# MakePCReady - Automated PC Setup Script

Tired of configuring your PC after a rebuild? This PowerShell script automates the installation of multiple applications using Winget with comprehensive logging.

## Features

✅ **Automated Installation** - Install multiple packages with a single command  
✅ **Interactive App Selection** - Check/uncheck specific applications before install  
✅ **Alternative TUI Selector** - Arrow-key/space multi-select (Ubuntu installer style, no external modules)  
✅ **Comprehensive Logging** - All actions logged to a file for debugging  
✅ **Error Handling** - Graceful error handling with detailed error messages  
✅ **Admin Check** - Verifies admin privileges before running  
✅ **Winget Management** - Checks, installs, and updates Winget automatically  
✅ **Progress Tracking** - Real-time console output + file logging  
✅ **Summary Report** - Installation summary with success/failure counts  

## Quick Start

### Prerequisites

- Windows 10/11
- PowerShell 5.0 or higher
- Administrator privileges
- Internet connection

### Basic Usage

1. Open PowerShell as Administrator
2. Navigate to the script directory
3. Run:

```powershell
.\MakePCReady.ps1
```

The script opens an interactive console app selector where you can:
- Toggle apps by index (for example: `1,3,5`)
- Select all with `A`
- Select none with `N`
- Continue with `S`
- Quit with `Q`

### Alternative TUI Selector

For an Ubuntu-installer-style experience with arrow keys and space to select:

```powershell
.\MakePCReadyAlternativeGUI.ps1
```

Controls:
- **Up/Down** arrows to move cursor
- **Space** to toggle selection
- **A** select all, **N** select none
- **Home/End/PageUp/PageDown** for fast navigation
- **Enter** to start installation
- **Esc** to quit

No external modules required. Works with PowerShell 5.1+.

After app selection:
 - Selected package entries are installed
 - Selected action entries (VC++ bundle and Windows features) are executed
 - WSL and Hyper-V are selectable in the same list
- Optional maintenance actions are available (Winget bulk upgrade and Windows Update trigger)

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
14:30:48 [SUCCESS] Winget found: v1.6.x.x
14:30:49 [INFO] Updating Winget package sources...
14:30:55 [SUCCESS] Winget sources updated successfully
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

The interactive selector is pre-loaded with these applications:

