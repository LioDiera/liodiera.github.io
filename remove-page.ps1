<#
.SYNOPSIS
  Removes a guide from the site: deletes its pages/<slug> folder and its entry on the home page.

.EXAMPLE
  .\remove-page.ps1 networking-101
  .\remove-page.ps1 networking-101 -WhatIf        # show what would be removed, change nothing
  .\remove-page.ps1 networking-101 -Confirm:$false  # skip the confirmation prompt

  Run it with no slug to list the guides on the site. The removal only reaches the live
  site once you commit and push, and until then `git restore pages pages.js` brings the guide back.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Position = 0)][string]$Slug
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$manifest = Join-Path $root 'pages.js'

$raw = [IO.File]::ReadAllText($manifest)
$json = ($raw -replace '^\s*window\.PAGES\s*=\s*', '') -replace ';\s*$', ''
# Parentheses unroll the array: Windows PowerShell 5.1 emits it as a single object otherwise
$all = @((ConvertFrom-Json $json))

if (-not $Slug) {
    Write-Host 'Guides on the site:'
    $all | ForEach-Object { Write-Host "  $($_.slug)  ($($_.title))" }
    Write-Host 'Run: .\remove-page.ps1 <slug>'
    return
}

# A slug is only lowercase letters, numbers and hyphens, so it can never point outside pages\
if ($Slug -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { throw "Not a valid slug: '$Slug'. Run .\remove-page.ps1 with no slug to list them." }

$dir = Join-Path $root "pages\$Slug"
$entries = @($all | Where-Object { $_.slug -eq $Slug })
$hasDir = Test-Path $dir

if (-not $hasDir -and $entries.Count -eq 0) {
    throw "No guide with slug '$Slug'. Run .\remove-page.ps1 with no slug to list them."
}

$title = if ($entries.Count) { $entries[0].title } else { $Slug }
$what = @()
if ($hasDir) { $what += "folder pages\$Slug" }
if ($entries.Count) { $what += "its home page entry" }

if (-not $PSCmdlet.ShouldProcess("'$title' ($($what -join ' and '))", 'Remove guide')) { return }

if ($hasDir) { Remove-Item $dir -Recurse -Force }
if ($entries.Count) {
    $list = @($all | Where-Object { $_.slug -ne $Slug })
    $out = ConvertTo-Json -InputObject @($list) -Depth 5
    [IO.File]::WriteAllText($manifest, "window.PAGES = $out;`n", (New-Object Text.UTF8Encoding $false))
}

Write-Host "Removed '$title'" -ForegroundColor Green
if (-not $hasDir) { Write-Host "  (it had no folder in pages\; only the home page entry was removed)" }
if (-not $entries.Count) { Write-Host "  (it wasn't listed on the home page; only the folder was removed)" }
Write-Host "Next: git add -A; git commit -m `"Remove $Slug`"; git push"
