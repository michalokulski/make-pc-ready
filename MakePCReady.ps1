param (
    [string]$LogPath = "$env:USERPROFILE\Desktop\MakePCReady.log",
    [switch]$SkipInteractiveSelection
)

# ============================================================================
# PowerShell PC Setup & Package Installation Script with Logging
# ============================================================================

$script:logFile = $LogPath
$script:logStartTime = Get-Date

# Application catalog (edit this list to manage available apps)
$script:appCatalog = @(
    [PSCustomObject]@{ Id = "7zip.7zip"; Name = "7-Zip"; DefaultSelected = $true }
    [PSCustomObject]@{ Id = "Git.Git"; Name = "Git"; DefaultSelected = $true }
    [PSCustomObject]@{ Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code"; DefaultSelected = $true }
    [PSCustomObject]@{ Id = "Microsoft.PowerShell"; Name = "PowerShell 7"; DefaultSelected = $true }
    [PSCustomObject]@{ Id = "Microsoft.Sysinternals.Suite"; Name = "Sysinternals Suite"; DefaultSelected = $true }
    [PSCustomObject]@{ Id = "Notepad++.Notepad++"; Name = "Notepad++"; DefaultSelected = $true }
    [PSCustomObject]@{ Id = "REALiX.HWiNFO"; Name = "HWiNFO"; DefaultSelected = $false }
    [PSCustomObject]@{ Id = "WinDirStat.WinDirStat"; Name = "WinDirStat"; DefaultSelected = $false }
)

function Initialize-Log {
    $header = @"
================================================================================
PC Setup & Package Installation Log
Started: $($script:logStartTime.ToString('yyyy-MM-dd HH:mm:ss'))
User: $env:USERNAME
Computer: $env:COMPUTERNAME
PowerShell Version: $($PSVersionTable.PSVersion.ToString())
================================================================================

"@

    $logDir = Split-Path -Path $script:logFile -Parent
    if (-not (Test-Path -Path $logDir)) {
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
        $colors = @{
            "SUCCESS" = "Green"
            "INFO"    = "White"
            "WARNING" = "Yellow"
            "ERROR"   = "Red"
        }

        if ($colors.ContainsKey($Level)) {
            $color = $colors[$Level]
        }
        else {
            $color = "White"
        }

        Write-Host $logMessage -ForegroundColor $color
    }
}

function Test-AdminPrivileges {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Log "This script requires administrator privileges." -Level "ERROR"
        Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Red
        exit 1
    }

    Write-Log "Administrator privileges verified" -Level "SUCCESS"
}

function Invoke-WingetCommand {
    param (
        [string[]]$Arguments
    )

    $commandOutput = & winget @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    return @{
        StdOut   = $commandOutput
        ExitCode = $exitCode
    }
}

function Ensure-Winget {
    Write-Log "Checking for Winget installation..." -Level "INFO"

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        $versionInfo = Invoke-WingetCommand -Arguments @("--version")
        if ($versionInfo.ExitCode -eq 0) {
            Write-Log "Winget found: $($versionInfo.StdOut | Select-Object -First 1)" -Level "SUCCESS"
            return $true
        }
    }

    Write-Log "Winget not found. Trying to install from https://aka.ms/getwinget ..." -Level "WARNING"

    try {
        $msixPath = Join-Path -Path $env:TEMP -ChildPath "winget.msixbundle"
        Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile $msixPath -UseBasicParsing
        Add-AppxPackage -Path $msixPath -ErrorAction Stop
        Start-Sleep -Seconds 3
    }
    catch {
        Write-Log "Failed to install Winget automatically: $_" -Level "ERROR"
        return $false
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Log "Winget still not available after installation attempt." -Level "ERROR"
        return $false
    }

    Write-Log "Winget installation completed" -Level "SUCCESS"
    return $true
}

function Update-WingetSources {
    Write-Log "Updating Winget package sources..." -Level "INFO"

    $result = Invoke-WingetCommand -Arguments @("source", "update")
    if ($result.ExitCode -eq 0) {
        Write-Log "Winget sources updated successfully" -Level "SUCCESS"
    }
    else {
        Write-Log "Could not update Winget sources. Continuing anyway." -Level "WARNING"
        foreach ($line in $result.StdOut) {
            Write-Log "winget: $line" -Level "WARNING" -NoConsole
        }
    }
}

