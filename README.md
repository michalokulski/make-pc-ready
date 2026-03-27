# MakePCReady - Automated PC Setup Script

Tired of configuring your PC after a rebuild? This PowerShell script automates the installation of 112+ applications using Winget with comprehensive logging.

## Features

✅ **Collapsible Tree TUI** - Full keyboard-driven selector with collapsible groups/subgroups  
✅ **112+ Package Catalog** - Applications, gaming, AI/LLM, runtimes, .NET, Java, and more  
✅ **Smart Installed Detection** - Dual-strategy detection: JSON snapshot (`winget list --output json`) on v1.6+, with automatic text table parsing fallback for older Winget versions  
✅ **Filter & Hide Installed** - Real-time text filter and toggle to hide already-installed packages  
✅ **WPF GUI Alternative** - A separate WPF-based graphical interface for the same catalog  
✅ **Comprehensive Logging** - All actions logged to a timestamped file  
✅ **Error Handling** - Graceful error handling with detailed error messages  
✅ **Admin Check** - Verifies admin privileges before running  
✅ **Winget Management** - Checks, installs, and self-upgrades Winget (via `Microsoft.AppInstaller`) automatically  
✅ **Progress Tracking** - Real-time console output + file logging  
✅ **Summary Report** - Installation summary with success/failure counts  

## Quick Start

### Prerequisites

- Windows 10/11
- PowerShell 5.1 or higher
- Administrator privileges
- Internet connection

### Console TUI (MakePCReady.ps1)

1. Open PowerShell as Administrator
2. Navigate to the script directory
3. Run:

```powershell
.\MakePCReady.ps1
```

The script opens a collapsible tree selector grouped by category:

**Navigation:**
- **Up/Down** arrows to move cursor
- **Left/Right** to collapse/expand groups and subgroups
- **Tab** to jump between group headers
- **Home/End/PageUp/PageDown** for fast navigation

**Selection:**
- **Space** to toggle individual items, or toggle entire groups/subgroups
- **A** select all, **N** select none
- **F** filter by text, **R** reset filter
- **H** hide already-installed packages

**Confirm:**
- **Enter** to review a grouped confirmation screen
- **Y** to proceed, **N** or **Esc** to go back

### WPF GUI (MakePCReadyAlternativeGUI.ps1)

For a graphical Windows Presentation Foundation interface:

```powershell
.\MakePCReadyAlternativeGUI.ps1
```

Provides a WPF window with checkboxes, search, and the same full catalog.

After app selection (both scripts):
- Selected package entries are installed via Winget
- Selected action entries (VC++ bundles, Windows features) are executed
- WSL, Hyper-V, and VirtualBox are selectable in the same list
- Maintenance actions are available (Winget bulk upgrade and Windows Update trigger)

### Custom Log File Location

```powershell
.\MakePCReady.ps1 -LogPath "C:\Logs\MySetup.log"
```

### Non-Interactive Mode

Use defaults and skip the app selection screen:

```powershell
.\MakePCReady.ps1 -SkipInteractiveSelection
```

### Default Log Location

If no path is specified, logs are saved to:
```
C:\Users\[YourUsername]\Desktop\MakePCReady.log
```

## Log File Features

The log file captures:
- **Timestamps** - Exact time of each action
- **Log Levels** - INFO, SUCCESS, WARNING, ERROR
- **Detailed Messages** - Every operation is logged
- **Installation Results** - Success/failure for each package
- **Summary** - Final report with elapsed time

### Example Log Output

```
================================================================================
PC Setup & Package Installation Log
Started: 2024-02-23 14:30:45
User: YourUsername
Computer: COMPUTERNAME
PowerShell Version: 7.4.0
================================================================================

14:30:46 [SUCCESS] Administrator privileges verified
14:30:47 [INFO] Checking for Winget installation...
14:30:48 [SUCCESS] Winget found: v1.12.470
14:30:48 [INFO] Checking for Winget (App Installer) updates...
14:30:52 [SUCCESS] Winget upgraded: v1.12.470 -> v1.13.123
14:30:53 [INFO] Updating Winget package sources...
14:30:59 [SUCCESS] Winget sources updated successfully
14:31:00 [INFO] ======== Starting package installation ========
14:31:02 [INFO] Installing: 7-Zip (7zip.7zip)...
14:31:15 [SUCCESS] ✓ Successfully installed: 7-Zip
14:31:17 [INFO] Installing: Git (Git.Git)...
14:31:42 [SUCCESS] ✓ Successfully installed: Git
...
14:35:20 [SUCCESS] ======== Setup Complete! ========
14:35:20 [INFO] Total Installed: 10
14:35:20 [INFO] Total Failed: 0
14:35:20 [INFO] Elapsed time: 00:04:45.2156234
```

## Customizing Packages

Edit the `$appCatalog` array at the beginning of `MakePCReady.ps1` to change the available applications.

### Catalog Entry Format
```powershell
[PSCustomObject]@{ Group = "Applications"; SubGroup = "General"; Id = "WingetPackageId"; Name = "Display Name"; DefaultSelected = $true }
```

