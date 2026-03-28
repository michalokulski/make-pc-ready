param (
    [string]$VMName,
    [string]$ISOPath,
    [string]$SwitchName,
    [int64]$MemoryBytes = 4GB,
    [int]$CPUCount = 2,
    [int64]$DiskSizeBytes = 64GB,
    [string]$VMPath,
    [string]$UnattendISOPath,
    [string]$LogPath = "$env:USERPROFILE\Desktop\MakeTestVM.log",
    [switch]$NonInteractive,
    [switch]$StartVM,
    [switch]$OpenConsole
)

# ============================================================================
# Hyper-V Test VM Creator - Automated Clean Windows VM Provisioning
# ============================================================================
# Creates a fresh Windows VM in Hyper-V with unattended installation.
# ISO sources: FIDO.ps1 (Microsoft download), or local ISO path.
# Unattend: repo-hosted unattend.iso (generate XML at schneegans.de, wrap in ISO).
# ============================================================================

$script:logFile = $LogPath
$script:logStartTime = Get-Date
$script:scriptRoot = $PSScriptRoot

$script:logColors = @{
    "SUCCESS" = "Green"
    "INFO"    = "White"
    "WARNING" = "Yellow"
    "ERROR"   = "Red"
}

# ============================================================================
# Logging
# ============================================================================

function Initialize-Log {
    $header = @"
================================================================================
Hyper-V Test VM Creator Log
Started: $($script:logStartTime.ToString('yyyy-MM-dd HH:mm:ss'))
User: $env:USERNAME
Computer: $env:COMPUTERNAME
PowerShell Version: $($PSVersionTable.PSVersion.ToString())
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
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [switch]$NoConsole
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "$timestamp [$Level] $Message"

    $logMessage | Out-File -FilePath $script:logFile -Encoding UTF8 -Append

    if (-not $NoConsole) {
        $color = if ($script:logColors.ContainsKey($Level)) { $script:logColors[$Level] } else { "White" }
        Write-Host $logMessage -ForegroundColor $color
    }
}

function Read-ValidatedInteger {
    param (
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
        $isValid = [int]::TryParse($inputValue, [ref]$parsedValue) -and $parsedValue -ge $Min -and $parsedValue -le $Max

        if (-not $isValid) {
            Write-Host "Please enter a number between $Min and $Max." -ForegroundColor Yellow
        }
    } while (-not $isValid)

    return $parsedValue
}

function Read-PositiveInteger {
    param (
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
        $isValid = [int]::TryParse($inputValue, [ref]$parsedValue) -and $parsedValue -gt 0

        if (-not $isValid) {
            Write-Host "Please enter a positive whole number." -ForegroundColor Yellow
        }
    } while (-not $isValid)

    return $parsedValue
}

# ============================================================================
# Prerequisites
# ============================================================================

function Test-AdminPrivileges {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Log "This script requires administrator privileges." -Level "ERROR"
        Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Red
        exit 1
    }

    Write-Log "Administrator privileges verified" -Level "SUCCESS"
}

function Test-HyperVAvailable {
    Write-Log "Checking Hyper-V availability..." -Level "INFO"

    $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue
    if (-not $hyperv -or $hyperv.State -ne "Enabled") {
        Write-Log "Hyper-V is not enabled. Please enable it first (e.g. via MakePCReady.ps1)." -Level "ERROR"
        return $false
    }

    $vmms = Get-Service vmms -ErrorAction SilentlyContinue
    if (-not $vmms -or $vmms.Status -ne "Running") {
        Write-Log "Hyper-V Virtual Machine Management service is not running." -Level "ERROR"
        return $false
    }

    Write-Log "Hyper-V is available and running" -Level "SUCCESS"
    return $true
}

