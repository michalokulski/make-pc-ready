# ============================================================================
# VMCommon.psm1 — Shared module for VM creator scripts
# ============================================================================
# Dot-sourced by Testing-Hyper-V/MakeTestVM.ps1 and Testing-QEMU/MakeTestVM-QEMU.ps1.
# Contains: logging, integer validation, ISO source menu, log finalizer.
# ============================================================================

# --- Module-scoped state ---
$script:logFile = $null
$script:logStartTime = $null

function Initialize-VMCommonState {
  # Entry scripts must call this instead of assigning $script: variables directly:
  # Import-Module gives this module its own scope, so caller-side assignments to
  # $script:logFile are NOT visible to functions defined here.
  param(
    [Parameter(Mandatory)]
    [string]$LogPath,
    [datetime]$StartTime = (Get-Date)
  )

  $script:logFile = $LogPath
  $script:logStartTime = $StartTime
}

$script:logColors = @{
  "SUCCESS" = "Green"
  "INFO" = "White"
  "WARNING" = "Yellow"
  "ERROR" = "Red"
}

# ============================================================================
# Logging
# ============================================================================

function Initialize-Log {
  param([string]$Title = "VM Creator Log")

  $userName = if ($env:USERNAME) { $env:USERNAME } else { $env:USER }
  $computerName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { [System.Net.Dns]::GetHostName() }
  $osDescription = if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
    "Windows"
  } else {
    [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
  }

  $header = @"
================================================================================
$Title
Started: $($script:logStartTime.ToString('yyyy-MM-dd HH:mm:ss'))
User: $userName
Computer: $computerName
PowerShell Version: $($PSVersionTable.PSVersion.ToString())
OS: $osDescription
================================================================================

"@

  $logDir = Split-Path -Path $script:logFile -Parent
  if (-not [string]::IsNullOrWhiteSpace($logDir) -and -not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  }

  $header | Out-File -FilePath $script:logFile -Encoding UTF8
  Write-Host "Log file created at: $script:logFile" -ForegroundColor Green
}

function Write-Log {
  param(
    [Parameter(Mandatory)]
    [string]$Message,
    [ValidateSet("SUCCESS","INFO","WARNING","ERROR")]
    [string]$Level = "INFO",
    [switch]$NoConsole
  )

  $timestamp = Get-Date -Format "HH:mm:ss"
  $line = "$timestamp [$Level] $Message"

  $line | Out-File -FilePath $script:logFile -Encoding UTF8 -Append

  if (-not $NoConsole) {
    $color = if ($script:logColors.ContainsKey($Level)) { $script:logColors[$Level] } else { "White" }
    Write-Host $line -ForegroundColor $color
  }
}

# ============================================================================
# Input Validation
# ============================================================================

function Read-ValidatedInteger {
  param(
    [Parameter(Mandatory)]
    [string]$Prompt,
    [Parameter(Mandatory)]
    [int]$Min,
    [Parameter(Mandatory)]
    [int]$Max,
    [Parameter(Mandatory)]
    [int]$DefaultValue
  )

  do {
    $inputValue = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($inputValue)) {
      $inputValue = "$DefaultValue"
    }

    $parsedValue = 0
    $isValid = [int]::TryParse($inputValue,[ref]$parsedValue) -and $parsedValue -ge $Min -and $parsedValue -le $Max

    if (-not $isValid) {
      Write-Host "Please enter a number between $Min and $Max." -ForegroundColor Yellow
    }
  } while (-not $isValid)

  return $parsedValue
}

function Read-PositiveInteger {
  param(
    [Parameter(Mandatory)]
    [string]$Prompt,
    [Parameter(Mandatory)]
    [int]$DefaultValue
  )

  do {
    $inputValue = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($inputValue)) {
      $inputValue = "$DefaultValue"
    }

    $parsedValue = 0
    $isValid = [int]::TryParse($inputValue,[ref]$parsedValue) -and $parsedValue -gt 0

    if (-not $isValid) {
      Write-Host "Please enter a positive whole number." -ForegroundColor Yellow
    }
  } while (-not $isValid)

  return $parsedValue
}