function Test-PackageInstalled {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageId
    )

    $result = Invoke-WingetCommand -Arguments @("list", "--id", $PackageId, "--exact")
    if ($result.ExitCode -ne 0) {
        return $false
    }

    $allText = ($result.StdOut | Out-String)
    if ($allText -match "No installed package found matching input criteria") {
        return $false
    }

    return ($allText -match [Regex]::Escape($PackageId))
}

function Install-Package {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageId,
        [string]$PackageName = $PackageId
    )

    if (Test-PackageInstalled -PackageId $PackageId) {
        Write-Log "Already installed: $PackageName ($PackageId). Skipping." -Level "INFO"
        return $true
    }

    Write-Log "Installing: $PackageName ($PackageId)" -Level "INFO"

    $args = @(
        "install"
        "--id", $PackageId
        "--exact"
        "--silent"
        "--accept-package-agreements"
        "--accept-source-agreements"
    )

    $result = Invoke-WingetCommand -Arguments $args
    if ($result.ExitCode -eq 0) {
        Write-Log "Installed: $PackageName" -Level "SUCCESS"
        return $true
    }

    Write-Log "Failed to install: $PackageName (exit code $($result.ExitCode))" -Level "ERROR"
    foreach ($line in $result.StdOut) {
        Write-Log "winget: $line" -Level "ERROR" -NoConsole
    }
    return $false
}

function Install-Packages {
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Packages
    )

    if (-not $Packages -or $Packages.Count -eq 0) {
        Write-Log "No applications selected. Skipping application installation." -Level "WARNING"
        return @{ Installed = 0; Failed = 0; Skipped = 0 }
    }

    Write-Log "========================================" -Level "INFO"
    Write-Log "Starting application installation (Total: $($Packages.Count))" -Level "INFO"
    Write-Log "========================================" -Level "INFO"

    $installed = 0
    $failed = 0
    $skipped = 0

    foreach ($pkg in $Packages) {
        $alreadyInstalled = $false
        if ($pkg.PSObject.Properties.Name -contains "IsInstalled") {
            $alreadyInstalled = [bool]$pkg.IsInstalled
        }
        else {
            $alreadyInstalled = Test-PackageInstalled -PackageId $pkg.Id
        }

        if ($alreadyInstalled) {
            Write-Log "Already installed: $($pkg.Name) ($($pkg.Id)). Skipping." -Level "INFO"
            $skipped++
            continue
        }

        if (Install-Package -PackageId $pkg.Id -PackageName $pkg.Name) {
            $installed++
        }
        else {
            $failed++
        }

        Start-Sleep -Milliseconds 400
    }

    Write-Log "========================================" -Level "INFO"
    Write-Log "Application Summary: $installed installed, $skipped skipped, $failed failed" -Level "INFO"
    Write-Log "========================================" -Level "INFO"

    return @{ Installed = $installed; Failed = $failed; Skipped = $skipped }
}

function Show-InteractiveAppSelector {
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Catalog
    )

    $selection = @()
    foreach ($item in $Catalog) {
        $selection += [PSCustomObject]@{
            Id          = $item.Id
            Name        = $item.Name
            Selected    = [bool]$item.DefaultSelected
            IsInstalled = [bool]$item.IsInstalled
        }
    }

    while ($true) {
        Clear-Host
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host " MakePCReady - App Selection" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Toggle apps by typing numbers (comma-separated)." -ForegroundColor Gray
        Write-Host "Commands: [A]ll, [N]one, [S]tart, [Q]uit" -ForegroundColor Gray
        Write-Host ""

        for ($i = 0; $i -lt $selection.Count; $i++) {
            $mark = if ($selection[$i].Selected) { "[x]" } else { "[ ]" }
            $state = if ($selection[$i].IsInstalled) { "(Installed)" } else { "(Not installed)" }
            Write-Host ("{0,2}. {1} {2} {3}" -f ($i + 1), $mark, $selection[$i].Name, $state)
        }

        Write-Host ""
        $inputValue = Read-Host "Choice"

        if ([string]::IsNullOrWhiteSpace($inputValue)) {
            continue
        }

        switch ($inputValue.Trim().ToUpperInvariant()) {
            "A" {
                foreach ($entry in $selection) {
                    $entry.Selected = $true
                }
                continue
            }
            "N" {
                foreach ($entry in $selection) {
                    $entry.Selected = $false
                }
                continue
            }
            "S" {
                return $selection | Where-Object { $_.Selected }
            }
            "Q" {
                Write-Log "User canceled application selection. Exiting..." -Level "WARNING"
                exit 0
            }
            default {
                $tokens = $inputValue -split ","
                foreach ($token in $tokens) {
                    $trimmed = $token.Trim()
                    $index = 0
                    if ([int]::TryParse($trimmed, [ref]$index)) {
                        if ($index -ge 1 -and $index -le $selection.Count) {
                            $selection[$index - 1].Selected = -not $selection[$index - 1].Selected
                        }
                    }
                }
            }
        }
    }
}