function Test-NonInteractiveConfig {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config,
        [object[]]$AvailableSwitches,
        [string]$BasePath
    )

    $validationErrors = @()

    if ([string]::IsNullOrWhiteSpace($Config.VMName)) {
        $validationErrors += "VM name cannot be empty in non-interactive mode."
    }
    else {
        $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
        if ($Config.VMName.IndexOfAny($invalidChars) -ge 0) {
            $validationErrors += "VM name '$($Config.VMName)' contains invalid file name characters."
        }
    }

    $maxCPU = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    if ($Config.CPUs -lt 1 -or $Config.CPUs -gt $maxCPU) {
        $validationErrors += "CPUCount must be between 1 and $maxCPU. Received: $($Config.CPUs)."
    }

    if ($Config.Memory -lt 1GB) {
        $validationErrors += "MemoryBytes must be at least 1 GB. Received: $([math]::Round($Config.Memory / 1MB, 0)) MB."
    }

    $hostMemory = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
    if ($Config.Memory -gt $hostMemory) {
        $validationErrors += "MemoryBytes cannot exceed host physical memory ($([math]::Round($hostMemory / 1GB, 2)) GB). Received: $([math]::Round($Config.Memory / 1GB, 2)) GB."
    }

    if ($Config.DiskSize -lt 40GB) {
        $validationErrors += "DiskSizeBytes must be at least 40 GB. Received: $([math]::Round($Config.DiskSize / 1GB, 2)) GB."
    }

    if ($Config.SwitchName) {
        if (-not $AvailableSwitches -or $AvailableSwitches.Count -eq 0) {
            $validationErrors += "SwitchName '$($Config.SwitchName)' was provided, but no Hyper-V switches are available."
        }
        else {
            $switchExists = @($AvailableSwitches | Where-Object { $_.Name -eq $Config.SwitchName }).Count -gt 0
            if (-not $switchExists) {
                $availableNames = @($AvailableSwitches | ForEach-Object { $_.Name }) -join ", "
                $validationErrors += "SwitchName '$($Config.SwitchName)' does not exist. Available switches: $availableNames"
            }
        }
    }

    if ($BasePath -and -not (Test-Path -Path $BasePath)) {
        try {
            New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
            Write-Log "Created VM base path: $BasePath" -Level "INFO"
        }
        catch {
            $validationErrors += "VMPath '$BasePath' does not exist and could not be created: $($_.Exception.Message)"
        }
    }

    if ($validationErrors.Count -gt 0) {
        Write-Log "Non-interactive parameter validation failed:" -Level "ERROR"
        foreach ($err in $validationErrors) {
            Write-Log "  - $err" -Level "ERROR"
        }
        return $false
    }

    Write-Log "Non-interactive parameter validation passed." -Level "SUCCESS"
    return $true
}

# ============================================================================
# ISO Acquisition
# ============================================================================

