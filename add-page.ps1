<#
.SYNOPSIS
  Adds a generated interactive HTML guide to the site and lists it on the home page.

.EXAMPLE
  .\add-page.ps1 "$HOME\Downloads\my-guide.html"
  .\add-page.ps1 "$HOME\Downloads\my-guide.html" -Title "Networking 101" -Tags "Networking","Cloud" -Slug "networking-101"

  Title defaults to the file's <title>, Description to its first class="lead" paragraph
  (or meta description). Re-running with the same slug replaces that page and its entry.
#>
[CmdletBinding(DefaultParameterSetName = 'Add')]
param(
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Add')][string]$File,
    [Parameter(ParameterSetName = 'Add')][string]$Title,
    [Parameter(ParameterSetName = 'Add')][string]$Description,
    [Parameter(ParameterSetName = 'Add')][string[]]$Tags = @(),
    [Parameter(ParameterSetName = 'Add')][string]$Slug,
    [Parameter(ParameterSetName = 'Add')][string]$Color,
    [Parameter(Mandatory = $true, ParameterSetName = 'Home')][switch]$AddHomeLinkToAll
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$manifest = Join-Path $root 'pages.js'

$homeCss = '<style id="site-home-css">.site-home-bar{box-sizing:border-box;padding:12px 16px;background:#FAF5EB;border-bottom:1px solid rgba(31,46,43,.22)}.site-home-bar a{display:inline-flex;align-items:center;gap:.5em;min-height:36px;box-sizing:border-box;padding:0 1.1em;border:1px solid #1F2E2B;border-radius:999px;background:#FBF8F1;color:#1F2E2B;font:600 .78rem/1 Poppins,system-ui,sans-serif;letter-spacing:.12em;text-transform:uppercase;text-decoration:none}.site-home-bar a:hover{background:#fff}.site-home-bar a:focus-visible{outline:3px solid #D9582A;outline-offset:2px}</style>'
$homeBar = '<nav class="site-home-bar" id="site-home" aria-label="Site"><a href="../../index.html"><span aria-hidden="true">&larr;</span> Home</a></nav>'
$utf8 = New-Object Text.UTF8Encoding $false

# Reads a file as UTF-8; returns $null if it isn't valid UTF-8 (so we never mangle it)
function Read-Utf8Strict([string]$path) {
    try { return [IO.File]::ReadAllText($path, (New-Object Text.UTF8Encoding $false, $true)) }
    catch [Text.DecoderFallbackException] { return $null }
}

# Adds a "back to home" bar right after <body>; if one is already there, refreshes it to the current version
function Add-HomeLink([string]$s) {
    if ($s -match 'id="site-home"') {
        $s = [regex]::new('<style id="site-home-css">.*?</style>', 'Singleline').Replace($s, [Text.RegularExpressions.MatchEvaluator]{ param($m) $homeCss }, 1)
        return [regex]::new('<nav class="site-home-bar" id="site-home".*?</nav>', 'Singleline').Replace($s, [Text.RegularExpressions.MatchEvaluator]{ param($m) $homeBar }, 1)
    }
    $s =[regex]::new('</head>', 'IgnoreCase').Replace($s, [Text.RegularExpressions.MatchEvaluator]{ param($m) $homeCss + $m.Value }, 1)
    return [regex]::new('<body[^>]*>', 'IgnoreCase').Replace($s, [Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Value + "`n" + $homeBar }, 1)
}

if ($AddHomeLinkToAll) {
    foreach ($f in Get-ChildItem (Join-Path $root 'pages') -Filter index.html -Recurse -Depth 1) {
        $old = Read-Utf8Strict $f.FullName
        if ($null -eq $old) { Write-Warning "Skipped (not UTF-8): $($f.FullName)"; continue }
        $new = Add-HomeLink $old
        if ($new -ne $old) { [IO.File]::WriteAllText($f.FullName, $new, $utf8); Write-Host "Home link updated: $($f.FullName)" }
    }
    return
}

if (-not (Test-Path $File)) { throw "File not found: $File" }
$html = Read-Utf8Strict (Resolve-Path $File)
$isUtf8 = $null -ne $html
if (-not $isUtf8) { $html = [IO.File]::ReadAllText((Resolve-Path $File), [Text.Encoding]::Default) }

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
if ($isUtf8) {
    [IO.File]::WriteAllText((Join-Path $dest 'index.html'), (Add-HomeLink $html), $utf8)
} else {
    Copy-Item (Resolve-Path $File) (Join-Path $dest 'index.html') -Force
    Write-Warning "Page isn't UTF-8, so it was copied as-is without the Home button."
}

# Optional: copy a sibling images folder if the page uses one
$srcImages = Join-Path (Split-Path (Resolve-Path $File)) 'images'
if ($html -match 'src="images/' -and (Test-Path $srcImages)) {
    Copy-Item $srcImages $dest -Recurse -Force
}

# Update manifest (pages.js = "window.PAGES = <json>;")
$raw = [IO.File]::ReadAllText($manifest)
$json = ($raw -replace '^\s*window\.PAGES\s*=\s*', '') -replace ';\s*$', ''
# Parentheses unroll the array: Windows PowerShell 5.1 emits it as a single object otherwise
$list = @((ConvertFrom-Json $json) | Where-Object { $_.slug -ne $Slug })

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
[IO.File]::WriteAllText($manifest, "window.PAGES = $out;`n", $utf8)

Write-Host "Added '$Title'" -ForegroundColor Green
Write-Host "  page:  pages/$Slug/index.html"
Write-Host "  url:   https://liodiera.github.io/pages/$Slug/"
Write-Host "Next: git add -A; git commit -m `"Add $Slug`"; git push"