For action entries (feature/bundle/custom install logic), use:

```powershell
[PSCustomObject]@{ Group = ".NET"; SubGroup = ".NET Framework"; Action = "EnableDotNetFx35"; Name = ".NET Framework 3.5"; DefaultSelected = $false }
```

### Example

```powershell
$appCatalog = @(
    [PSCustomObject]@{ Group = "Applications"; SubGroup = "General"; Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code"; DefaultSelected = $true }
    [PSCustomObject]@{ Group = ".NET"; SubGroup = ".NET Runtime (Core)"; Id = "Microsoft.DotNet.Runtime.10"; Name = ".NET Runtime 10"; DefaultSelected = $false }
    [PSCustomObject]@{ Group = "Java"; SubGroup = "IBM Semeru JRE (LTS)"; Id = "IBM.Semeru.21.JRE"; Name = "IBM Semeru JRE 21"; DefaultSelected = $false }
)
```

### Finding Winget Package IDs

To find package IDs, run:
```powershell
winget search "application name"
```

## Default Application Catalog

The catalog includes 112+ entries organized into groups and subgroups:

### Applications

| SubGroup | Package | ID |
|----------|---------|-----|
| **General** | 7-Zip | `7zip.7zip` |
| | Git | `Git.Git` |
| | Visual Studio Code | `Microsoft.VisualStudioCode` |
| | PowerShell 7 | `Microsoft.PowerShell` |
| | Sysinternals Suite | `Microsoft.Sysinternals.Suite` |
| | Notepad++ | `Notepad++.Notepad++` |
| | WinDirStat | `WinDirStat.WinDirStat` |
| | Windows Terminal | `Microsoft.WindowsTerminal` |
| | Everything (File Search) | `voidtools.Everything` |
| | DevToys | `DevToys-app.DevToys` |
| **Browsers and Essentials** | Google Chrome | `Google.Chrome` |
| | Mozilla Firefox | `Mozilla.Firefox` |
| | VLC Media Player | `VideoLAN.VLC` |
| | FFmpeg | `Gyan.FFmpeg` |
| | Microsoft PowerToys | `Microsoft.PowerToys` |
| | Brave Browser | `Brave.Brave` |
| **Hardware Tools** | HWiNFO | `REALiX.HWiNFO` |
| | CPU-Z | `CPUID.CPU-Z` |
| | GPU-Z | `TechPowerUp.GPU-Z` |
| | NVCleanstall | `TechPowerUp.NVCleanstall` |
| | AMD Software: Cloud Edition | `AMD.AMDSoftwareCloudEdition` |
| | Display Driver Uninstaller (DDU) | `Wagnardsoft.DisplayDriverUninstaller` |
| | CrystalDiskInfo | `CrystalDewWorld.CrystalDiskInfo` |
| | CrystalDiskMark | `CrystalDewWorld.CrystalDiskMark` |
| | HWMonitor | `CPUID.HWMonitor` |
| **Containers** | Podman CLI | `RedHat.Podman` |
| | Podman Desktop | `RedHat.Podman-Desktop` |
| **Developer Tools** | Node.js LTS | `OpenJS.NodeJS.LTS` |
| | GitHub CLI | `GitHub.cli` |
| | GitHub Desktop | `GitHub.GitHubDesktop` |
| | Oh My Posh | `JanDeDobbeleer.OhMyPosh` |
| **Python and Data Tools** | Python 3.13 | `Python.Python.3.13` |
| | Python 3.12 (Compatibility) | `Python.Python.3.12` |
| | uv (Python package/env manager) | `astral-sh.uv` |
| | Miniconda3 | `Anaconda.Miniconda3` |
| | Anaconda3 | `Anaconda.Anaconda3` |
| | JupyterLab | `ProjectJupyter.JupyterLab` |
| | PyCharm Community | `JetBrains.PyCharm.Community` |
| | DBeaver Community | `DBeaver.DBeaver.Community` |
| **Media** | OBS Studio | `OBSProject.OBSStudio` |
| | Spotify | `Spotify.Spotify` |
| **Communication** | Discord | `Discord.Discord` |
| **Networking** | PuTTY | `PuTTY.PuTTY` |
| | WinSCP | `WinSCP.WinSCP` |
| **System Utilities** | Rufus | `Rufus.Rufus` |
| | Ventoy | `Ventoy.Ventoy` |
| **Productivity** | LibreOffice | `TheDocumentFoundation.LibreOffice` |

### Gaming

| SubGroup | Package | ID |
|----------|---------|-----|
| **Launchers** | Steam | `Valve.Steam` |
| | Ubisoft Connect | `Ubisoft.Connect` |
| | GOG Galaxy | `GOG.Galaxy` |
| | Epic Games Launcher | `EpicGames.EpicGamesLauncher` |
| | EA App | `ElectronicArts.EADesktop` |
| | Battle.net | `Blizzard.BattleNet` |

