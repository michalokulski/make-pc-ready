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
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "General"; Id = "7zip.7zip"; Name = "7-Zip"; DefaultSelected = $true }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "General"; Id = "Git.Git"; Name = "Git"; DefaultSelected = $true }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "General"; Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code"; DefaultSelected = $true }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "General"; Id = "Microsoft.PowerShell"; Name = "PowerShell 7"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "General"; Id = "Microsoft.Sysinternals.Suite"; Name = "Sysinternals Suite"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "General"; Id = "Notepad++.Notepad++"; Name = "Notepad++"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "General"; Id = "WinDirStat.WinDirStat"; Name = "WinDirStat"; DefaultSelected = $false }

    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Browsers and Essentials"; Id = "Google.Chrome"; Name = "Google Chrome"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Browsers and Essentials"; Id = "Mozilla.Firefox"; Name = "Mozilla Firefox"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Browsers and Essentials"; Id = "VideoLAN.VLC"; Name = "VLC Media Player"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Browsers and Essentials"; Id = "Gyan.FFmpeg"; Name = "FFmpeg"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Browsers and Essentials"; Id = "Microsoft.PowerToys"; Name = "Microsoft PowerToys"; DefaultSelected = $false }

    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Hardware Tools"; Id = "REALiX.HWiNFO"; Name = "HWiNFO"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Hardware Tools"; Id = "CPUID.CPU-Z"; Name = "CPU-Z"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Hardware Tools"; Id = "TechPowerUp.GPU-Z"; Name = "GPU-Z"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Hardware Tools"; Id = "TechPowerUp.NVCleanstall"; Name = "NVCleanstall (NVIDIA Driver Cleaner/Installer)"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Hardware Tools"; Id = "AMD.AMDSoftwareCloudEdition"; Name = "AMD Software: Cloud Edition"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Hardware Tools"; Id = "Wagnardsoft.DisplayDriverUninstaller"; Name = "Display Driver Uninstaller (DDU)"; DefaultSelected = $false }

    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Containers"; Id = "RedHat.Podman"; Name = "Podman CLI"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Containers"; Id = "RedHat.Podman-Desktop"; Name = "Podman Desktop"; DefaultSelected = $false }

    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "Python.Python.3.13"; Name = "Python 3.13"; DefaultSelected = $false}
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "Python.Python.3.12"; Name = "Python 3.12 (Compatibility)"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "astral-sh.uv"; Name = "uv (Python package/env manager)"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "Anaconda.Miniconda3"; Name = "Miniconda3"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "Anaconda.Anaconda3"; Name = "Anaconda3"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "ProjectJupyter.JupyterLab"; Name = "JupyterLab"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "JetBrains.PyCharm.Community"; Name = "PyCharm Community"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "DBeaver.DBeaver.Community"; Name = "DBeaver Community"; DefaultSelected = $false }

    [PSCustomObject]@{ Group = "Gaming"; SubGroup = "Launchers"; Id = "Valve.Steam"; Name = "Steam"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Gaming"; SubGroup = "Launchers"; Id = "Ubisoft.Connect"; Name = "Ubisoft Connect"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Gaming"; SubGroup = "Launchers"; Id = "GOG.Galaxy"; Name = "GOG Galaxy"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Gaming"; SubGroup = "Launchers"; Id = "EpicGames.EpicGamesLauncher"; Name = "Epic Games Launcher"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Gaming"; SubGroup = "Launchers"; Id = "ElectronicArts.EADesktop"; Name = "EA App"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Gaming"; SubGroup = "Launchers"; Id = "Blizzard.BattleNet"; Name = "Battle.net"; DefaultSelected = $false }

    [PSCustomObject]@{ Group = "AI/LLM"; SubGroup = "Clients"; Id = "Anthropic.Claude"; Name = "Claude Desktop"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "AI/LLM"; SubGroup = "Clients"; Id = "Bin-Huang.Chatbox"; Name = "Chatbox"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "AI/LLM"; SubGroup = "Local Inference"; Id = "Ollama.Ollama"; Name = "Ollama"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "AI/LLM"; SubGroup = "Local Inference"; Id = "ElementLabs.LMStudio"; Name = "LM Studio"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "AI/LLM"; SubGroup = "Local Inference"; Id = "AhoyLabs.BackyardAI"; Name = "Backyard AI"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "AI/LLM"; SubGroup = "Local Inference"; Id = "CloudStack.Msty"; Name = "Msty"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "AI/LLM"; SubGroup = "Local Inference"; Id = "CloudStack.Msty.CPU"; Name = "Msty (CPU)"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "AI/LLM"; SubGroup = "Local Inference"; Id = "Jan.Jan"; Name = "Jan"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "AI/LLM"; SubGroup = "Local Inference"; Id = "QXYZLabs.Sanctum"; Name = "Sanctum"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "AI/LLM"; SubGroup = "Coding Assistants"; Id = "OpenAgentPlatform.Dive"; Name = "Dive"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "AI/LLM"; SubGroup = "Coding Assistants"; Id = "SST.opencode"; Name = "opencode"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "AI/LLM"; SubGroup = "Coding Assistants"; Id = "Anysphere.Cursor"; Name = "Cursor"; DefaultSelected = $false }

    [PSCustomObject]@{ Group = "Runtime Bundles"; SubGroup = "VC++"; Action = "InstallVCRedist"; Name = "Visual C++ Redistributables (Bundle)"; DefaultSelected = $false }

    [PSCustomObject]@{ Group = "Platform Features"; SubGroup = "Windows"; Action = "InstallWSL"; Name = "Windows Subsystem for Linux (WSL)"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Platform Features"; SubGroup = "Windows"; Action = "EnableHyperV"; Name = "Hyper-V"; DefaultSelected = $false }

    [PSCustomObject]@{ Group = "Maintenance"; SubGroup = "Updates"; Action = "UpgradeAllWingetPackages"; Name = "Upgrade all installed applications via Winget"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Maintenance"; SubGroup = "Updates"; Action = "TriggerWindowsUpdate"; Name = "Trigger Windows Update (scan/download/install)"; DefaultSelected = $false }

    [PSCustomObject]@{ Group = ".NET"; SubGroup = ".NET Framework"; Action = "EnableDotNetFx35"; Name = ".NET Framework 3.5 (Windows Feature: NetFx3)"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = ".NET"; SubGroup = ".NET Framework"; Action = "EnsureDotNetFx4x"; Name = ".NET Framework 4.x (Windows Feature/Presence Check)"; DefaultSelected = $false }

    [PSCustomObject]@{ Group = ".NET"; SubGroup = ".NET Runtime (Core)"; Id = "Microsoft.DotNet.Runtime.6"; Name = ".NET Runtime 6"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = ".NET"; SubGroup = ".NET Runtime (Core)"; Id = "Microsoft.DotNet.Runtime.8"; Name = ".NET Runtime 8"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = ".NET"; SubGroup = ".NET Runtime (Core)"; Id = "Microsoft.DotNet.Runtime.9"; Name = ".NET Runtime 9"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = ".NET"; SubGroup = ".NET Runtime (Core)"; Id = "Microsoft.DotNet.Runtime.10"; Name = ".NET Runtime 10"; DefaultSelected = $false }

    [PSCustomObject]@{ Group = ".NET"; SubGroup = ".NET Desktop Runtime"; Id = "Microsoft.DotNet.DesktopRuntime.6"; Name = ".NET Desktop Runtime 6 (WPF/WinForms)"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = ".NET"; SubGroup = ".NET Desktop Runtime"; Id = "Microsoft.DotNet.DesktopRuntime.8"; Name = ".NET Desktop Runtime 8 (WPF/WinForms)"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = ".NET"; SubGroup = ".NET Desktop Runtime"; Id = "Microsoft.DotNet.DesktopRuntime.9"; Name = ".NET Desktop Runtime 9 (WPF/WinForms)"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = ".NET"; SubGroup = ".NET Desktop Runtime"; Id = "Microsoft.DotNet.DesktopRuntime.10"; Name = ".NET Desktop Runtime 10 (WPF/WinForms)"; DefaultSelected = $false }

    [PSCustomObject]@{ Group = ".NET"; SubGroup = "ASP.NET Core Runtime"; Id = "Microsoft.DotNet.AspNetCore.6"; Name = "ASP.NET Core Runtime 6"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = ".NET"; SubGroup = "ASP.NET Core Runtime"; Id = "Microsoft.DotNet.AspNetCore.8"; Name = "ASP.NET Core Runtime 8"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = ".NET"; SubGroup = "ASP.NET Core Runtime"; Id = "Microsoft.DotNet.AspNetCore.9"; Name = "ASP.NET Core Runtime 9"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = ".NET"; SubGroup = "ASP.NET Core Runtime"; Id = "Microsoft.DotNet.AspNetCore.10"; Name = "ASP.NET Core Runtime 10"; DefaultSelected = $false }

    [PSCustomObject]@{ Group = "Java"; SubGroup = "IBM Semeru JDK (LTS)"; Id = "IBM.Semeru.8.JDK"; Name = "IBM Semeru JDK 8"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "IBM Semeru JDK (LTS)"; Id = "IBM.Semeru.11.JDK"; Name = "IBM Semeru JDK 11"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "IBM Semeru JDK (LTS)"; Id = "IBM.Semeru.17.JDK"; Name = "IBM Semeru JDK 17"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "IBM Semeru JDK (LTS)"; Id = "IBM.Semeru.21.JDK"; Name = "IBM Semeru JDK 21"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "IBM Semeru JDK (LTS)"; Id = "IBM.Semeru.25.JDK"; Name = "IBM Semeru JDK 25"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "IBM Semeru JRE (LTS)"; Id = "IBM.Semeru.8.JRE"; Name = "IBM Semeru JRE 8"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "IBM Semeru JRE (LTS)"; Id = "IBM.Semeru.11.JRE"; Name = "IBM Semeru JRE 11"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "IBM Semeru JRE (LTS)"; Id = "IBM.Semeru.17.JRE"; Name = "IBM Semeru JRE 17"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "IBM Semeru JRE (LTS)"; Id = "IBM.Semeru.21.JRE"; Name = "IBM Semeru JRE 21"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "IBM Semeru JRE (LTS)"; Id = "IBM.Semeru.25.JRE"; Name = "IBM Semeru JRE 25"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "Amazon Corretto JDK (LTS)"; Id = "Amazon.Corretto.8.JDK"; Name = "Amazon Corretto JDK 8"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "Amazon Corretto JDK (LTS)"; Id = "Amazon.Corretto.11.JDK"; Name = "Amazon Corretto JDK 11"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "Amazon Corretto JDK (LTS)"; Id = "Amazon.Corretto.17.JDK"; Name = "Amazon Corretto JDK 17"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "Amazon Corretto JDK (LTS)"; Id = "Amazon.Corretto.21.JDK"; Name = "Amazon Corretto JDK 21"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "Amazon Corretto JDK (LTS)"; Id = "Amazon.Corretto.25.JDK"; Name = "Amazon Corretto JDK 25"; DefaultSelected = $false }
    # Corretto JRE: only version 8 is currently published in Winget.
    [PSCustomObject]@{ Group = "Java"; SubGroup = "Amazon Corretto JRE (LTS)"; Id = "Amazon.Corretto.8.JRE"; Name = "Amazon Corretto JRE 8"; DefaultSelected = $false }

    [PSCustomObject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JDK (LTS)"; Id = "EclipseAdoptium.Temurin.8.JDK"; Name = "Eclipse Temurin JDK 8"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JDK (LTS)"; Id = "EclipseAdoptium.Temurin.11.JDK"; Name = "Eclipse Temurin JDK 11"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JDK (LTS)"; Id = "EclipseAdoptium.Temurin.17.JDK"; Name = "Eclipse Temurin JDK 17"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JDK (LTS)"; Id = "EclipseAdoptium.Temurin.21.JDK"; Name = "Eclipse Temurin JDK 21"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JDK (LTS)"; Id = "EclipseAdoptium.Temurin.25.JDK"; Name = "Eclipse Temurin JDK 25"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JRE (LTS)"; Id = "EclipseAdoptium.Temurin.8.JRE"; Name = "Eclipse Temurin JRE 8"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JRE (LTS)"; Id = "EclipseAdoptium.Temurin.11.JRE"; Name = "Eclipse Temurin JRE 11"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JRE (LTS)"; Id = "EclipseAdoptium.Temurin.17.JRE"; Name = "Eclipse Temurin JRE 17"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JRE (LTS)"; Id = "EclipseAdoptium.Temurin.21.JRE"; Name = "Eclipse Temurin JRE 21"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JRE (LTS)"; Id = "EclipseAdoptium.Temurin.25.JRE"; Name = "Eclipse Temurin JRE 25"; DefaultSelected = $false }
)

$script:installedCache = @{}

$script:logColors = @{
    "SUCCESS" = "Green"
    "INFO"    = "White"
    "WARNING" = "Yellow"
    "ERROR"   = "Red"
}

$script:vcRedistPackages = @(
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
        $color = if ($script:logColors.ContainsKey($Level)) { $script:logColors[$Level] } else { "White" }
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
        [string]$PackageId,
        [switch]$Refresh
    )

    if (-not $Refresh -and $script:installedCache.ContainsKey($PackageId)) {
        return [bool]$script:installedCache[$PackageId]
    }

    $result = Invoke-WingetCommand -Arguments @("list", "--id", $PackageId, "--exact")
    if ($result.ExitCode -ne 0) {
        $script:installedCache[$PackageId] = $false
        return $false
    }

    $allText = ($result.StdOut | Out-String)
    if ($allText -match "No installed package found matching input criteria") {
        $script:installedCache[$PackageId] = $false
        return $false
    }

    $installed = ($allText -match [Regex]::Escape($PackageId))
    $script:installedCache[$PackageId] = $installed
    return $installed
}

function Test-BundleInstalled {
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Packages
    )

    foreach ($pkg in $Packages) {
        if (-not (Test-PackageInstalled -PackageId $pkg.Id)) {
            return $false
        }
    }

    return $true
}