function Read-YesNoChoice {
    param (
        [string]$Prompt,
        [bool]$DefaultYes = $true
    )

    $suffix = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    $raw = Read-Host "$Prompt $suffix"

    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $DefaultYes
    }

    $answer = $raw.Trim().ToLowerInvariant()
    return ($answer -eq "y" -or $answer -eq "yes")
}

function Install-VCRedist {
    Write-Log "========================================" -Level "INFO"
    Write-Log "Installing Visual C++ Redistributables..." -Level "INFO"
    Write-Log "========================================" -Level "INFO"

    $vcRedists = @(
        [PSCustomObject]@{ Id = "Microsoft.VCRedist.2005.x64"; Name = "VC++ 2005 x64" }
        [PSCustomObject]@{ Id = "Microsoft.VCRedist.2005.x86"; Name = "VC++ 2005 x86" }
        [PSCustomObject]@{ Id = "Microsoft.VCRedist.2008.x64"; Name = "VC++ 2008 x64" }
        [PSCustomObject]@{ Id = "Microsoft.VCRedist.2008.x86"; Name = "VC++ 2008 x86" }
        [PSCustomObject]@{ Id = "Microsoft.VCRedist.2010.x64"; Name = "VC++ 2010 x64" }
        [PSCustomObject]@{ Id = "Microsoft.VCRedist.2010.x86"; Name = "VC++ 2010 x86" }
        [PSCustomObject]@{ Id = "Microsoft.VCRedist.2012.x64"; Name = "VC++ 2012 x64" }
        [PSCustomObject]@{ Id = "Microsoft.VCRedist.2012.x86"; Name = "VC++ 2012 x86" }
        [PSCustomObject]@{ Id = "Microsoft.VCRedist.2013.x64"; Name = "VC++ 2013 x64" }
        [PSCustomObject]@{ Id = "Microsoft.VCRedist.2013.x86"; Name = "VC++ 2013 x86" }
        [PSCustomObject]@{ Id = "Microsoft.VCRedist.2015+.x64"; Name = "VC++ 2015+ x64" }
        [PSCustomObject]@{ Id = "Microsoft.VCRedist.2015+.x86"; Name = "VC++ 2015+ x86" }
    )

    $result = Install-Packages -Packages $vcRedists
    if ($result.Failed -eq 0) {
        Write-Log "Visual C++ Redistributables completed successfully" -Level "SUCCESS"
        return $true
    }

    Write-Log "Visual C++ Redistributables completed with failures" -Level "WARNING"
    return $false
}

function Install-WSLFromWinget {
    Write-Log "========================================" -Level "INFO"
    Write-Log "Installing Windows Subsystem for Linux (WSL) from Winget..." -Level "INFO"
    Write-Log "========================================" -Level "INFO"

    $ok = Install-Package -PackageId "Microsoft.WSL" -PackageName "Windows Subsystem for Linux"
    if (-not $ok) {
        return $false
    }

    $wslCmd = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if ($wslCmd) {
        Write-Log "WSL command is available (wsl.exe detected)." -Level "SUCCESS"
    }
    else {
        Write-Log "WSL package installed, but wsl.exe was not detected in PATH yet." -Level "WARNING"
    }

    return $true
}