### AI/LLM

| SubGroup | Package | ID |
|----------|---------|-----|
| **Clients** | Claude Desktop | `Anthropic.Claude` |
| | Chatbox | `Bin-Huang.Chatbox` |
| **Local Inference** | Ollama | `Ollama.Ollama` |
| | LM Studio | `ElementLabs.LMStudio` |
| | Backyard AI | `AhoyLabs.BackyardAI` |
| | Msty | `CloudStack.Msty` |
| | Msty (CPU) | `CloudStack.Msty.CPU` |
| | Jan | `Jan.Jan` |
| | Sanctum | `QXYZLabs.Sanctum` |
| **Coding Assistants** | Dive | `OpenAgentPlatform.Dive` |
| | opencode | `SST.opencode` |
| | Cursor | `Anysphere.Cursor` |

### Runtime Bundles, Platform Features & Maintenance

| SubGroup | Package | Type |
|----------|---------|------|
| **VC++** | Visual C++ Redistributables (package-by-package) | Action |
| | VC Redist AIO (abbodi1406 bundle) | Action |
| **Windows** | Windows Subsystem for Linux (WSL) | Action |
| | Hyper-V | Action |
| **Virtualization** | VirtualBox | `Oracle.VirtualBox` |
| **Updates** | Upgrade all installed apps via Winget | Action |
| | Trigger Windows Update (scan/download/install) | Action |

### .NET

| SubGroup | Versions |
|----------|----------|
| **.NET Framework** | 3.5 (Windows Feature), 4.x (Presence Check) |
| **.NET Runtime (Core)** | 6, 8, 9, 10 |
| **.NET Desktop Runtime** | 6, 8, 9, 10 |
| **ASP.NET Core Runtime** | 6, 8, 9, 10 |

### Java

| SubGroup | Versions |
|----------|----------|
| **IBM Semeru JDK (LTS)** | 8, 11, 17, 21, 25 |
| **IBM Semeru JRE (LTS)** | 8, 11, 17, 21, 25 |
| **Amazon Corretto JDK (LTS)** | 8, 11, 17, 21, 25 |
| **Amazon Corretto JRE (LTS)** | 8 |
| **Eclipse Adoptium Temurin JDK (LTS)** | 8, 11, 17, 21, 25 |
| **Eclipse Adoptium Temurin JRE (LTS)** | 8, 11, 17, 21, 25 |

> **Note:** Only 7-Zip, Git, and Visual Studio Code are selected by default. All other entries default to unselected.

> **Note:** Only Corretto JRE 8 is currently available in Winget. Corretto JRE 11/17/21/25 are not published there.

## Troubleshooting

### Script Won't Run

Ensure PowerShell execution policy allows scripts:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "This script requires administrator privileges!"

The script must run as Administrator. Right-click PowerShell and select "Run as Administrator".

### Winget Installation Failed

If Winget fails to install automatically:
- Install from Microsoft Store: https://apps.microsoft.com/detail/app-installer/9NBLGGH4NNS1
- Or download: https://aka.ms/getwinget

### Package Installation Failed

Check the log file for specific error messages. Common issues:
- Incorrect package ID (verify with `winget search`)
- Package already installed
- Network connectivity issues
- Package temporarily unavailable

## Script Functions

- **Initialize-Log** - Creates and initializes log file
- **Write-Log** - Logs messages with color coding
- **Test-AdminPrivileges** - Validates admin rights
- **Ensure-Winget** - Checks/installs Winget and self-upgrades via `Microsoft.AppInstaller`
- **Initialize-InstalledCacheFromWinget** - Builds installed-package cache using JSON or text table fallback
- **Get-CatalogItemInstalledState** - Checks a catalog item against the installed cache
- **Update-WingetSources** - Refreshes package sources
- **Install-Package** - Installs an individual package and validates exit code
- **Install-Packages** - Batch installation with tracking
- **Show-InteractiveAppSelector** - Collapsible tree TUI selector with filter and hide-installed
- **Install-VCRedist** - Installs VC++ redistributables one-by-one
- **Install-VCRedistAIO** - Installs VC++ Redistributable AIO package
- **Upgrade-AllWingetPackages** - Runs Winget bulk upgrades (`winget upgrade --all -r -h --include-unknown`)
- **Trigger-WindowsUpdate** - Triggers Windows Update scan/download/install commands
- **Enable-WindowsFeatureIfNeeded** - Enables Windows optional feature when needed
- **Ensure-DotNetFramework4x** - Verifies .NET Framework 4.x presence
- **Install-WSLFromWinget** - Installs WSL from Winget package ID
- **Enable-HyperV** - Checks current state and enables Hyper-V when needed
- **Invoke-SelectedAction** - Dispatches a catalog entry to its install handler
- **Invoke-PCSetup** - Main orchestration function

## Notes

- Installation follows the array order
- 400ms delay between each package installation
- Failed installations don't stop the process
- All output appears in console AND log file
- Requires active internet connection
- Some packages may require system restart (not automatic)