function Test-WindowsFeatureEnabled {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FeatureName
    )

    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue
    return ($feature -and $feature.State -eq "Enabled")
}

function Enable-WindowsFeatureIfNeeded {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FeatureName,
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        [string]$EnableFeatureName
    )

    if (-not $EnableFeatureName) { $EnableFeatureName = $FeatureName }

    if (Test-WindowsFeatureEnabled -FeatureName $FeatureName) {
        Write-Log "$DisplayName is already enabled." -Level "INFO"
        return $true
    }

    Write-Log "Enabling $DisplayName ($EnableFeatureName)..." -Level "INFO"
    try {
        $result = Enable-WindowsOptionalFeature -Online -FeatureName $EnableFeatureName -All -NoRestart -ErrorAction Stop
    }
    catch {
        Write-Log "Failed to enable ${DisplayName}: $_" -Level "ERROR"
        return $false
    }

    if (Test-WindowsFeatureEnabled -FeatureName $FeatureName) {
        Write-Log "$DisplayName enabled successfully." -Level "SUCCESS"
        if ($result.RestartNeeded) {
            Write-Log "System restart is required to finalize $DisplayName." -Level "WARNING"
        }
        return $true
    }

    Write-Log "$DisplayName enable command ran, but feature is not Enabled." -Level "ERROR"
    return $false
}

