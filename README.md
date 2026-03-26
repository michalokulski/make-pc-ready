# MakePCReady - Automated PC Setup Script

Tired of configuring your PC after a rebuild? This PowerShell script automates the installation of multiple applications using Winget with comprehensive logging.

## Features

✅ **Automated Installation** - Install multiple packages with a single command  
✅ **Interactive App Selection** - Check/uncheck specific applications before install  
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

After app selection, the script asks whether to:
- Install all Visual C++ Redistributables
- Install WSL from Winget
- Enable Hyper-V

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
[PSCustomObject]@{ Id = "WingetPackageId"; Name = "Display Name"; DefaultSelected = $true }
```

### Example

```powershell
$appCatalog = @(
    [PSCustomObject]@{ Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code"; DefaultSelected = $true }
    [PSCustomObject]@{ Id = "Python.Python.3.12"; Name = "Python 3.12"; DefaultSelected = $true }
    [PSCustomObject]@{ Id = "NodeJS.NodeJS"; Name = "Node.js"; DefaultSelected = $false }
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
| HWiNFO | REALiX.HWiNFO | Not selected |
| WinDirStat | WinDirStat.WinDirStat | Not selected |

Optional steps are prompted separately:
- Visual C++ Redistributables (2005 to 2015+, x86/x64)
- WSL (`Microsoft.WSL`) via Winget
- Hyper-V enablement with pre-check and post-check

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
