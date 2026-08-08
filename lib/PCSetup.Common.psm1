# ============================================================================
# PCSetup.Common.psm1 — Shared module for MakePCReady scripts
# ============================================================================
# Dot-sourced by MakePCReady.ps1 and MakePCReadyAlternativeGUI.ps1.
# Contains: catalog, winget helpers, install functions, action handlers, Invoke-PCSetup.
# ============================================================================

# --- Module-scoped state ---
$script:logFile = $null
$script:logStartTime = $null
$script:wingetPath = $null
$script:installedCache = @{}
$script:installedCachePrimed = $false

$script:logColors = @{
  "SUCCESS" = "Green"
  "INFO" = "White"
  "WARNING" = "Yellow"
  "ERROR" = "Red"
}

# --- Application catalog ---
$script:appCatalog = @(
  [pscustomobject]@{ Group = "Applications"; SubGroup = "General"; Id = "7zip.7zip"; Name = "7-Zip"; DefaultSelected = $true }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "General"; Id = "Git.Git"; Name = "Git"; DefaultSelected = $true }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "General"; Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code"; DefaultSelected = $true }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "General"; Id = "Microsoft.PowerShell"; Name = "PowerShell 7"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "General"; Id = "Microsoft.Sysinternals.Suite"; Name = "Sysinternals Suite"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "General"; Id = "Notepad++.Notepad++"; Name = "Notepad++"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "General"; Id = "WinDirStat.WinDirStat"; Name = "WinDirStat"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "General"; Id = "Microsoft.WindowsTerminal"; Name = "Windows Terminal"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "General"; Id = "voidtools.Everything"; Name = "Everything (File Search)"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "General"; Id = "DevToys-app.DevToys"; Name = "DevToys"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Applications"; SubGroup = "Browsers and Essentials"; Id = "Google.Chrome"; Name = "Google Chrome"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Browsers and Essentials"; Id = "Mozilla.Firefox"; Name = "Mozilla Firefox"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Browsers and Essentials"; Id = "VideoLAN.VLC"; Name = "VLC Media Player"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Browsers and Essentials"; Id = "Gyan.FFmpeg"; Name = "FFmpeg"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Browsers and Essentials"; Id = "Microsoft.PowerToys"; Name = "Microsoft PowerToys"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Browsers and Essentials"; Id = "Brave.Brave"; Name = "Brave Browser"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Applications"; SubGroup = "Hardware Tools"; Id = "REALiX.HWiNFO"; Name = "HWiNFO"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Hardware Tools"; Id = "CPUID.CPU-Z"; Name = "CPU-Z"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Hardware Tools"; Id = "TechPowerUp.GPU-Z"; Name = "GPU-Z"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Hardware Tools"; Id = "TechPowerUp.NVCleanstall"; Name = "NVCleanstall (NVIDIA Driver Cleaner/Installer)"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Hardware Tools"; Id = "AMD.AMDSoftwareCloudEdition"; Name = "AMD Software: Cloud Edition"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Hardware Tools"; Id = "Wagnardsoft.DisplayDriverUninstaller"; Name = "Display Driver Uninstaller (DDU)"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Hardware Tools"; Id = "CrystalDewWorld.CrystalDiskInfo"; Name = "CrystalDiskInfo"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Hardware Tools"; Id = "CrystalDewWorld.CrystalDiskMark"; Name = "CrystalDiskMark"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Hardware Tools"; Id = "CPUID.HWMonitor"; Name = "HWMonitor"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Applications"; SubGroup = "Containers"; Id = "RedHat.Podman"; Name = "Podman CLI"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Containers"; Id = "RedHat.Podman-Desktop"; Name = "Podman Desktop"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Applications"; SubGroup = "Developer Tools"; Id = "OpenJS.NodeJS.LTS"; Name = "Node.js LTS"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Developer Tools"; Id = "GitHub.cli"; Name = "GitHub CLI"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Developer Tools"; Id = "GitHub.GitHubDesktop"; Name = "GitHub Desktop"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Developer Tools"; Id = "JanDeDobbeleer.OhMyPosh"; Name = "Oh My Posh"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "Python.Python.3.13"; Name = "Python 3.13"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "Python.Python.3.12"; Name = "Python 3.12 (Compatibility)"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "astral-sh.uv"; Name = "uv (Python package/env manager)"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "Anaconda.Miniconda3"; Name = "Miniconda3"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "Anaconda.Anaconda3"; Name = "Anaconda3"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "ProjectJupyter.JupyterLab"; Name = "JupyterLab"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "JetBrains.PyCharm.Community"; Name = "PyCharm Community"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Python and Data Tools"; Id = "DBeaver.DBeaver.Community"; Name = "DBeaver Community"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Applications"; SubGroup = "Media"; Id = "OBSProject.OBSStudio"; Name = "OBS Studio"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Media"; Id = "Spotify.Spotify"; Name = "Spotify"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Applications"; SubGroup = "Communication"; Id = "Discord.Discord"; Name = "Discord"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Applications"; SubGroup = "Networking"; Id = "PuTTY.PuTTY"; Name = "PuTTY"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "Networking"; Id = "WinSCP.WinSCP"; Name = "WinSCP"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Applications"; SubGroup = "System Utilities"; Id = "Rufus.Rufus"; Name = "Rufus"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Applications"; SubGroup = "System Utilities"; Id = "Ventoy.Ventoy"; Name = "Ventoy"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Applications"; SubGroup = "Productivity"; Id = "TheDocumentFoundation.LibreOffice"; Name = "LibreOffice"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Gaming"; SubGroup = "Launchers"; Id = "Valve.Steam"; Name = "Steam"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Gaming"; SubGroup = "Launchers"; Id = "Ubisoft.Connect"; Name = "Ubisoft Connect"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Gaming"; SubGroup = "Launchers"; Id = "GOG.Galaxy"; Name = "GOG Galaxy"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Gaming"; SubGroup = "Launchers"; Id = "EpicGames.EpicGamesLauncher"; Name = "Epic Games Launcher"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Gaming"; SubGroup = "Launchers"; Id = "ElectronicArts.EADesktop"; Name = "EA App"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Gaming"; SubGroup = "Launchers"; Id = "Blizzard.BattleNet"; Name = "Battle.net"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "AI/LLM"; SubGroup = "Clients"; Id = "Anthropic.Claude"; Name = "Claude Desktop"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "AI/LLM"; SubGroup = "Clients"; Id = "Bin-Huang.Chatbox"; Name = "Chatbox"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "AI/LLM"; SubGroup = "Local Inference"; Id = "Ollama.Ollama"; Name = "Ollama"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "AI/LLM"; SubGroup = "Local Inference"; Id = "ElementLabs.LMStudio"; Name = "LM Studio"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "AI/LLM"; SubGroup = "Local Inference"; Id = "AhoyLabs.BackyardAI"; Name = "Backyard AI"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "AI/LLM"; SubGroup = "Local Inference"; Id = "CloudStack.Msty"; Name = "Msty"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "AI/LLM"; SubGroup = "Local Inference"; Id = "CloudStack.Msty.CPU"; Name = "Msty (CPU)"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "AI/LLM"; SubGroup = "Local Inference"; Id = "Jan.Jan"; Name = "Jan"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "AI/LLM"; SubGroup = "Local Inference"; Id = "QXYZLabs.Sanctum"; Name = "Sanctum"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "AI/LLM"; SubGroup = "Coding Assistants"; Id = "OpenAgentPlatform.Dive"; Name = "Dive"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "AI/LLM"; SubGroup = "Coding Assistants"; Id = "SST.opencode"; Name = "opencode"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "AI/LLM"; SubGroup = "Coding Assistants"; Id = "Anysphere.Cursor"; Name = "Cursor"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Runtime Bundles"; SubGroup = "VC++"; Action = "InstallVCRedist"; Name = "Visual C++ Redistributables (Install package-by-package)"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Runtime Bundles"; SubGroup = "VC++"; Action = "InstallVCRedistAIO"; Name = "VC Redist AIO (abbodi1406 bundle)"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Platform Features"; SubGroup = "Windows"; Action = "InstallWSL"; Name = "Windows Subsystem for Linux (WSL)"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Platform Features"; SubGroup = "Windows"; Action = "EnableHyperV"; Name = "Hyper-V"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Platform Features"; SubGroup = "Virtualization"; Id = "Oracle.VirtualBox"; Name = "VirtualBox"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Maintenance"; SubGroup = "Updates"; Action = "UpgradeAllWingetPackages"; Name = "Upgrade all installed applications via Winget"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Maintenance"; SubGroup = "Updates"; Action = "TriggerWindowsUpdate"; Name = "Trigger Windows Update (scan/download/install)"; DefaultSelected = $false }

  [pscustomobject]@{ Group = ".NET"; SubGroup = ".NET Framework"; Action = "EnableDotNetFx35"; Name = ".NET Framework 3.5 (Windows Feature: NetFx3)"; DefaultSelected = $false }
  [pscustomobject]@{ Group = ".NET"; SubGroup = ".NET Framework"; Action = "EnsureDotNetFx4x"; Name = ".NET Framework 4.x (Windows Feature/Presence Check)"; DefaultSelected = $false }

  [pscustomobject]@{ Group = ".NET"; SubGroup = ".NET Runtime (Core)"; Id = "Microsoft.DotNet.Runtime.6"; Name = ".NET Runtime 6"; DefaultSelected = $false }
  [pscustomobject]@{ Group = ".NET"; SubGroup = ".NET Runtime (Core)"; Id = "Microsoft.DotNet.Runtime.8"; Name = ".NET Runtime 8"; DefaultSelected = $false }
  [pscustomobject]@{ Group = ".NET"; SubGroup = ".NET Runtime (Core)"; Id = "Microsoft.DotNet.Runtime.9"; Name = ".NET Runtime 9"; DefaultSelected = $false }
  [pscustomobject]@{ Group = ".NET"; SubGroup = ".NET Runtime (Core)"; Id = "Microsoft.DotNet.Runtime.10"; Name = ".NET Runtime 10"; DefaultSelected = $false }

  [pscustomobject]@{ Group = ".NET"; SubGroup = ".NET Desktop Runtime"; Id = "Microsoft.DotNet.DesktopRuntime.6"; Name = ".NET Desktop Runtime 6 (WPF/WinForms)"; DefaultSelected = $false }
  [pscustomobject]@{ Group = ".NET"; SubGroup = ".NET Desktop Runtime"; Id = "Microsoft.DotNet.DesktopRuntime.8"; Name = ".NET Desktop Runtime 8 (WPF/WinForms)"; DefaultSelected = $false }
  [pscustomobject]@{ Group = ".NET"; SubGroup = ".NET Desktop Runtime"; Id = "Microsoft.DotNet.DesktopRuntime.9"; Name = ".NET Desktop Runtime 9 (WPF/WinForms)"; DefaultSelected = $false }
  [pscustomobject]@{ Group = ".NET"; SubGroup = ".NET Desktop Runtime"; Id = "Microsoft.DotNet.DesktopRuntime.10"; Name = ".NET Desktop Runtime 10 (WPF/WinForms)"; DefaultSelected = $false }

  [pscustomobject]@{ Group = ".NET"; SubGroup = "ASP.NET Core Runtime"; Id = "Microsoft.DotNet.AspNetCore.6"; Name = "ASP.NET Core Runtime 6"; DefaultSelected = $false }
  [pscustomobject]@{ Group = ".NET"; SubGroup = "ASP.NET Core Runtime"; Id = "Microsoft.DotNet.AspNetCore.8"; Name = "ASP.NET Core Runtime 8"; DefaultSelected = $false }
  [pscustomobject]@{ Group = ".NET"; SubGroup = "ASP.NET Core Runtime"; Id = "Microsoft.DotNet.AspNetCore.9"; Name = "ASP.NET Core Runtime 9"; DefaultSelected = $false }
  [pscustomobject]@{ Group = ".NET"; SubGroup = "ASP.NET Core Runtime"; Id = "Microsoft.DotNet.AspNetCore.10"; Name = "ASP.NET Core Runtime 10"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Java"; SubGroup = "IBM Semeru JDK (LTS)"; Id = "IBM.Semeru.8.JDK"; Name = "IBM Semeru JDK 8"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "IBM Semeru JDK (LTS)"; Id = "IBM.Semeru.11.JDK"; Name = "IBM Semeru JDK 11"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "IBM Semeru JDK (LTS)"; Id = "IBM.Semeru.17.JDK"; Name = "IBM Semeru JDK 17"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "IBM Semeru JDK (LTS)"; Id = "IBM.Semeru.21.JDK"; Name = "IBM Semeru JDK 21"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "IBM Semeru JDK (LTS)"; Id = "IBM.Semeru.25.JDK"; Name = "IBM Semeru JDK 25"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "IBM Semeru JRE (LTS)"; Id = "IBM.Semeru.8.JRE"; Name = "IBM Semeru JRE 8"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "IBM Semeru JRE (LTS)"; Id = "IBM.Semeru.11.JRE"; Name = "IBM Semeru JRE 11"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "IBM Semeru JRE (LTS)"; Id = "IBM.Semeru.17.JRE"; Name = "IBM Semeru JRE 17"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "IBM Semeru JRE (LTS)"; Id = "IBM.Semeru.21.JRE"; Name = "IBM Semeru JRE 21"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "IBM Semeru JRE (LTS)"; Id = "IBM.Semeru.25.JRE"; Name = "IBM Semeru JRE 25"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "Amazon Corretto JDK (LTS)"; Id = "Amazon.Corretto.8.JDK"; Name = "Amazon Corretto JDK 8"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "Amazon Corretto JDK (LTS)"; Id = "Amazon.Corretto.11.JDK"; Name = "Amazon Corretto JDK 11"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "Amazon Corretto JDK (LTS)"; Id = "Amazon.Corretto.17.JDK"; Name = "Amazon Corretto JDK 17"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "Amazon Corretto JDK (LTS)"; Id = "Amazon.Corretto.21.JDK"; Name = "Amazon Corretto JDK 21"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "Amazon Corretto JDK (LTS)"; Id = "Amazon.Corretto.25.JDK"; Name = "Amazon Corretto JDK 25"; DefaultSelected = $false }
  # Corretto JRE: only version 8 is currently published in Winget.
  [pscustomobject]@{ Group = "Java"; SubGroup = "Amazon Corretto JRE (LTS)"; Id = "Amazon.Corretto.8.JRE"; Name = "Amazon Corretto JRE 8"; DefaultSelected = $false }

  [pscustomobject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JDK (LTS)"; Id = "EclipseAdoptium.Temurin.8.JDK"; Name = "Eclipse Temurin JDK 8"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JDK (LTS)"; Id = "EclipseAdoptium.Temurin.11.JDK"; Name = "Eclipse Temurin JDK 11"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JDK (LTS)"; Id = "EclipseAdoptium.Temurin.17.JDK"; Name = "Eclipse Temurin JDK 17"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JDK (LTS)"; Id = "EclipseAdoptium.Temurin.21.JDK"; Name = "Eclipse Temurin JDK 21"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JDK (LTS)"; Id = "EclipseAdoptium.Temurin.25.JDK"; Name = "Eclipse Temurin JDK 25"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JRE (LTS)"; Id = "EclipseAdoptium.Temurin.8.JRE"; Name = "Eclipse Temurin JRE 8"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JRE (LTS)"; Id = "EclipseAdoptium.Temurin.11.JRE"; Name = "Eclipse Temurin JRE 11"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JRE (LTS)"; Id = "EclipseAdoptium.Temurin.17.JRE"; Name = "Eclipse Temurin JRE 17"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JRE (LTS)"; Id = "EclipseAdoptium.Temurin.21.JRE"; Name = "Eclipse Temurin JRE 21"; DefaultSelected = $false }
  [pscustomobject]@{ Group = "Java"; SubGroup = "Eclipse Adoptium Temurin JRE (LTS)"; Id = "EclipseAdoptium.Temurin.25.JRE"; Name = "Eclipse Temurin JRE 25"; DefaultSelected = $false }
)

$script:vcRedistPackages = @(
  [pscustomobject]@{ Id = "Microsoft.VCRedist.2005.x64"; Name = "VC++ 2005 x64" }
  [pscustomobject]@{ Id = "Microsoft.VCRedist.2005.x86"; Name = "VC++ 2005 x86" }
  [pscustomobject]@{ Id = "Microsoft.VCRedist.2008.x64"; Name = "VC++ 2008 x64" }
  [pscustomobject]@{ Id = "Microsoft.VCRedist.2008.x86"; Name = "VC++ 2008 x86" }
  [pscustomobject]@{ Id = "Microsoft.VCRedist.2010.x64"; Name = "VC++ 2010 x64" }
  [pscustomobject]@{ Id = "Microsoft.VCRedist.2010.x86"; Name = "VC++ 2010 x86" }
  [pscustomobject]@{ Id = "Microsoft.VCRedist.2012.x64"; Name = "VC++ 2012 x64" }
  [pscustomobject]@{ Id = "Microsoft.VCRedist.2012.x86"; Name = "VC++ 2012 x86" }
  [pscustomobject]@{ Id = "Microsoft.VCRedist.2013.x64"; Name = "VC++ 2013 x64" }
  [pscustomobject]@{ Id = "Microsoft.VCRedist.2013.x86"; Name = "VC++ 2013 x86" }
  [pscustomobject]@{ Id = "Microsoft.VCRedist.2015+.x64"; Name = "VC++ 2015+ x64" }
  [pscustomobject]@{ Id = "Microsoft.VCRedist.2015+.x86"; Name = "VC++ 2015+ x86" }
)

$script:vcRedistAioPackage = [pscustomobject]@{ Id = "abbodi1406.vcredist"; Name = "VC Redist AIO (abbodi1406)" }

# ============================================================================
# Logging
# ============================================================================

function Initialize-Log {
  param([string]$Title = "PC Setup & Package Installation Log")

  $header = @"
================================================================================
$Title
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
  param(
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

# ============================================================================
# Admin Check
# ============================================================================

function Test-AdminPrivileges {
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

  if (-not $isAdmin) {
    Write-Log "This script requires administrator privileges." -Level "ERROR"
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Red
    exit 1
  }

  Write-Log "Administrator privileges verified" -Level "SUCCESS"
}

# ============================================================================
# Winget Helpers
# ============================================================================

function Resolve-WingetPath {
  # Strategy 1: Try invoking winget directly.
  try {
    $output = (& winget.exe --version 2>$null) | Out-String
    if ($output -match 'v\d') { return "winget.exe" }
  }
  catch {
    # winget.exe not found via direct invocation — try other strategies
    $null = $_
  }

  # Strategy 2: Get-Command lookup
  $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  # Strategy 3: Resolve from the DesktopAppInstaller AppX package
  $pkg = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $pkg) {
    $pkg = Get-AppxPackage -AllUsers -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue | Select-Object -First 1
  }
  if ($pkg) {
    $wingetExe = Join-Path -Path $pkg.InstallLocation -ChildPath "winget.exe"
    if (Test-Path -Path $wingetExe) {
      Write-Log "Resolved winget from AppX package: $wingetExe" -Level "INFO"
      return $wingetExe
    }
  }

  # Strategy 4: Search known WindowsApps locations
  $candidates = @(
    "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe\winget.exe"
  )
  foreach ($pattern in $candidates) {
    $found = Get-Item -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
      Write-Log "Resolved winget from fallback path: $($found.FullName)" -Level "INFO"
      return $found.FullName
    }
  }

  return $null
}

function Invoke-WingetCommand {
  param(
    [string[]]$Arguments
  )

  if ($Arguments -notcontains "--accept-source-agreements" -and
    $Arguments[0] -notmatch '^--') {
    $Arguments += "--accept-source-agreements"
  }

  if (-not $script:wingetPath) {
    $script:wingetPath = Resolve-WingetPath
  }
  if (-not $script:wingetPath) {
    return @{ StdOut = @("winget.exe not found"); ExitCode = -1 }
  }

  $commandOutput = & $script:wingetPath @Arguments 2>&1
  $exitCode = $LASTEXITCODE
  return @{
    StdOut = $commandOutput
    ExitCode = $exitCode
  }
}

function Ensure-Winget {
  Write-Log "Checking for Winget installation..." -Level "INFO"

  $script:wingetPath = Resolve-WingetPath
  if ($script:wingetPath) {
    $versionInfo = Invoke-WingetCommand -Arguments @("--version")
    if ($versionInfo.ExitCode -eq 0) {
      $currentVersion = "$($versionInfo.StdOut | Select-Object -First 1)".Trim()
      Write-Log "Winget found: $currentVersion" -Level "SUCCESS"

      Write-Log "Checking for Winget (App Installer) updates..." -Level "INFO"
      $upgradeResult = Invoke-WingetCommand -Arguments @(
        "upgrade","--id","Microsoft.AppInstaller",
        "--accept-source-agreements","--accept-package-agreements","--silent"
      )
      if ($upgradeResult.ExitCode -eq 0) {
        $newVersionInfo = Invoke-WingetCommand -Arguments @("--version")
        $newVersion = "$($newVersionInfo.StdOut | Select-Object -First 1)".Trim()
        if ($newVersion -ne $currentVersion) {
          Write-Log "Winget upgraded: $currentVersion -> $newVersion" -Level "SUCCESS"
        }
        else {
          Write-Log "Winget is already up to date ($currentVersion)" -Level "SUCCESS"
        }
      }
      else {
        $outputText = ($upgradeResult.StdOut | Out-String)
        if ($outputText -match "No applicable update found|No available upgrade") {
          Write-Log "Winget is already up to date ($currentVersion)" -Level "SUCCESS"
        }
        else {
          Write-Log "Could not upgrade Winget automatically. Continuing with $currentVersion." -Level "WARNING"
        }
      }
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

  $script:wingetPath = Resolve-WingetPath
  if (-not $script:wingetPath) {
    Write-Log "Winget still not available after installation attempt." -Level "ERROR"
    return $false
  }

  Write-Log "Winget installation completed" -Level "SUCCESS"
  return $true
}

function Update-WingetSources {
  Write-Log "Updating Winget package sources..." -Level "INFO"

  $result = Invoke-WingetCommand -Arguments @("source","update")
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

# ============================================================================
# Installed Detection
# ============================================================================

function Initialize-InstalledCacheFromWinget {
  Write-Log "Creating installed-package snapshot from Winget..." -Level "INFO"

  # Strategy 1: JSON output (winget >= v1.6)
  $result = Invoke-WingetCommand -Arguments @("list","--output","json")
  if ($result.ExitCode -eq 0) {
    $jsonText = ($result.StdOut | Out-String)
    if (-not [string]::IsNullOrWhiteSpace($jsonText)) {
      try {
        $payload = $jsonText | ConvertFrom-Json -ErrorAction Stop

        $packageEntries = @()
        if ($payload -and ($payload.PSObject.Properties.Name -contains "Sources")) {
          foreach ($source in @($payload.Sources)) {
            if ($source -and ($source.PSObject.Properties.Name -contains "Packages")) {
              $packageEntries += @($source.Packages)
            }
          }
        }
        elseif ($payload -and ($payload.PSObject.Properties.Name -contains "Packages")) {
          $packageEntries += @($payload.Packages)
        }

        $script:installedCache = @{}
        $detectedCount = 0
        foreach ($pkg in $packageEntries) {
          if ($pkg -and ($pkg.PSObject.Properties.Name -contains "PackageIdentifier") -and -not [string]::IsNullOrWhiteSpace($pkg.PackageIdentifier)) {
            $script:installedCache[$pkg.PackageIdentifier] = $true
            $detectedCount++
          }
        }

        $script:installedCachePrimed = $true
        Write-Log "Winget snapshot ready (JSON). Detected $detectedCount installed package identifiers." -Level "SUCCESS"
        return $true
      }
      catch {
        Write-Log "Could not parse Winget JSON output: $($_.Exception.Message)" -Level "WARNING" -NoConsole
      }
    }
  }

  # Strategy 2: Parse text table output (winget < v1.6 or JSON failed)
  Write-Log "JSON snapshot unavailable, parsing text table from 'winget list'..." -Level "INFO"
  $result = Invoke-WingetCommand -Arguments @("list")
  if ($result.ExitCode -ne 0) {
    Write-Log "Could not read Winget package list. Falling back to per-package checks." -Level "WARNING"
    $script:installedCachePrimed = $false
    return $false
  }

  $lines = @($result.StdOut | ForEach-Object { "$_" })
  $headerIdx = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '\bId\b' -and $lines[$i] -match '\bVersion\b') {
      $headerIdx = $i
      break
    }
  }

  if ($headerIdx -lt 0) {
    Write-Log "Could not locate header row in winget list output. Falling back to per-package checks." -Level "WARNING"
    $script:installedCachePrimed = $false
    return $false
  }

  $header = $lines[$headerIdx]
  $idStart = $header.IndexOf("Id")
  $versionStart = $header.IndexOf("Version")
  if ($idStart -lt 0 -or $versionStart -lt 0 -or $versionStart -le $idStart) {
    Write-Log "Could not parse column positions from winget list header. Falling back to per-package checks." -Level "WARNING"
    $script:installedCachePrimed = $false
    return $false
  }

  $dataStart = $headerIdx + 1
  if ($dataStart -lt $lines.Count -and $lines[$dataStart] -match '^[\s-]+$') {
    $dataStart++
  }

  $script:installedCache = @{}
  $detectedCount = 0
  for ($i = $dataStart; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line.Length -le $idStart) { continue }
    $idEnd = [math]::Min($line.Length,$versionStart)
    $pkgId = $line.Substring($idStart,$idEnd - $idStart).Trim()
    if (-not [string]::IsNullOrWhiteSpace($pkgId) -and $pkgId -match '\S+\.\S+') {
      $script:installedCache[$pkgId] = $true
      $detectedCount++
    }
  }

  $script:installedCachePrimed = $true
  Write-Log "Winget snapshot ready (text). Detected $detectedCount installed package identifiers." -Level "SUCCESS"
  return $true
}

function Test-PackageInstalled {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PackageId,
    [switch]$Refresh
  )

  if (-not $Refresh -and $script:installedCache.ContainsKey($PackageId)) {
    return [bool]$script:installedCache[$PackageId]
  }

  if (-not $Refresh -and $script:installedCachePrimed) {
    $script:installedCache[$PackageId] = $false
    return $false
  }

  $result = Invoke-WingetCommand -Arguments @("list","--id",$PackageId,"--exact")
  if ($result.ExitCode -ne 0) {
    $script:installedCache[$PackageId] = $false
    return $false
  }

  $allText = ($result.StdOut | Out-String)
  if ($allText -match "No installed package found matching input criteria") {
    $script:installedCache[$PackageId] = $false
    return $false
  }

  $installed = ($allText -match [regex]::Escape($PackageId))
  $script:installedCache[$PackageId] = $installed
  return $installed
}