function Test-DotNetFx4xInstalled {
    $release = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -Name "Release" -ErrorAction SilentlyContinue
    return ($release -ge 378389)
}

function Ensure-DotNetFramework4x {
    Write-Log "Ensuring .NET Framework 4.x availability..." -Level "INFO"

    if (Test-DotNetFx4xInstalled) {
        Write-Log ".NET Framework 4.x detected in registry." -Level "SUCCESS"
        return $true
    }

    if (Enable-WindowsFeatureIfNeeded -FeatureName "NetFx4-AdvSrvs" -DisplayName ".NET Framework 4.x Advanced Services") {
        if (Test-DotNetFx4xInstalled) {
            Write-Log ".NET Framework 4.x is now available." -Level "SUCCESS"
            return $true
        }
    }

    Write-Log ".NET Framework 4.x could not be verified as installed." -Level "WARNING"
    return $false
}

function Get-CatalogItemInstalledState {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Item
    )

    switch ($Item.Action) {
        "InstallVCRedist" { return (Test-BundleInstalled -Packages $script:vcRedistPackages) }
        "InstallWSL" { return ((Test-PackageInstalled -PackageId "Microsoft.WSL") -or [bool](Get-Command wsl.exe -ErrorAction SilentlyContinue)) }
        "EnableHyperV" { return (Test-WindowsFeatureEnabled -FeatureName "Microsoft-Hyper-V-All") }
        "EnableDotNetFx35" { return (Test-WindowsFeatureEnabled -FeatureName "NetFx3") }
        "EnsureDotNetFx4x" { return (Test-DotNetFx4xInstalled) }
        "UpgradeAllWingetPackages" { return $false }
        "TriggerWindowsUpdate" { return $false }
    }

    if (-not [string]::IsNullOrWhiteSpace($Item.Id)) {
        return (Test-PackageInstalled -PackageId $Item.Id)
    }

    return $false
}