function Get-WindowsISOViaFido {
    param (
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
    } while ($osChoice -notin @("1", "2"))

    if ($osChoice -eq "1") {
        $fidoWin = "Windows 11"
        $fidoEd = "Windows 11 Home/Pro/Edu"
        $defaultFileName = "Windows11.iso"
    } else {
        $fidoWin = "Windows 10"
        $fidoEd = "Windows 10 Home/Pro/Edu"
        $defaultFileName = "Windows10.iso"
    }

    # ---- Language Selection ----
    $languages = @(
        @{ Name = "English (US)";           Code = "English" },
        @{ Name = "English International";  Code = "English International" },
        @{ Name = "German";                 Code = "German" },
        @{ Name = "French";                 Code = "French" },
        @{ Name = "Spanish";                Code = "Spanish" },
        @{ Name = "Italian";                Code = "Italian" },
        @{ Name = "Portuguese (Brazil)";    Code = "Brazilian Portuguese" },
        @{ Name = "Dutch";                  Code = "Dutch" },
        @{ Name = "Japanese";               Code = "Japanese" },
        @{ Name = "Korean";                 Code = "Korean" },
        @{ Name = "Chinese Simplified";     Code = "Chinese (Simplified)" },
        @{ Name = "Chinese Traditional";    Code = "Chinese (Traditional)" },
        @{ Name = "Russian";                Code = "Russian" },
        @{ Name = "Polish";                 Code = "Polish" },
        @{ Name = "Swedish";                Code = "Swedish" },
        @{ Name = "Turkish";                Code = "Turkish" },
        @{ Name = "Arabic";                 Code = "Arabic" }
    )

    Write-Host ""
    Write-Host "Select language:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $languages.Count; $i++) {
        Write-Host "  [$($i+1)] $($languages[$i].Name)" -ForegroundColor White
    }
    Write-Host ""

    $langChoice = Read-ValidatedInteger -Prompt "Select language (1-$($languages.Count)) [1]" -Min 1 -Max $languages.Count -DefaultValue 1

    $fidoLang = $languages[$langChoice - 1].Code

    # ---- Architecture Selection ----
    Write-Host ""
    Write-Host "Select architecture:" -ForegroundColor Cyan
    Write-Host "  [1] x64 (recommended)" -ForegroundColor White
    $hostArch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
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
    $fidoPath = Join-Path -Path $env:TEMP -ChildPath "Fido.ps1"

    try {
        Write-Log "Fetching FIDO.ps1 from GitHub..." -Level "INFO"
        Invoke-WebRequest -Uri $fidoUrl -OutFile $fidoPath -UseBasicParsing -ErrorAction Stop
        Unblock-File -Path $fidoPath -ErrorAction SilentlyContinue
        Write-Log "FIDO.ps1 downloaded successfully" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to download FIDO.ps1: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }

    # Get the download URL using FIDO in command-line mode
    Write-Log "Querying Microsoft for $fidoWin ISO download link..." -Level "INFO"
    Write-Log "This may take a moment as FIDO negotiates with Microsoft's servers..." -Level "INFO"

    try {
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

        try {
            Start-BitsTransfer -Source $isoUrl -Destination $outputPath -ErrorAction Stop
        }
        catch {
            Write-Log "BITS transfer failed, falling back to Invoke-WebRequest: $($_.Exception.Message)" -Level "WARNING"
            Invoke-WebRequest -Uri $isoUrl -OutFile $outputPath -UseBasicParsing -ErrorAction Stop
        }

        if (Test-Path -Path $outputPath) {
            $fileSize = [math]::Round((Get-Item $outputPath).Length / 1GB, 2)
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
    param (
        [string]$DownloadFolder
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
    } while ($osChoice -notin @("1", "2"))

    if ($osChoice -eq "1") {
        $searchQuery = "Windows+11"
        $titleFilter = "Windows 11, version"
        $osLabel = "Windows 11"
    } else {
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

    if (-not $response.response.builds) {
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
    Write-Log "Selected language: $selectedLang" -Level "INFO"

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
    $packageZip = Join-Path -Path $env:TEMP -ChildPath "uupdump_package.zip"
    $packageDir = Join-Path -Path $env:TEMP -ChildPath "uupdump_work"

    Write-Log "Downloading UUP dump creation package..." -Level "INFO"

    try {
        Invoke-WebRequest -Uri $packageUrl -OutFile $packageZip -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Log "Failed to download UUP dump package: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "You can manually download from: https://uupdump.net/selectlang.php?id=$($selectedBuild.uuid)" -Level "INFO"
        return $null
    }

    # Step 3: Extract and run the converter
    if (Test-Path -Path $packageDir) {
        Remove-Item -Path $packageDir -Recurse -Force
    }

    Write-Log "Extracting UUP dump package..." -Level "INFO"
    try {
        Expand-Archive -Path $packageZip -DestinationPath $packageDir -Force -ErrorAction Stop
    }
    catch {
        Write-Log "Failed to extract package: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }

    $cmdScript = Join-Path -Path $packageDir -ChildPath "uup_download_windows.cmd"
    if (-not (Test-Path -Path $cmdScript)) {
        Write-Log "uup_download_windows.cmd not found in the package." -Level "ERROR"
        Write-Log "Package contents: $(Get-ChildItem $packageDir -Name | Out-String)" -Level "WARNING"
        return $null
    }

    Write-Log "Running UUP dump converter (this downloads UUPs and builds the ISO)..." -Level "INFO"
    Write-Log "This will take a LONG time (downloading ~4 GB of UUP files + conversion)..." -Level "WARNING"
    Write-Log "A new window will open - do NOT close it until it finishes." -Level "WARNING"

    try {
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$cmdScript`"" `
            -WorkingDirectory $packageDir -Wait -PassThru
        Write-Log "UUP dump converter exited with code: $($process.ExitCode)" -Level "INFO"
    }
    catch {
        Write-Log "Failed to run UUP dump converter: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }

    # Step 4: Find the resulting ISO
    $resultISOs = @(Get-ChildItem -Path $packageDir -Filter "*.iso" -File -ErrorAction SilentlyContinue)
    if ($resultISOs.Count -eq 0) {
        Write-Log "No ISO file was produced by the UUP dump converter." -Level "ERROR"
        Write-Log "Check the converter window for errors." -Level "INFO"
        return $null
    }

    $sourceISO = $resultISOs | Sort-Object Length -Descending | Select-Object -First 1
    $destISO = Join-Path -Path $DownloadFolder -ChildPath $sourceISO.Name

    Write-Log "Moving built ISO to: $destISO" -Level "INFO"
    Move-Item -Path $sourceISO.FullName -Destination $destISO -Force

    # Cleanup temp files
    Remove-Item -Path $packageZip -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $packageDir -Recurse -Force -ErrorAction SilentlyContinue

    $fileSize = [math]::Round((Get-Item $destISO).Length / 1GB, 2)
    Write-Log "ISO built successfully ($fileSize GB): $destISO" -Level "SUCCESS"
    return $destISO
}

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
    } while ($choice -notin @("1", "2", "3"))

    return [int]$choice
}

function Select-LocalISO {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select Windows Installation ISO"
    $dialog.Filter = "ISO Files (*.iso)|*.iso"
    $dialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.FileName
    }

    return $null
}

# ============================================================================
# VM Configuration UI
# ============================================================================

function Get-AvailableVMSwitches {
    $switches = @(Get-VMSwitch -ErrorAction SilentlyContinue)
    return $switches
}

function Show-VMConfigMenu {
    param (
        [string]$DefaultVMName,
        [object[]]$AvailableSwitches
    )

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  VM Configuration" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""

    # VM Name
    $defaultName = if ($DefaultVMName) { $DefaultVMName } else { "TestVM-$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
    $nameInput = Read-Host "VM Name [$defaultName]"
    $vmName = if ([string]::IsNullOrWhiteSpace($nameInput)) { $defaultName } else { $nameInput }

    # Memory
    Write-Host ""
    Write-Host "Memory options:" -ForegroundColor Gray
    Write-Host "  [1] 2 GB" -ForegroundColor White
    Write-Host "  [2] 4 GB (recommended)" -ForegroundColor White
    Write-Host "  [3] 8 GB" -ForegroundColor White
    Write-Host "  [4] Custom" -ForegroundColor White
    $memChoice = Read-ValidatedInteger -Prompt "Select memory [2]" -Min 1 -Max 4 -DefaultValue 2

    $memory = switch ($memChoice) {
        1 { 2GB }
        2 { 4GB }
        3 { 8GB }
        4 {
            $customMem = Read-PositiveInteger -Prompt "Enter memory in GB" -DefaultValue 4
            [int64]$customMem * 1GB
        }
        default { 4GB }
    }

    # CPUs
    $maxCPU = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    $defaultCPU = [Math]::Min(2, $maxCPU)
    $cpus = Read-ValidatedInteger -Prompt "CPU cores (1-$maxCPU) [$defaultCPU]" -Min 1 -Max $maxCPU -DefaultValue $defaultCPU

    # Disk Size
    Write-Host ""
    Write-Host "Disk size options:" -ForegroundColor Gray
    Write-Host "  [1] 40 GB (minimum)" -ForegroundColor White
    Write-Host "  [2] 64 GB (recommended)" -ForegroundColor White
    Write-Host "  [3] 128 GB" -ForegroundColor White
    Write-Host "  [4] Custom" -ForegroundColor White
    $diskChoice = Read-ValidatedInteger -Prompt "Select disk size [2]" -Min 1 -Max 4 -DefaultValue 2

    $diskSize = switch ($diskChoice) {
        1 { 40GB }
        2 { 64GB }
        3 { 128GB }
        4 {
            $customDisk = Read-PositiveInteger -Prompt "Enter disk size in GB" -DefaultValue 64
            [int64]$customDisk * 1GB
        }
        default { 64GB }
    }

    # Network Switch
    Write-Host ""
    $selectedSwitch = $null
    if ($AvailableSwitches.Count -gt 0) {
        Write-Host "Available network switches:" -ForegroundColor Gray
        Write-Host "  [0] No network adapter" -ForegroundColor White
        for ($i = 0; $i -lt $AvailableSwitches.Count; $i++) {
            $sw = $AvailableSwitches[$i]
            $marker = if ($sw.SwitchType -eq "External") { " (recommended)" } else { "" }
            Write-Host "  [$($i+1)] $($sw.Name) ($($sw.SwitchType))$marker" -ForegroundColor White
        }

        # Default to first external switch, or first switch
        $defaultSwitchIdx = 0
        for ($i = 0; $i -lt $AvailableSwitches.Count; $i++) {
            if ($AvailableSwitches[$i].SwitchType -eq "External") {
                $defaultSwitchIdx = $i + 1
                break
            }
        }
        if ($defaultSwitchIdx -eq 0 -and $AvailableSwitches.Count -gt 0) { $defaultSwitchIdx = 1 }

        $switchIdx = Read-ValidatedInteger -Prompt "Select network switch [$defaultSwitchIdx]" -Min 0 -Max $AvailableSwitches.Count -DefaultValue $defaultSwitchIdx

        if ($switchIdx -gt 0 -and $switchIdx -le $AvailableSwitches.Count) {
            $selectedSwitch = $AvailableSwitches[$switchIdx - 1].Name
        }
    }
    else {
        Write-Host "No Hyper-V virtual switches found." -ForegroundColor Yellow
        Write-Host "The VM will be created without a network adapter." -ForegroundColor Yellow
        Write-Host "You can create a switch later via Hyper-V Manager or:" -ForegroundColor Gray
        Write-Host "  New-VMSwitch -Name 'External' -NetAdapterName (Get-NetAdapter | Select -First 1).Name" -ForegroundColor Gray
    }

    return @{
        VMName     = $vmName
        Memory     = $memory
        CPUs       = $cpus
        DiskSize   = $diskSize
        SwitchName = $selectedSwitch
    }
}

# ============================================================================
# VM Creation
# ============================================================================

function New-TestVM {
    param (
        [Parameter(Mandatory)]
        [string]$VMName,
        [Parameter(Mandatory)]
        [string]$WindowsISOPath,
        [Parameter(Mandatory)]
        [string]$UnattendISOPath,
        [int64]$Memory = 4GB,
        [int]$CPUs = 2,
        [int64]$DiskSize = 64GB,
        [string]$SwitchName,
        [string]$BasePath
    )

    # Determine VM storage path
    if (-not $BasePath) {
        $defaultPath = (Get-VMHost).VirtualMachinePath
        if ([string]::IsNullOrWhiteSpace($defaultPath)) {
            $defaultPath = "C:\Hyper-V"
        }
        $BasePath = $defaultPath
    }

    $vmFolder = Join-Path -Path $BasePath -ChildPath $VMName
    $vhdxPath = Join-Path -Path $vmFolder -ChildPath "$VMName.vhdx"

    Write-Log "Creating VM: $VMName" -Level "INFO"
    Write-Log "  Path:   $vmFolder" -Level "INFO"
    Write-Log "  Memory: $([math]::Round($Memory / 1GB, 1)) GB" -Level "INFO"
    Write-Log "  CPUs:   $CPUs" -Level "INFO"
    Write-Log "  Disk:   $([math]::Round($DiskSize / 1GB, 0)) GB" -Level "INFO"
    Write-Log "  Switch: $(if ($SwitchName) { $SwitchName } else { 'None' })" -Level "INFO"

    # Check if VM already exists
    $existingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    if ($existingVM) {
        Write-Log "A VM with the name '$VMName' already exists." -Level "ERROR"
        return $false
    }

    try {
        # Create VM directory
        if (-not (Test-Path -Path $vmFolder)) {
            New-Item -ItemType Directory -Path $vmFolder -Force | Out-Null
        }

        # Create the VHDX
        Write-Log "Creating virtual hard disk: $vhdxPath" -Level "INFO"
        New-VHD -Path $vhdxPath -SizeBytes $DiskSize -Dynamic | Out-Null
        Write-Log "VHDX created" -Level "SUCCESS"

        # Create the Gen 2 VM
        $vmParams = @{
            Name               = $VMName
            MemoryStartupBytes = $Memory
            Generation         = 2
            VHDPath            = $vhdxPath
            Path               = $BasePath
        }

        if ($SwitchName) {
            $vmParams["SwitchName"] = $SwitchName
        }

        Write-Log "Creating Generation 2 VM..." -Level "INFO"
        New-VM @vmParams | Out-Null
        Write-Log "VM created" -Level "SUCCESS"

        # Configure VM settings
        Write-Log "Configuring VM settings..." -Level "INFO"

        Set-VM -Name $VMName -ProcessorCount $CPUs -CheckpointType Standard -AutomaticCheckpointsEnabled $false

        # Disable Secure Boot for broader ISO compatibility
        Set-VMFirmware -VMName $VMName -EnableSecureBoot Off

        # Add DVD drive for the Windows ISO (if not already present)
        $dvdDrives = Get-VMDvdDrive -VMName $VMName
        if ($dvdDrives.Count -eq 0) {
            Add-VMDvdDrive -VMName $VMName
        }

        # Attach Windows ISO to the first DVD drive
        $dvd1 = Get-VMDvdDrive -VMName $VMName | Select-Object -First 1
        Set-VMDvdDrive -VMName $VMName -ControllerNumber $dvd1.ControllerNumber -ControllerLocation $dvd1.ControllerLocation -Path $WindowsISOPath
        Write-Log "Windows ISO attached: $WindowsISOPath" -Level "SUCCESS"

        # Add second DVD drive for unattend ISO
        Add-VMDvdDrive -VMName $VMName -Path $UnattendISOPath
        Write-Log "Unattend ISO attached: $UnattendISOPath" -Level "SUCCESS"

        # Set boot order: DVD first, then hard drive
        $dvdDrives = Get-VMDvdDrive -VMName $VMName
        $hdd = Get-VMHardDiskDrive -VMName $VMName
        $bootDevices = @($dvdDrives[0]) + @($hdd) + @($dvdDrives | Select-Object -Skip 1)
        Set-VMFirmware -VMName $VMName -BootOrder $bootDevices

        # Enable TPM for Windows 11 (if available on host)
        try {
            $keyProtector = New-HgsGuardian -Name "UntrustedGuardian_$VMName" -GenerateCertificates -ErrorAction SilentlyContinue
            if (-not $keyProtector) {
                $keyProtector = Get-HgsGuardian -Name "UntrustedGuardian_$VMName" -ErrorAction SilentlyContinue
            }
            if ($keyProtector) {
                $kp = New-HgsKeyProtector -Owner $keyProtector -AllowUntrustedRoot
                Set-VMKeyProtector -VMName $VMName -KeyProtector $kp.RawData
                Enable-VMTPM -VMName $VMName
                Write-Log "Virtual TPM enabled" -Level "SUCCESS"
            }
        }
        catch {
            Write-Log "Could not enable virtual TPM (not critical - bypassed in unattend): $($_.Exception.Message)" -Level "WARNING"
        }

        Write-Log "VM '$VMName' configured successfully" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to create VM: $($_.Exception.Message)" -Level "ERROR"

        # Cleanup on failure
        $failedVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
        if ($failedVM) {
            Remove-VM -Name $VMName -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -Path $vhdxPath) {
            Remove-Item -Path $vhdxPath -Force -ErrorAction SilentlyContinue
        }
        Remove-HgsGuardian -Name "UntrustedGuardian_$VMName" -ErrorAction SilentlyContinue

        return $false
    }
}

# ============================================================================
# Summary & Confirmation
# ============================================================================

function Show-Summary {
    param (
        [hashtable]$Config,
        [string]$ISOPath,
        [string]$UnattendPath
    )

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  VM Creation Summary" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  VM Name:    $($Config.VMName)" -ForegroundColor White
    Write-Host "  Memory:     $([math]::Round($Config.Memory / 1GB, 1)) GB" -ForegroundColor White
    Write-Host "  CPUs:       $($Config.CPUs)" -ForegroundColor White
    Write-Host "  Disk:       $([math]::Round($Config.DiskSize / 1GB, 0)) GB" -ForegroundColor White
    Write-Host "  Switch:     $(if ($Config.SwitchName) { $Config.SwitchName } else { 'None' })" -ForegroundColor White
    Write-Host "  Generation: 2 (UEFI)" -ForegroundColor White
    Write-Host ""
    Write-Host "  ISO:        $ISOPath" -ForegroundColor White
    Write-Host "  Unattend:   $UnattendPath" -ForegroundColor White
    Write-Host ""
    Write-Host "  The VM will auto-install Windows with:" -ForegroundColor Gray
    Write-Host "    - Local account 'User' (no password)" -ForegroundColor Gray
    Write-Host "    - Edition per unattend.xml (not activated)" -ForegroundColor Gray
    Write-Host "    - All OOBE screens skipped" -ForegroundColor Gray
    Write-Host "    - Win11 hardware requirements bypassed" -ForegroundColor Gray
    Write-Host ""

    $confirm = Read-Host "Proceed with VM creation? (Y/n)"
    return ($confirm -eq "" -or $confirm -imatch "^y")
}

# ============================================================================
# Finalize Log
# ============================================================================

function Complete-Log {
    param ([bool]$Success)

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
        Write-Host "VM creation completed successfully!" -ForegroundColor Green
        Write-Host "Log: $script:logFile" -ForegroundColor Gray
    }
    else {
        Write-Host ""
        Write-Host "VM creation failed. Check the log for details." -ForegroundColor Red
        Write-Host "Log: $script:logFile" -ForegroundColor Gray
    }
}

# ============================================================================
# Main Flow
# ============================================================================

function Main {
    Initialize-Log
    Test-AdminPrivileges

    if (-not (Test-HyperVAvailable)) {
        Complete-Log -Success $false
        exit 1
    }

    $isNonInteractive = $NonInteractive.IsPresent
    if ($isNonInteractive) {
        Write-Log "Running in non-interactive mode." -Level "INFO"
        if ($OpenConsole -and -not $StartVM) {
            Write-Log "-OpenConsole was set without -StartVM. Console launch will be skipped." -Level "WARNING"
        }
    }

    # ---- Step 1: Resolve Windows ISO ----
    $isoPath = $ISOPath

    if (-not $isoPath) {
        if ($isNonInteractive) {
            Write-Log "Non-interactive mode requires -ISOPath." -Level "ERROR"
            Complete-Log -Success $false
            exit 1
        }

        $isoSource = Show-ISOSourceMenu

        switch ($isoSource) {
            1 {
                $downloadFolder = Join-Path -Path $env:USERPROFILE -ChildPath "Downloads"
                $isoPath = Get-WindowsISOViaFido -DownloadFolder $downloadFolder
            }
            2 {
                $downloadFolder = Join-Path -Path $env:USERPROFILE -ChildPath "Downloads"
                $isoPath = Get-WindowsISOViaUUPDump -DownloadFolder $downloadFolder
            }
            3 {
                $isoPath = Select-LocalISO
            }
        }
    }

    if (-not $isoPath -or -not (Test-Path -Path $isoPath)) {
        Write-Log "No valid Windows ISO selected or found. Aborting." -Level "ERROR"
        Complete-Log -Success $false
        exit 1
    }

    Write-Log "Windows ISO: $isoPath" -Level "SUCCESS"

    # ---- Step 2: Resolve Unattend ISO ----
    $unattendISOPath = $UnattendISOPath
    if (-not $unattendISOPath) {
        $unattendISOPath = Join-Path -Path $script:scriptRoot -ChildPath "unattend.iso"
    }

    if (-not (Test-Path -Path $unattendISOPath)) {
        Write-Log "Unattend ISO not found at: $unattendISOPath" -Level "ERROR"
        Write-Log "Expected file: unattend.iso in the same folder as this script." -Level "ERROR"
        Write-Log "Generate your autounattend.xml at https://schneegans.de/windows/unattend-generator/" -Level "INFO"
        Write-Log "Then download it as '.xml wrapped in .iso' and place it as unattend.iso in the repo root." -Level "INFO"
        Complete-Log -Success $false
        exit 1
    }

    Write-Log "Unattend ISO: $unattendISOPath" -Level "SUCCESS"

    # ---- Step 3: VM Configuration ----
    $switches = Get-AvailableVMSwitches

    if ($isNonInteractive) {
        $resolvedVMName = if ([string]::IsNullOrWhiteSpace($VMName)) { "TestVM-$(Get-Date -Format 'yyyyMMdd-HHmmss')" } else { $VMName }
        if (-not $VMName) {
            Write-Log "No -VMName provided. Using generated name: $resolvedVMName" -Level "INFO"
        }

        $vmConfig = @{
            VMName     = $resolvedVMName
            Memory     = $MemoryBytes
            CPUs       = $CPUCount
            DiskSize   = $DiskSizeBytes
            SwitchName = $SwitchName
        }
    }
    elseif ($VMName -and $ISOPath) {
        # Enough CLI params provided - skip interactive menu but still validate
        $vmConfig = @{
            VMName     = $VMName
            Memory     = $MemoryBytes
            CPUs       = $CPUCount
            DiskSize   = $DiskSizeBytes
            SwitchName = $SwitchName
        }

        if (-not (Test-NonInteractiveConfig -Config $vmConfig -AvailableSwitches $switches -BasePath $VMPath)) {
            Complete-Log -Success $false
            exit 1
        }
    }
    else {
        # Interactive configuration
        $vmConfig = Show-VMConfigMenu -DefaultVMName $VMName -AvailableSwitches $switches
    }

    if ($isNonInteractive) {
        $switchLabel = if ([string]::IsNullOrWhiteSpace($vmConfig.SwitchName)) { "None" } else { $vmConfig.SwitchName }
        $vmPathLabel = if ([string]::IsNullOrWhiteSpace($VMPath)) { "(Hyper-V default)" } else { $VMPath }
        Write-Log "Non-interactive config: VMName='$($vmConfig.VMName)', ISOPath='$isoPath', UnattendISOPath='$unattendISOPath', MemoryGB=$([math]::Round($vmConfig.Memory / 1GB, 2)), CPUs=$($vmConfig.CPUs), DiskGB=$([math]::Round($vmConfig.DiskSize / 1GB, 2)), Switch='$switchLabel', VMPath='$vmPathLabel'" -Level "INFO"

        if (-not (Test-NonInteractiveConfig -Config $vmConfig -AvailableSwitches $switches -BasePath $VMPath)) {
            Complete-Log -Success $false
            exit 1
        }
    }

    # ---- Step 4: Confirm & Create ----
    if ($isNonInteractive) {
        Write-Log "Non-interactive mode: skipping confirmation prompt." -Level "INFO"
    }
    elseif (-not (Show-Summary -Config $vmConfig -ISOPath $isoPath -UnattendPath $unattendISOPath)) {
        Write-Log "User cancelled VM creation." -Level "WARNING"
        Complete-Log -Success $false
        exit 0
    }

    $createParams = @{
        VMName         = $vmConfig.VMName
        WindowsISOPath = $isoPath
        UnattendISOPath = $unattendISOPath
        Memory         = $vmConfig.Memory
        CPUs           = $vmConfig.CPUs
        DiskSize       = $vmConfig.DiskSize
        SwitchName     = $vmConfig.SwitchName
    }

    if ($VMPath) {
        $createParams["BasePath"] = $VMPath
    }

    $success = New-TestVM @createParams

    if ($success) {
        if ($isNonInteractive) {
            if ($StartVM) {
                Write-Log "Starting VM '$($vmConfig.VMName)'..." -Level "INFO"
                Start-VM -Name $vmConfig.VMName
                Write-Log "VM started! Windows installation is running unattended." -Level "SUCCESS"
                Write-Log "You can connect via: vmconnect localhost $($vmConfig.VMName)" -Level "INFO"

                if ($OpenConsole) {
                    Start-Process "vmconnect" -ArgumentList "localhost", "`"$($vmConfig.VMName)`""
                }
            }
            else {
                Write-Log "Non-interactive mode: VM created but not started. Use -StartVM to start automatically." -Level "INFO"
            }
        }
        else {
            # ---- Step 5: Start the VM ----
            Write-Host ""
            $startNow = Read-Host "Start the VM now? (Y/n)"
            if ($startNow -eq "" -or $startNow -imatch "^y") {
                Write-Log "Starting VM '$($vmConfig.VMName)'..." -Level "INFO"
                Start-VM -Name $vmConfig.VMName
                Write-Log "VM started! Windows installation is running unattended." -Level "SUCCESS"
                Write-Log "You can connect via: vmconnect localhost $($vmConfig.VMName)" -Level "INFO"

                Write-Host ""
                $connectNow = Read-Host "Open VM console now? (Y/n)"
                if ($connectNow -eq "" -or $connectNow -imatch "^y") {
                    Start-Process "vmconnect" -ArgumentList "localhost", "`"$($vmConfig.VMName)`""
                }
            }
        }
    }

    Complete-Log -Success $success
}

# Run
Main