# ============================================================================
# ISO Source Menu
# ============================================================================

function Show-ISOSourceMenu {
  Write-Host ""
  Write-Host "============================================" -ForegroundColor Cyan
  Write-Host "  Windows ISO Source Selection" -ForegroundColor Cyan
  Write-Host "============================================" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "  [1] Download from Microsoft via FIDO.ps1" -ForegroundColor White
  Write-Host "      (Latest Windows 10/11 retail ISO, ~5-6 GB download)" -ForegroundColor Gray
  Write-Host ""
  Write-Host "  [2] Build ISO via UUP dump" -ForegroundColor White
  Write-Host "      (Any Win10/11 build incl. older versions, slower)" -ForegroundColor Gray
  Write-Host ""
  Write-Host "  [3] Use a local ISO file" -ForegroundColor White
  Write-Host "      (Browse for an existing .iso file)" -ForegroundColor Gray
  Write-Host ""

  do {
    $choice = Read-Host "Select ISO source (1-3)"
  } while ($choice -notin @("1","2","3"))

  return [int]$choice
}

# ============================================================================
# Shared ISO Acquisition Functions
# ============================================================================
# Used by both Testing-Hyper-V/MakeTestVM.ps1 and Testing-QEMU/MakeTestVM-QEMU.ps1.
# The selected ISO language is stored in module scope; entry scripts read it via
# Get-SelectedISOLanguage (module scopes are isolated from the caller).

$script:selectedISOLanguage = $null

function Set-SelectedISOLanguage {
  param([string]$Language)
  $script:selectedISOLanguage = $Language
}

function Get-SelectedISOLanguage {
  return $script:selectedISOLanguage
}

function Invoke-FileDownload {
  # Cross-platform download: BITS on Windows when available, IWR fallback everywhere.
  param(
    [Parameter(Mandatory)]
    [string]$Uri,
    [Parameter(Mandatory)]
    [string]$DestinationPath
  )

  if ($IsWindows -or $env:OS -eq "Windows_NT") {
    if (Get-Command -Name Start-BitsTransfer -ErrorAction SilentlyContinue) {
      try {
        Start-BitsTransfer -Source $Uri -Destination $DestinationPath -ErrorAction Stop
        return
      }
      catch {
        Write-Log "BITS transfer failed, falling back to Invoke-WebRequest: $($_.Exception.Message)" -Level "WARNING"
      }
    }
  }

  Invoke-WebRequest -Uri $Uri -OutFile $DestinationPath -UseBasicParsing -ErrorAction Stop
}

