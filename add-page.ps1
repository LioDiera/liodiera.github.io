<#
.SYNOPSIS
  Adds a generated interactive HTML guide to the site and lists it on the home page.

.EXAMPLE
  .\add-page.ps1 "$HOME\Downloads\my-guide.html"
  .\add-page.ps1 "$HOME\Downloads\my-guide.html" -Title "Networking 101" -Tags "Networking","Cloud" -Slug "networking-101"

  Title defaults to the file's <title>, Description to its first class="lead" paragraph
  (or meta description). Re-running with the same slug replaces that page and its entry.
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$File,
    [string]$Title,
    [string]$Description,
    [string[]]$Tags = @(),
    [string]$Slug,
    [string]$Color
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$manifest = Join-Path $root 'pages.js'

if (-not (Test-Path $File)) { throw "File not found: $File" }
$html = [IO.File]::ReadAllText((Resolve-Path $File))

function Get-PlainText([string]$s) {
    $t = [regex]::Replace($s, '<[^>]+>', '')
    return [Net.WebUtility]::HtmlDecode($t).Trim()
}

if (-not $Title) {
    $m = [regex]::Match($html, '<title>(.*?)</title>', 'Singleline,IgnoreCase')
    $Title = if ($m.Success) { Get-PlainText $m.Groups[1].Value } else { [IO.Path]::GetFileNameWithoutExtension($File) }
}
if (-not $Description) {
    $m = [regex]::Match($html, '<meta\s+name="description"\s+content="([^"]*)"', 'IgnoreCase')
    if (-not $m.Success) { $m = [regex]::Match($html, 'class="(?:lead|summary)"[^>]*>(.*?)</(?:p|div)>', 'Singleline,IgnoreCase') }
    if ($m.Success) { $Description = Get-PlainText $m.Groups[1].Value }
}
if (-not $Slug) {
    $Slug = ($Title.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
    if ($Slug.Length -gt 60) { $Slug = $Slug.Substring(0, 60).Trim('-') }
}

# Copy the page in
$dest = Join-Path $root "pages\$Slug"
New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item (Resolve-Path $File) (Join-Path $dest 'index.html') -Force

# Optional: copy a sibling images folder if the page uses one
$srcImages = Join-Path (Split-Path (Resolve-Path $File)) 'images'
if ($html -match 'src="images/' -and (Test-Path $srcImages)) {
    Copy-Item $srcImages $dest -Recurse -Force
}

# Update manifest (pages.js = "window.PAGES = <json>;")
$raw = [IO.File]::ReadAllText($manifest)
$json = ($raw -replace '^\s*window\.PAGES\s*=\s*', '') -replace ';\s*$', ''
$list = @(ConvertFrom-Json $json) | Where-Object { $_.slug -ne $Slug }

$entry = [ordered]@{
    slug        = $Slug
    title       = $Title
    description = "$Description"
    tags        = @($Tags)
    date        = (Get-Date -Format 'yyyy-MM-dd')
}
if ($Color) { $entry.color = $Color }
$list = @($list) + @([pscustomobject]$entry)

$out = ConvertTo-Json -InputObject @($list) -Depth 5
[IO.File]::WriteAllText($manifest, "window.PAGES = $out;`n", (New-Object Text.UTF8Encoding $false))

Write-Host "Added '$Title'" -ForegroundColor Green
Write-Host "  page:  pages/$Slug/index.html"
Write-Host "  url:   https://liodiera.github.io/pages/$Slug/"
Write-Host "Next: git add -A; git commit -m `"Add $Slug`"; git push"