| Package | ID | Default |
|---------|-----|---------|
| 7-Zip | 7zip.7zip | Selected |
| Git | Git.Git | Selected |
| Visual Studio Code | Microsoft.VisualStudioCode | Selected |
| PowerShell 7 | Microsoft.PowerShell | Selected |
| Sysinternals Suite | Microsoft.Sysinternals.Suite | Selected |
| Notepad++ | Notepad++.Notepad++ | Selected |
| WinDirStat | WinDirStat.WinDirStat | Not selected |
| Google Chrome | Google.Chrome | Selected |
| Mozilla Firefox | Mozilla.Firefox | Selected |
| VLC Media Player | VideoLAN.VLC | Selected |
| FFmpeg | Gyan.FFmpeg | Selected |
| Microsoft PowerToys | Microsoft.PowerToys | Selected |
| HWiNFO | REALiX.HWiNFO | Not selected |
| CPU-Z | CPUID.CPU-Z | Not selected |
| GPU-Z | TechPowerUp.GPU-Z | Not selected |
| NVCleanstall | TechPowerUp.NVCleanstall | Not selected |
| AMD Software: Cloud Edition | AMD.AMDSoftwareCloudEdition | Not selected |
| Display Driver Uninstaller (DDU) | Wagnardsoft.DisplayDriverUninstaller | Not selected |
| Podman CLI | RedHat.Podman | Not selected |
| Podman Desktop | RedHat.Podman-Desktop | Not selected |
| Python 3.13 | Python.Python.3.13 | Selected |
| Python 3.12 (Compatibility) | Python.Python.3.12 | Not selected |
| uv (Python package/env manager) | astral-sh.uv | Selected |
| Miniconda3 | Anaconda.Miniconda3 | Not selected |
| Anaconda3 | Anaconda.Anaconda3 | Not selected |
| JupyterLab | ProjectJupyter.JupyterLab | Not selected |
| PyCharm Community | JetBrains.PyCharm.Community | Not selected |
| DBeaver Community | DBeaver.DBeaver.Community | Not selected |
| Steam | Valve.Steam | Not selected |
| Ubisoft Connect | Ubisoft.Connect | Not selected |
| GOG Galaxy | GOG.Galaxy | Not selected |
| Epic Games Launcher | EpicGames.EpicGamesLauncher | Not selected |
| EA App | ElectronicArts.EADesktop | Not selected |
| Battle.net | Blizzard.BattleNet | Not selected |
| Claude Desktop | Anthropic.Claude | Not selected |
| Chatbox | Bin-Huang.Chatbox | Not selected |
| Ollama | Ollama.Ollama | Not selected |
| LM Studio | ElementLabs.LMStudio | Not selected |
| Backyard AI | AhoyLabs.BackyardAI | Not selected |
| Msty | CloudStack.Msty | Not selected |
| Msty (CPU) | CloudStack.Msty.CPU | Not selected |
| Jan | Jan.Jan | Not selected |
| Sanctum | QXYZLabs.Sanctum | Not selected |
| Dive | OpenAgentPlatform.Dive | Not selected |
| opencode | SST.opencode | Not selected |
| Cursor | Anysphere.Cursor | Not selected |
| Visual C++ Redistributables (Bundle) | Action: InstallVCRedist | Selected |
| WSL | Action: InstallWSL | Selected |
| Hyper-V | Action: EnableHyperV | Not selected |
| Upgrade all installed apps via Winget | Action: UpgradeAllWingetPackages | Not selected |
| Trigger Windows Update (scan/download/install) | Action: TriggerWindowsUpdate | Not selected |
| .NET Framework 3.5 | Action: EnableDotNetFx35 | Not selected |
| .NET Framework 4.x | Action: EnsureDotNetFx4x | Not selected |
| .NET Runtime 6/8/9/10 | Package IDs | Not selected |
| .NET Desktop Runtime 6/8/9/10 | Package IDs | Not selected |
| ASP.NET Core Runtime 6/8/9/10 | Package IDs | Not selected |
| IBM Semeru JDK 8/11/17/21/25 (LTS) | Package IDs | Not selected |
| IBM Semeru JRE 8/11/17/21/25 (LTS) | Package IDs | Not selected |
| Amazon Corretto JDK 8/11/17/21/25 (LTS) | Package IDs | Not selected |
| Amazon Corretto JRE 8 (LTS) | Package ID | Not selected |
| Eclipse Adoptium Temurin JDK 8/11/17/21/25 (LTS) | Package IDs | Not selected |
| Eclipse Adoptium Temurin JRE 8/11/17/21/25 (LTS) | Package IDs | Not selected |

Note: only Corretto JRE 8 is currently available in Winget. Corretto JRE 11/17/21/25 are not published there.

Optional steps are prompted separately:
- None. WSL and Hyper-V are now part of the main selector.

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
- **Ensure-Winget** - Checks/installs Winget
- **Update-WingetSources** - Refreshes package sources
- **Install-Package** - Installs an individual package and validates exit code
- **Install-Packages** - Batch installation with tracking
- **Show-InteractiveAppSelector** - Interactive check/uncheck selector
- **Install-VCRedist** - Installs VC++ redistributables one-by-one
- **Upgrade-AllWingetPackages** - Runs Winget bulk upgrades (`winget upgrade --all -r -h --include-unknown`)
- **Trigger-WindowsUpdate** - Triggers Windows Update scan/download/install commands
- **Enable-WindowsFeatureIfNeeded** - Enables Windows optional feature when needed
- **Ensure-DotNetFramework4x** - Verifies .NET Framework 4.x presence
- **Install-WSLFromWinget** - Installs WSL from Winget package ID
- **Enable-HyperV** - Checks current state and enables Hyper-V when needed
- **Invoke-PCSetup** - Main orchestration function

## Notes

- Installation follows the array order
- 400ms delay between each package installation
- Failed installations don't stop the process
- All output appears in console AND log file
- Requires active internet connection
- Some packages may require system restart (not automatic)