function Get-WindowsISOViaFido {
  param(
    [Parameter(Mandatory)]
    [string]$DownloadFolder
  )

  Write-Log "Downloading Windows ISO via FIDO.ps1..." -Level "INFO"

  if (-not (Test-Path -Path $DownloadFolder)) {
    Write-Log "Creating download folder: $DownloadFolder" -Level "INFO"
    New-Item -ItemType Directory -Path $DownloadFolder -Force | Out-Null
  }

  # ---- Windows Version Selection ----
  Write-Host ""
  Write-Host "Select Windows version:" -ForegroundColor Cyan
  Write-Host "  [1] Windows 11 (recommended)" -ForegroundColor White
  Write-Host "  [2] Windows 10" -ForegroundColor White
  Write-Host ""

  do {
    $osChoice = Read-Host "Select version (1-2) [1]"
    if ([string]::IsNullOrWhiteSpace($osChoice)) { $osChoice = "1" }
  } while ($osChoice -notin @("1","2"))

  if ($osChoice -eq "1") {
    $fidoWin = "Windows 11"
    $fidoEd = "Windows 11 Home/Pro/Edu"
    $defaultFileName = "Windows11.iso"
  }
  else {
    $fidoWin = "Windows 10"
    $fidoEd = "Windows 10 Home/Pro/Edu"
    $defaultFileName = "Windows10.iso"
  }

  # ---- Language Selection ----
  $languages = @(
    @{ Name = "English (US)"; Code = "English" },
    @{ Name = "English International"; Code = "English International" },
    @{ Name = "German"; Code = "German" },
    @{ Name = "French"; Code = "French" },
    @{ Name = "Spanish"; Code = "Spanish" },
    @{ Name = "Italian"; Code = "Italian" },
    @{ Name = "Portuguese (Brazil)"; Code = "Brazilian Portuguese" },
    @{ Name = "Dutch"; Code = "Dutch" },
    @{ Name = "Japanese"; Code = "Japanese" },
    @{ Name = "Korean"; Code = "Korean" },
    @{ Name = "Chinese Simplified"; Code = "Chinese (Simplified)" },
    @{ Name = "Chinese Traditional"; Code = "Chinese (Traditional)" },
    @{ Name = "Russian"; Code = "Russian" },
    @{ Name = "Polish"; Code = "Polish" },
    @{ Name = "Swedish"; Code = "Swedish" },
    @{ Name = "Turkish"; Code = "Turkish" },
    @{ Name = "Arabic"; Code = "Arabic" }
  )

  Write-Host ""
  Write-Host "Select language:" -ForegroundColor Cyan
  for ($i = 0; $i -lt $languages.Count; $i++) {
    Write-Host "  [$($i+1)] $($languages[$i].Name)" -ForegroundColor White
  }
  Write-Host ""

  $langChoice = Read-ValidatedInteger -Prompt "Select language (1-$($languages.Count)) [1]" -Min 1 -Max $languages.Count -DefaultValue 1

  $fidoLang = $languages[$langChoice - 1].Code
  Set-SelectedISOLanguage -Language $fidoLang

  # Warn about non-English ISO and unattend compatibility
  if ($fidoLang -notin @("English","English International")) {
    Write-Host ""
    Write-Host "  WARNING: The included autounattend.xml is configured for English (en-US)." -ForegroundColor Yellow
    Write-Host "  A non-English ISO may cause the unattended installation to fail or require" -ForegroundColor Yellow
    Write-Host "  manual intervention (e.g. language/locale prompts, edition mismatches)." -ForegroundColor Yellow
    Write-Host "  For fully automatic installation, use an English ISO or a matching unattend.iso." -ForegroundColor Yellow
    Write-Host ""
    Write-Log "Non-English ISO language selected ('$fidoLang'). Bundled autounattend.xml is for en-US." -Level "WARNING"
  }

  # ---- Architecture Selection ----
  Write-Host ""
  Write-Host "Select architecture:" -ForegroundColor Cyan
  Write-Host "  [1] x64 (recommended)" -ForegroundColor White

  if ($PSVersionTable.PSVersion.Major -ge 6) {
    $hostArch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToUpperInvariant()
  }
  else {
    $hostArch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
  }
  $arm64Supported = ($hostArch -eq "ARM64")

  if ($fidoWin -eq "Windows 11" -and $arm64Supported) {
    Write-Host "  [2] ARM64" -ForegroundColor White
  }
  elseif ($fidoWin -eq "Windows 11") {
    Write-Host "  ARM64 option hidden (host architecture: $hostArch)" -ForegroundColor Gray
  }
  Write-Host ""

  $maxArchChoice = if ($fidoWin -eq "Windows 11" -and $arm64Supported) { 2 } else { 1 }
  $archChoice = Read-ValidatedInteger -Prompt "Select architecture (1-$maxArchChoice) [1]" -Min 1 -Max $maxArchChoice -DefaultValue 1

  $fidoArch = if ($archChoice -eq 2) { "ARM64" } else { "x64" }

  Write-Log "Selected: $fidoWin, Edition=$fidoEd, Language=$fidoLang, Architecture=$fidoArch" -Level "INFO"

  # ---- Download FIDO.ps1 ----
  $fidoUrl = "https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1"
  $fidoPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "Fido.ps1"

  try {
    Write-Log "Fetching FIDO.ps1 from GitHub..." -Level "INFO"
    Invoke-FileDownload -Uri $fidoUrl -DestinationPath $fidoPath
    Unblock-File -Path $fidoPath -ErrorAction SilentlyContinue
    Write-Log "FIDO.ps1 downloaded successfully" -Level "SUCCESS"
  }
  catch {
    Write-Log "Failed to download FIDO.ps1: $($_.Exception.Message)" -Level "ERROR"
    return $null
  }

  try {
    Write-Log "Querying Microsoft for $fidoWin ISO download link..." -Level "INFO"
    Write-Log "This may take a moment as FIDO negotiates with Microsoft's servers..." -Level "INFO"

    $fidoOutput = @(& $fidoPath -Win $fidoWin -Rel "Latest" -Ed $fidoEd -Lang $fidoLang -Arch $fidoArch -GetUrl)
    # FIDO may emit multiple lines; the URL is the last valid one
    $isoUrl = $fidoOutput | Where-Object { $_ -match "^https?://" } | Select-Object -Last 1
    if (-not $isoUrl) {
      Write-Log "FIDO did not return a valid download URL." -Level "ERROR"
      Write-Log "FIDO output: $($fidoOutput -join ' | ')" -Level "ERROR" -NoConsole
      return $null
    }

    Write-Log "Download URL obtained: $($isoUrl.Substring(0, [Math]::Min(80, $isoUrl.Length)))..." -Level "SUCCESS"

    # Extract filename from URL
    $fileName = [System.IO.Path]::GetFileName(([uri]$isoUrl).LocalPath)
    if (-not $fileName -or -not $fileName.EndsWith(".iso")) {
      $fileName = $defaultFileName
    }

    $outputPath = Join-Path -Path $DownloadFolder -ChildPath $fileName

    if (Test-Path -Path $outputPath) {
      Write-Log "ISO already exists at: $outputPath - skipping download" -Level "INFO"
      return $outputPath
    }

    Write-Log "Downloading ISO to: $outputPath" -Level "INFO"
    Write-Log "This will take a while (ISO is typically 5-6 GB)..." -Level "INFO"

    Invoke-FileDownload -Uri $isoUrl -DestinationPath $outputPath

    if (Test-Path -Path $outputPath) {
      $fileSize = [math]::Round((Get-Item $outputPath).Length / 1GB,2)
      Write-Log "ISO downloaded successfully ($fileSize GB): $outputPath" -Level "SUCCESS"
      return $outputPath
    }

    Write-Log "ISO file not found after download." -Level "ERROR"
    return $null
  }
  catch {
    Write-Log "Failed during FIDO ISO download: $($_.Exception.Message)" -Level "ERROR"
    return $null
  }
  finally {
    Remove-Item -Path $fidoPath -Force -ErrorAction SilentlyContinue
  }
}

