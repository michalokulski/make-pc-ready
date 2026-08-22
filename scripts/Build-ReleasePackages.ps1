# ============================================================================
# Build-ReleasePackages.ps1 — Packages the three releaseable components
# ============================================================================
# Used by .github/workflows/release.yml. Can also be run locally:
#   ./scripts/Build-ReleasePackages.ps1 -Version "1.0.0"
#
# Produces in .\dist\:
#   MakePCReady-v<Version>.zip        — app installer (TUI + WPF GUI + shared module)
#   MakeTestVM-HyperV-v<Version>.zip  — Hyper-V VM creator
#   MakeTestVM-QEMU-v<Version>.zip    — QEMU VM creator (cross-platform, LF for .sh)
# ============================================================================

param(
  [Parameter(Mandatory)]
  [string]$Version,

  [string]$RepoRoot = (Split-Path -Path $PSScriptRoot -Parent),
  [string]$OutputDir = (Join-Path -Path $PSScriptRoot -ChildPath "..\dist")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Version -notmatch '^\d+\.\d+\.\d+.*$') {
  throw "Version '$Version' must look like '1.2.3' (without the leading 'v')."
}

$dist = $null
$resolvedOutput = Resolve-Path -Path $OutputDir -ErrorAction SilentlyContinue
if ($resolvedOutput) { $dist = $resolvedOutput.Path }
if (-not $dist) {
  $dist = New-Item -ItemType Directory -Path $OutputDir -Force | Select-Object -ExpandProperty FullName
}

# Clean previous artifacts so the release never contains stale files.
# A locked zip (e.g. open in Explorer) must not silently keep stale files in
# the release — fail loudly instead of packaging around it.
Get-ChildItem -Path $dist -Filter '*.zip' -ErrorAction SilentlyContinue | ForEach-Object {
  try {
    Remove-Item -Path $_.FullName -Force -ErrorAction Stop
  }
  catch {
    throw "Cannot remove stale artifact '$($_.Name)': $($_.Exception.Message). Close any program using it and retry."
  }
}

function New-ReleaseZip {
  param(
    [Parameter(Mandatory)]
    [string]$ZipName,
    [Parameter(Mandatory)]
    [hashtable]$FileMap # source path (repo-relative) -> destination path inside zip
  )

  $staging = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("pkg_" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $staging -Force | Out-Null

  try {
    foreach ($entry in $FileMap.GetEnumerator()) {
      $src = Join-Path -Path $RepoRoot -ChildPath $entry.Key
      if (-not (Test-Path -Path $src)) {
        throw "Packaging error: required file missing: $($entry.Key)"
      }

      $dest = Join-Path -Path $staging -ChildPath $entry.Value
      $destDir = Split-Path -Path $dest -Parent
      if (-not (Test-Path -Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
      }
      Copy-Item -Path $src -Destination $dest -Force
    }

    # Normalize line endings per file type before zipping:
    # .sh must be LF (bash on Linux rejects CRLF); everything else keeps CRLF.
    $shFiles = Get-ChildItem -Path $staging -Filter '*.sh' -Recurse -File
    foreach ($sh in $shFiles) {
      $content = Get-Content -Path $sh.FullName -Raw
      $content = $content -replace "`r`n","`n"
      [System.IO.File]::WriteAllText($sh.FullName,$content,(New-Object System.Text.UTF8Encoding $false))
    }

    $zipPath = Join-Path -Path $dist -ChildPath $ZipName
    Compress-Archive -Path (Join-Path -Path $staging -ChildPath '*') -DestinationPath $zipPath -Force
    Write-Host "Created $ZipName ($([math]::Round((Get-Item $zipPath).Length / 1KB, 1)) KB)"
  }
  finally {
    Remove-Item -Path $staging -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# --- 1. App installer (TUI + WPF GUI + shared module) ---
New-ReleaseZip -ZipName "MakePCReady-v$Version.zip" -FileMap @{
  'MakePCReady.ps1' = 'MakePCReady.ps1'
  'MakePCReadyAlternativeGUI.ps1' = 'MakePCReadyAlternativeGUI.ps1'
  'README.md' = 'README.md'
  'lib/PCSetup.Common.psm1' = 'lib/PCSetup.Common.psm1'
}

# --- 2. Hyper-V VM creator ---
New-ReleaseZip -ZipName "MakeTestVM-HyperV-v$Version.zip" -FileMap @{
  'Testing-Hyper-V/MakeTestVM.ps1' = 'Testing-Hyper-V/MakeTestVM.ps1'
  'Testing-Hyper-V/autounattend.xml' = 'Testing-Hyper-V/autounattend.xml'
  'Testing-Hyper-V/README.md' = 'Testing-Hyper-V/README.md'
  'lib/VMCommon.psm1' = 'lib/VMCommon.psm1'
}

# --- 3. QEMU VM creator (cross-platform) ---
New-ReleaseZip -ZipName "MakeTestVM-QEMU-v$Version.zip" -FileMap @{
  'Testing-QEMU/MakeTestVM-QEMU.ps1' = 'Testing-QEMU/MakeTestVM-QEMU.ps1'
  'Testing-QEMU/MakeTestVM-QEMU.sh' = 'Testing-QEMU/MakeTestVM-QEMU.sh'
  'Testing-QEMU/autounattend.xml' = 'Testing-QEMU/autounattend.xml'
  'Testing-QEMU/README.md' = 'Testing-QEMU/README.md'
  'lib/VMCommon.psm1' = 'lib/VMCommon.psm1'
}

Write-Host ""
Write-Host "All packages created in: $dist"
Get-ChildItem -Path $dist -Filter '*.zip' | ForEach-Object { Write-Host ("  {0}" -f $_.Name) }