function Invoke-SelectedAction {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Action
    )

    switch ($Action) {
        "InstallVCRedist" {
            Install-VCRedist | Out-Null
            return
        }
        "InstallWSL" {
            Install-WSLFromWinget | Out-Null
            return
        }
        "EnableHyperV" {
            Enable-HyperV | Out-Null
            return
        }
        "UpgradeAllWingetPackages" {
            Upgrade-AllWingetPackages | Out-Null
            return
        }
        "TriggerWindowsUpdate" {
            Trigger-WindowsUpdate | Out-Null
            return
        }
        "EnableDotNetFx35" {
            Enable-WindowsFeatureIfNeeded -FeatureName "NetFx3" -DisplayName ".NET Framework 3.5" | Out-Null
            return
        }
        "EnsureDotNetFx4x" {
            Ensure-DotNetFramework4x | Out-Null
            return
        }
        default {
            Write-Log "Unknown action '$Action' was selected and skipped." -Level "WARNING"
            return
        }
    }
}

function Install-Package {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageId,
        [string]$PackageName = $PackageId,
        [switch]$SkipInstalledCheck
    )

    if (-not $SkipInstalledCheck -and (Test-PackageInstalled -PackageId $PackageId)) {
        Write-Log "Already installed: $PackageName ($PackageId). Skipping." -Level "INFO"
        return $true
    }

    Write-Log "Installing: $PackageName ($PackageId)" -Level "INFO"

    $wingetArgs = @(
        "install"
        "--id", $PackageId
        "--exact"
        "--silent"
        "--accept-package-agreements"
        "--accept-source-agreements"
    )

    $result = Invoke-WingetCommand -Arguments $wingetArgs
    if ($result.ExitCode -eq 0) {
        $script:installedCache[$PackageId] = $true
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
            $script:installedCache[$pkg.Id] = $alreadyInstalled
        }
        else {
            $alreadyInstalled = Test-PackageInstalled -PackageId $pkg.Id
        }

        if ($alreadyInstalled) {
            Write-Log "Already installed: $($pkg.Name) ($($pkg.Id)). Skipping." -Level "INFO"
            $skipped++
            continue
        }

        if (Install-Package -PackageId $pkg.Id -PackageName $pkg.Name -SkipInstalledCheck) {
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

    $selection = @($Catalog | ForEach-Object {
        [PSCustomObject]@{
            Group       = $_.Group
            SubGroup    = $_.SubGroup
            Action      = $_.Action
            Id          = $_.Id
            Name        = $_.Name
            Selected    = [bool]$_.DefaultSelected
            IsInstalled = [bool]$_.IsInstalled
        }
    })

    if (-not $Host.UI.RawUI) {
        Write-Log "Interactive console features are unavailable. Falling back to defaults." -Level "WARNING"
        return $selection | Where-Object { $_.Selected }
    }

    $cursor = 0
    $statusMessage = ""

    while ($true) {
        [Console]::CursorVisible = $false
        try { [Console]::SetCursorPosition(0, 0) } catch { }
        $bufferLines = @()

        $windowHeight = [Math]::Max(20, $Host.UI.RawUI.WindowSize.Height)
        $visibleRows = [Math]::Max(8, $windowHeight - 10)
        $maxTop = [Math]::Max(0, $selection.Count - $visibleRows)
        $topIndex = [Math]::Min($maxTop, [Math]::Max(0, $cursor - [int]($visibleRows / 2)))
        $bottomExclusive = [Math]::Min($selection.Count, $topIndex + $visibleRows)

        $selectedCount = @($selection | Where-Object { $_.Selected }).Count

        # Build display using Write-Host for color, but use SetCursorPosition for flicker-free refresh
        [Console]::Clear()
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host " MakePCReady - Alternative TUI Selector" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  Up/Down  move   Space  toggle   A  select all   N  select none" -ForegroundColor DarkGray
        Write-Host "  PgUp/PgDn/Home/End  scroll      Enter  start    Esc  quit" -ForegroundColor DarkGray
        Write-Host ("  Selected: {0} of {1}" -f $selectedCount, $selection.Count) -ForegroundColor Gray
        Write-Host ""

        $currentGroup = ""
        $currentSubGroup = ""
        for ($i = $topIndex; $i -lt $bottomExclusive; $i++) {
            if ($selection[$i].Group -ne $currentGroup) {
                $currentGroup = $selection[$i].Group
                $currentSubGroup = ""
                Write-Host ""
                Write-Host ("---- {0} ----" -f $currentGroup) -ForegroundColor Cyan
            }

            if ($selection[$i].SubGroup -ne $currentSubGroup) {
                $currentSubGroup = $selection[$i].SubGroup
                if (-not [string]::IsNullOrWhiteSpace($currentSubGroup)) {
                    Write-Host ("  [{0}]" -f $currentSubGroup) -ForegroundColor DarkCyan
                }
            }

            $mark = if ($selection[$i].Selected) { "[x]" } else { "[ ]" }
            $pointer = if ($i -eq $cursor) { ">" } else { " " }

            # Build info tag: show install state + action type for non-package items
            $infoTag = ""
            if ($selection[$i].IsInstalled) {
                $infoTag = "(Installed)"
            }
            elseif (-not [string]::IsNullOrWhiteSpace($selection[$i].Action)) {
                $infoTag = "(Action: $($selection[$i].Action))"
            }
            else {
                $infoTag = "(Not installed)"
            }

            $line = ("{0} {1,2}. {2} {3} {4}" -f $pointer, ($i + 1), $mark, $selection[$i].Name, $infoTag)

            if ($i -eq $cursor) {
                Write-Host $line -ForegroundColor Yellow
            }
            else {
                Write-Host $line
            }
        }

        Write-Host ""
        if ($selection.Count -gt $visibleRows) {
            Write-Host ("  Showing {0}-{1} of {2}" -f ($topIndex + 1), $bottomExclusive, $selection.Count) -ForegroundColor DarkGray
        }
        if (-not [string]::IsNullOrWhiteSpace($statusMessage)) {
            Write-Host "  $statusMessage" -ForegroundColor DarkYellow
        }

        [Console]::CursorVisible = $false
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $statusMessage = ""

        switch ($key.VirtualKeyCode) {
            38 { # Up
                $cursor--
                if ($cursor -lt 0) { $cursor = $selection.Count - 1 }
                continue
            }
            40 { # Down
                $cursor++
                if ($cursor -ge $selection.Count) { $cursor = 0 }
                continue
            }
            36 { # Home
                $cursor = 0
                continue
            }
            35 { # End
                $cursor = $selection.Count - 1
                continue
            }
            33 { # PageUp
                $cursor = [Math]::Max(0, $cursor - $visibleRows)
                continue
            }
            34 { # PageDown
                $cursor = [Math]::Min($selection.Count - 1, $cursor + $visibleRows)
                continue
            }
            32 { # Space
                $selection[$cursor].Selected = -not $selection[$cursor].Selected
                continue
            }
            13 { # Enter
                [Console]::CursorVisible = $true
                return $selection | Where-Object { $_.Selected }
            }
            27 { # Escape
                [Console]::CursorVisible = $true
                Write-Log "User canceled application selection. Exiting..." -Level "WARNING"
                exit 0
            }
        }

        switch ($key.Character.ToString().ToUpperInvariant()) {
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
            default { $statusMessage = "Unsupported key. Use Space, arrows, Enter, A, N, Esc." }
        }
    }
}