function Test-BundleInstalled {
  param(
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

# ============================================================================
# Windows Features
# ============================================================================

function Test-WindowsFeatureEnabled {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FeatureName
  )

  $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue
  return ($feature -and $feature.State -eq "Enabled")
}

function Enable-WindowsFeatureIfNeeded {
  param(
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

# ============================================================================
# Catalog Item State & Action Dispatch
# ============================================================================

function Get-CatalogItemInstalledState {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Item
  )

  switch ($Item.Action) {
    "InstallVCRedist" { return (Test-BundleInstalled -Packages $script:vcRedistPackages) }
    "InstallVCRedistAIO" { return (Test-PackageInstalled -PackageId $script:vcRedistAioPackage.Id) }
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
  param(
    [Parameter(Mandatory = $true)]
    [string]$Action
  )

  switch ($Action) {
    "InstallVCRedist" {
      Install-VCRedist | Out-Null
      return
    }
    "InstallVCRedistAIO" {
      Install-VCRedistAIO | Out-Null
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

# ============================================================================
# Package Installation
# ============================================================================

function Install-Package {
  param(
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
    "--id",$PackageId
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
  param(
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

# ============================================================================
# Action Implementations
# ============================================================================

function Install-VCRedist {
  Write-Log "========================================" -Level "INFO"
  Write-Log "Installing Visual C++ Redistributables (package-by-package)..." -Level "INFO"
  Write-Log "========================================" -Level "INFO"

  $result = Install-Packages -Packages $script:vcRedistPackages
  if ($result.Failed -eq 0) {
    Write-Log "Visual C++ Redistributables (package-by-package) completed successfully" -Level "SUCCESS"
    return $true
  }

  Write-Log "Visual C++ Redistributables (package-by-package) completed with failures" -Level "WARNING"
  return $false
}

function Install-VCRedistAIO {
  Write-Log "========================================" -Level "INFO"
  Write-Log "Installing VC Redist AIO (abbodi1406.vcredist)..." -Level "INFO"
  Write-Log "========================================" -Level "INFO"

  $ok = Install-Package -PackageId $script:vcRedistAioPackage.Id -PackageName $script:vcRedistAioPackage.Name
  if ($ok) {
    Write-Log "VC Redist AIO completed successfully" -Level "SUCCESS"
    return $true
  }

  Write-Log "VC Redist AIO completed with failures" -Level "WARNING"
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
    foreach ($step in @("StartScan","StartDownload","StartInstall")) {
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

# ============================================================================
# Main Orchestrator
# ============================================================================

function Invoke-PCSetup {
  param(
    [switch]$SkipInteractiveSelection,
    [scriptblock]$ShowSelector
  )

  Initialize-Log
  Test-AdminPrivileges

  if (-not (Ensure-Winget)) {
    Write-Log "Cannot continue without Winget. Exiting..." -Level "ERROR"
    exit 1
  }

  Update-WingetSources

  $appCatalog = @($script:appCatalog | ForEach-Object { $_.PSObject.Copy() })

  [void](Initialize-InstalledCacheFromWinget)

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
    $selectedApps = & $ShowSelector -Catalog $appCatalog
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