function Get-WindowsISOViaUUPDump {
  param(
    [Parameter(Mandatory)]
    [string]$DownloadFolder,
    [switch]$IncludeLinuxRunner
  )

  Write-Log "Building Windows ISO via UUP dump..." -Level "INFO"

  if (-not (Test-Path -Path $DownloadFolder)) {
    Write-Log "Creating download folder: $DownloadFolder" -Level "INFO"
    New-Item -ItemType Directory -Path $DownloadFolder -Force | Out-Null
  }

  # ---- OS Selection ----
  Write-Host ""
  Write-Host "Select Windows version to search:" -ForegroundColor Cyan
  Write-Host "  [1] Windows 11 (recommended)" -ForegroundColor White
  Write-Host "  [2] Windows 10" -ForegroundColor White
  Write-Host ""

  do {
    $osChoice = Read-Host "Select version (1-2) [1]"
    if ([string]::IsNullOrWhiteSpace($osChoice)) { $osChoice = "1" }
  } while ($osChoice -notin @("1","2"))

  if ($osChoice -eq "1") {
    $searchQuery = "Windows+11"
    $titleFilter = "Windows 11, version"
    $osLabel = "Windows 11"
  }
  else {
    $searchQuery = "Windows+10"
    $titleFilter = "Windows 10, version"
    $osLabel = "Windows 10"
  }

  # Step 1: Query UUP dump API for available builds
  Write-Log "Querying UUP dump API for available $osLabel builds..." -Level "INFO"

  try {
    $apiUrl = "https://api.uupdump.net/listid.php?search=$searchQuery&sortByDate=1"
    $response = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -ErrorAction Stop
  }
  catch {
    Write-Log "Failed to query UUP dump API: $($_.Exception.Message)" -Level "ERROR"
    return $null
  }

  if (-not $response.response -or -not $response.response.builds) {
    Write-Log "UUP dump API returned no builds." -Level "ERROR"
    return $null
  }

  # UUP dump API returns builds as a PSObject with numbered keys, not an array
  $allBuilds = @($response.response.builds.PSObject.Properties.Value)

  # Filter for stable x64 builds (non-Insider, non-Server, non-Cumulative Update)
  $stableBuilds = @($allBuilds | Where-Object {
      $_.arch -eq "amd64" -and
      $_.title -notmatch "Insider|Server|Cumulative|Preview Update|Security Update" -and
      $_.title -match $titleFilter
    } | Select-Object -First 10)

  if ($stableBuilds.Count -eq 0) {
    Write-Log "No stable $osLabel builds found on UUP dump." -Level "ERROR"
    return $null
  }

  # Show available builds
  Write-Host ""
  Write-Host "Available $osLabel builds from UUP dump:" -ForegroundColor Cyan
  Write-Host ""
  for ($i = 0; $i -lt $stableBuilds.Count; $i++) {
    $b = $stableBuilds[$i]
    $date = [DateTimeOffset]::FromUnixTimeSeconds($b.created).LocalDateTime.ToString("yyyy-MM-dd")
    Write-Host "  [$($i+1)] $($b.title) ($date)" -ForegroundColor White
  }
  Write-Host ""

  $buildChoice = Read-ValidatedInteger -Prompt "Select build (1-$($stableBuilds.Count)) [1]" -Min 1 -Max $stableBuilds.Count -DefaultValue 1

  $selectedBuild = $stableBuilds[$buildChoice - 1]
  Write-Log "Selected: $($selectedBuild.title) (UUID: $($selectedBuild.uuid))" -Level "INFO"

  # ---- Language Selection (dynamic from API) ----
  Write-Log "Querying available languages for this build..." -Level "INFO"

  try {
    $langUrl = "https://api.uupdump.net/listlangs.php?id=$($selectedBuild.uuid)"
    $langResponse = Invoke-RestMethod -Uri $langUrl -UseBasicParsing -ErrorAction Stop
  }
  catch {
    Write-Log "Failed to query languages: $($_.Exception.Message)" -Level "ERROR"
    return $null
  }

  $langCodes = @($langResponse.response.langFancyNames.PSObject.Properties | Sort-Object Value)

  if ($langCodes.Count -eq 0) {
    Write-Log "No languages available for this build." -Level "ERROR"
    return $null
  }

  Write-Host ""
  Write-Host "Available languages:" -ForegroundColor Cyan
  $defaultLangIdx = 1
  for ($i = 0; $i -lt $langCodes.Count; $i++) {
    Write-Host "  [$($i+1)] $($langCodes[$i].Value) ($($langCodes[$i].Name))" -ForegroundColor White
    if ($langCodes[$i].Name -eq "en-us") { $defaultLangIdx = $i + 1 }
  }
  Write-Host ""

  $langChoice = Read-ValidatedInteger -Prompt "Select language (1-$($langCodes.Count)) [$defaultLangIdx]" -Min 1 -Max $langCodes.Count -DefaultValue $defaultLangIdx

  $selectedLang = $langCodes[$langChoice - 1].Name
  Set-SelectedISOLanguage -Language $selectedLang
  Write-Log "Selected language: $selectedLang" -Level "INFO"

  # Warn about non-English ISO and unattend compatibility
  if ($selectedLang -notmatch '^en-') {
    Write-Host ""
    Write-Host "  WARNING: The included autounattend.xml is configured for English (en-US)." -ForegroundColor Yellow
    Write-Host "  A non-English ISO may cause the unattended installation to fail or require" -ForegroundColor Yellow
    Write-Host "  manual intervention (e.g. language/locale prompts, edition mismatches)." -ForegroundColor Yellow
    Write-Host "  For fully automatic installation, use an English ISO or a matching unattend.iso." -ForegroundColor Yellow
    Write-Host ""
    Write-Log "Non-English ISO language selected ('$selectedLang'). Bundled autounattend.xml is for en-US." -Level "WARNING"
  }

  # ---- Edition Selection (dynamic from API) ----
  Write-Log "Querying available editions..." -Level "INFO"

  try {
    $edUrl = "https://api.uupdump.net/listeditions.php?lang=$selectedLang&id=$($selectedBuild.uuid)"
    $edResponse = Invoke-RestMethod -Uri $edUrl -UseBasicParsing -ErrorAction Stop
  }
  catch {
    Write-Log "Failed to query editions: $($_.Exception.Message)" -Level "ERROR"
    return $null
  }

  $editions = @($edResponse.response.editionFancyNames.PSObject.Properties | Sort-Object Value)

  if ($editions.Count -eq 0) {
    Write-Log "No editions available for this build and language." -Level "ERROR"
    return $null
  }

  Write-Host ""
  Write-Host "Available editions:" -ForegroundColor Cyan
  $defaultEdIdx = 1
  for ($i = 0; $i -lt $editions.Count; $i++) {
    Write-Host "  [$($i+1)] $($editions[$i].Value) ($($editions[$i].Name))" -ForegroundColor White
    if ($editions[$i].Name -eq "professional") { $defaultEdIdx = $i + 1 }
  }
  Write-Host ""

  $edChoice = Read-ValidatedInteger -Prompt "Select edition (1-$($editions.Count)) [$defaultEdIdx]" -Min 1 -Max $editions.Count -DefaultValue $defaultEdIdx

  $selectedEdition = $editions[$edChoice - 1].Name
  Write-Log "Selected edition: $selectedEdition" -Level "INFO"

  # Step 2: Download the UUP dump creation package
  $packageUrl = "https://uupdump.net/get.php?id=$($selectedBuild.uuid)&pack=$selectedLang&edition=$selectedEdition&autodl=2"
  $packageZip = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "uupdump_package.zip"
  $packageDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "uupdump_work"

  Write-Log "Downloading UUP dump creation package..." -Level "INFO"

  try {
    Invoke-FileDownload -Uri $packageUrl -DestinationPath $packageZip
  }
  catch {
    Write-Log "Failed to download UUP dump package: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "You can manually download from: https://uupdump.net/selectlang.php?id=$($selectedBuild.uuid)" -Level "INFO"
    return $null
  }

  # Step 3: Extract and run the converter
  if (Test-Path -Path $packageDir) {
    Remove-Item -Path $packageDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  Write-Log "Extracting UUP dump package..." -Level "INFO"
  try {
    Expand-Archive -Path $packageZip -DestinationPath $packageDir -Force -ErrorAction Stop
  }
  catch {
    Write-Log "Failed to extract package: $($_.Exception.Message)" -Level "ERROR"
    return $null
  }

  # Pick the runner script for the current platform
  $runnerPath = $null
  $isWindowsHost = ($PSVersionTable.PSVersion.Major -ge 6) ? $IsWindows : ($env:OS -eq "Windows_NT")
  if ($isWindowsHost) {
    $candidate = Join-Path -Path $packageDir -ChildPath "uup_download_windows.cmd"
    if (Test-Path -Path $candidate) { $runnerPath = $candidate }
  }
  elseif ($IncludeLinuxRunner) {
    $candidate = Join-Path -Path $packageDir -ChildPath "uup_download_linux.sh"
    if (Test-Path -Path $candidate) { $runnerPath = $candidate }
  }

  if (-not $runnerPath) {
    Write-Log "Could not find a supported UUP download runner script in package." -Level "ERROR"
    Write-Log "Package contents: $(Get-ChildItem $packageDir -Name | Out-String)" -Level "WARNING"
    return $null
  }

  Write-Log "Running UUP dump converter (this downloads UUPs and builds the ISO)..." -Level "INFO"
  Write-Log "This will take a LONG time (downloading ~4 GB of UUP files + conversion)..." -Level "WARNING"

  if ($isWindowsHost) {
    try {
      $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$runnerPath`"" `
         -WorkingDirectory $packageDir -Wait -Passthru
      if ($process.ExitCode -ne 0) {
        Write-Log "UUP converter failed with exit code $($process.ExitCode)." -Level "ERROR"
        return $null
      }
    }
    catch {
      Write-Log "Failed to run UUP dump converter: $($_.Exception.Message)" -Level "ERROR"
      return $null
    }
  }
  else {
    $pushedLocation = $false
    try {
      Push-Location -Path $packageDir
      $pushedLocation = $true
      & chmod +x $runnerPath
      & bash $runnerPath
      $runnerExitCode = $LASTEXITCODE
      Pop-Location
      $pushedLocation = $false

      if ($runnerExitCode -ne 0) {
        Write-Log "UUP converter failed with exit code $runnerExitCode." -Level "ERROR"
        return $null
      }
    }
    catch {
      if ($pushedLocation) {
        Pop-Location -ErrorAction SilentlyContinue
      }
      Write-Log "Failed to run UUP dump converter: $($_.Exception.Message)" -Level "ERROR"
      return $null
    }
  }

  # Step 4: Find the resulting ISO
  $resultISOs = @(Get-ChildItem -Path $packageDir -Filter "*.iso" -File -Recurse -ErrorAction SilentlyContinue)
  if ($resultISOs.Count -eq 0) {
    Write-Log "No ISO file was produced by the UUP dump converter." -Level "ERROR"
    Write-Log "Check the converter output above for errors." -Level "INFO"
    return $null
  }

  $sourceISO = $resultISOs | Sort-Object Length -Descending | Select-Object -First 1
  $destISO = Join-Path -Path $DownloadFolder -ChildPath $sourceISO.Name

  Write-Log "Moving built ISO to: $destISO" -Level "INFO"
  Move-Item -Path $sourceISO.FullName -Destination $destISO -Force

  # Cleanup temp files
  Remove-Item -Path $packageZip -Force -ErrorAction SilentlyContinue
  Remove-Item -Path $packageDir -Recurse -Force -ErrorAction SilentlyContinue

  $fileSize = [math]::Round((Get-Item $destISO).Length / 1GB,2)
  Write-Log "ISO built successfully ($fileSize GB): $destISO" -Level "SUCCESS"
  return $destISO
}

# ============================================================================
# Log Finalizer
# ============================================================================

function Complete-Log {
  param([bool]$Success)

  $elapsed = (Get-Date) - $script:logStartTime

  $footer = @"

================================================================================
Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Duration: $($elapsed.ToString('hh\:mm\:ss'))
Result: $(if ($Success) { 'SUCCESS' } else { 'FAILED' })
================================================================================
"@

  $footer | Out-File -FilePath $script:logFile -Encoding UTF8 -Append

  if ($Success) {
    Write-Host ""
    Write-Host "VM operation completed successfully!" -ForegroundColor Green
    Write-Host "Log: $script:logFile" -ForegroundColor Gray
  }
  else {
    Write-Host ""
    Write-Host "VM operation failed. Check the log for details." -ForegroundColor Red
    Write-Host "Log: $script:logFile" -ForegroundColor Gray
  }
}