function Install-VCRedist {
    Write-Log "========================================" -Level "INFO"
    Write-Log "Installing Visual C++ Redistributables..." -Level "INFO"
    Write-Log "========================================" -Level "INFO"

    $result = Install-Packages -Packages $script:vcRedistPackages
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

function Upgrade-AllWingetPackages {
    Write-Log "========================================" -Level "INFO"
    Write-Log "Upgrading installed applications via Winget..." -Level "INFO"
    Write-Log "========================================" -Level "INFO"

    $wingetArgs = @(
        "upgrade"
        "--all"
        "-r"
        "-h"
        "--include-unknown"
        "--accept-package-agreements"
        "--accept-source-agreements"
    )

    $result = Invoke-WingetCommand -Arguments $wingetArgs
    if ($result.ExitCode -eq 0) {
        Write-Log "Winget upgrade completed." -Level "SUCCESS"
        return $true
    }

    Write-Log "Winget upgrade completed with exit code $($result.ExitCode)." -Level "WARNING"
    foreach ($line in $result.StdOut) {
        Write-Log "winget: $line" -Level "WARNING" -NoConsole
    }
    return $false
}

function Trigger-WindowsUpdate {
    Write-Log "========================================" -Level "INFO"
    Write-Log "Triggering Windows Update scan/download/install..." -Level "INFO"
    Write-Log "========================================" -Level "INFO"

    $usoClient = Get-Command UsoClient.exe -ErrorAction SilentlyContinue
    if ($usoClient) {
        foreach ($step in @("StartScan", "StartDownload", "StartInstall")) {
            try {
                Start-Process -FilePath $usoClient.Source -ArgumentList $step -WindowStyle Hidden | Out-Null
                Write-Log "USOClient step triggered: $step" -Level "INFO"
            }
            catch {
                Write-Log "Failed to trigger USOClient step $step : $_" -Level "WARNING"
            }
        }

        Write-Log "Windows Update trigger commands were sent via USOClient." -Level "SUCCESS"
        return $true
    }

    $wuaucltPath = Join-Path -Path $env:SystemRoot -ChildPath "System32\wuauclt.exe"
    if (Test-Path -Path $wuaucltPath) {
        try {
            Start-Process -FilePath $wuaucltPath -ArgumentList "/detectnow" -WindowStyle Hidden | Out-Null
            Start-Process -FilePath $wuaucltPath -ArgumentList "/updatenow" -WindowStyle Hidden | Out-Null
            Write-Log "Windows Update trigger commands were sent via wuauclt." -Level "SUCCESS"
            return $true
        }
        catch {
            Write-Log "Failed to trigger Windows Update via wuauclt: $_" -Level "ERROR"
            return $false
        }
    }

    Write-Log "No supported Windows Update trigger tool was found (UsoClient/wuauclt)." -Level "ERROR"
    return $false
}

function Enable-HyperV {
    Write-Log "========================================" -Level "INFO"
    Write-Log "Checking/Enabling Hyper-V..." -Level "INFO"
    Write-Log "========================================" -Level "INFO"

    $ok = Enable-WindowsFeatureIfNeeded -FeatureName "Microsoft-Hyper-V-All" -DisplayName "Hyper-V" -EnableFeatureName "Microsoft-Hyper-V"

    $vmmsService = Get-Service -Name vmms -ErrorAction SilentlyContinue
    if ($vmmsService) {
        Write-Log "Hyper-V management service found: vmms ($($vmmsService.Status))" -Level "INFO"
    }
    elseif ($ok) {
        Write-Log "vmms service not found yet (often appears after reboot)." -Level "WARNING"
    }

    return $ok
}

function Invoke-PCSetup {
    Initialize-Log
    Test-AdminPrivileges

    if (-not (Ensure-Winget)) {
        Write-Log "Cannot continue without Winget. Exiting..." -Level "ERROR"
        exit 1
    }

    Update-WingetSources

    $appCatalog = @($script:appCatalog | ForEach-Object { $_.PSObject.Copy() })

    Write-Log "Detecting already installed applications in catalog..." -Level "INFO"
    foreach ($app in $appCatalog) {
        $isInstalled = Get-CatalogItemInstalledState -Item $app

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

    $selectedPackageApps = @($selectedApps | Where-Object { [string]::IsNullOrWhiteSpace($_.Action) })
    $selectedActions = @($selectedApps | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Action) } | ForEach-Object { $_.Action } | Select-Object -Unique)

    $appResults = Install-Packages -Packages $selectedPackageApps

    foreach ($action in $selectedActions) {
        Invoke-SelectedAction -Action $action
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