function Enable-HyperV {
    Write-Log "========================================" -Level "INFO"
    Write-Log "Checking/Enabling Hyper-V..." -Level "INFO"
    Write-Log "========================================" -Level "INFO"

    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction Stop
    }
    catch {
        Write-Log "Hyper-V feature query failed: $_" -Level "ERROR"
        return $false
    }

    if ($feature.State -eq "Enabled") {
        Write-Log "Hyper-V is already enabled." -Level "SUCCESS"

        $vmmsService = Get-Service -Name vmms -ErrorAction SilentlyContinue
        if ($vmmsService) {
            Write-Log "Hyper-V management service found: vmms ($($vmmsService.Status))" -Level "INFO"
        }
        else {
            Write-Log "Hyper-V appears enabled, but vmms service was not found." -Level "WARNING"
        }

        return $true
    }

    try {
        $result = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart -ErrorAction Stop
    }
    catch {
        Write-Log "Failed to enable Hyper-V: $_" -Level "ERROR"
        return $false
    }

    $postCheck = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
    if ($postCheck -and $postCheck.State -eq "Enabled") {
        if ($result.RestartNeeded) {
            Write-Log "Hyper-V enabled successfully. Restart required." -Level "SUCCESS"
            Write-Log "System restart is required to complete Hyper-V installation." -Level "WARNING"
        }
        else {
            Write-Log "Hyper-V enabled successfully." -Level "SUCCESS"
        }

        $vmmsService = Get-Service -Name vmms -ErrorAction SilentlyContinue
        if ($vmmsService) {
            Write-Log "Hyper-V management service found: vmms ($($vmmsService.Status))" -Level "INFO"
        }
        else {
            Write-Log "Hyper-V enabled, but vmms service was not found yet (often appears after reboot)." -Level "WARNING"
        }

        return $true
    }

    Write-Log "Hyper-V enable command completed, but final state is not Enabled." -Level "ERROR"
    return $false
}

function Invoke-PCSetup {
    Initialize-Log
    Test-AdminPrivileges

    if (-not (Ensure-Winget)) {
        Write-Log "Cannot continue without Winget. Exiting..." -Level "ERROR"
        exit 1
    }

    Update-WingetSources

    $appCatalog = @()
    foreach ($baseApp in $script:appCatalog) {
        $appCatalog += [PSCustomObject]@{
            Id              = $baseApp.Id
            Name            = $baseApp.Name
            DefaultSelected = [bool]$baseApp.DefaultSelected
        }
    }

    Write-Log "Detecting already installed applications in catalog..." -Level "INFO"
    foreach ($app in $appCatalog) {
        $isInstalled = Test-PackageInstalled -PackageId $app.Id
        Add-Member -InputObject $app -MemberType NoteProperty -Name IsInstalled -Value $isInstalled -Force
        if ($isInstalled) {
            Write-Log "Detected installed: $($app.Name)" -Level "INFO" -NoConsole
        }
    }

    if ($SkipInteractiveSelection) {
        $selectedApps = $appCatalog | Where-Object { $_.DefaultSelected }
        Write-Log "Interactive package selector skipped. Using default selected apps." -Level "INFO"
    }
    else {
        $selectedApps = Show-InteractiveAppSelector -Catalog $appCatalog
        Write-Log "User selected $($selectedApps.Count) applications for installation." -Level "INFO"
    }

    $appResults = Install-Packages -Packages $selectedApps

    $installVcRedist = Read-YesNoChoice -Prompt "Install all VC++ Redistributables?" -DefaultYes $true
    if ($installVcRedist) {
        Install-VCRedist | Out-Null
    }
    else {
        Write-Log "Skipped VC++ Redistributables installation by user choice." -Level "INFO"
    }

    $installWsl = Read-YesNoChoice -Prompt "Install WSL from Winget?" -DefaultYes $true
    if ($installWsl) {
        Install-WSLFromWinget | Out-Null
    }
    else {
        Write-Log "Skipped WSL installation by user choice." -Level "INFO"
    }

    $enableHyperV = Read-YesNoChoice -Prompt "Enable Hyper-V?" -DefaultYes $false
    if ($enableHyperV) {
        Enable-HyperV | Out-Null
    }
    else {
        Write-Log "Skipped Hyper-V enablement by user choice." -Level "INFO"
    }

    Write-Log "" -Level "INFO" -NoConsole
    Write-Log "========================================" -Level "INFO"
    Write-Log "Setup Complete" -Level "SUCCESS"
    Write-Log "Total Applications Installed: $($appResults.Installed)" -Level "INFO"
    Write-Log "Total Applications Skipped (already installed): $($appResults.Skipped)" -Level "INFO"
    Write-Log "Total Applications Failed: $($appResults.Failed)" -Level "INFO"
    Write-Log "Log file: $script:logFile" -Level "INFO"
    Write-Log "Elapsed time: $((Get-Date) - $script:logStartTime)" -Level "INFO"
    Write-Log "========================================" -Level "INFO"

    Write-Host "`nLog file saved to: $script:logFile" -ForegroundColor Green
}

Invoke-PCSetup
