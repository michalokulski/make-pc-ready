# MakePCReady - Automated PC Setup Script

Tired of configuring your PC after a rebuild? This PowerShell script automates the installation of multiple applications using Winget with comprehensive logging.

## Features

✅ **Automated Installation** - Install multiple packages with a single command  
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

### Custom Log File Location

```powershell
.\MakePCReady.ps1 -LogPath "C:\Logs\MySetup.log"
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

Edit the `$packages` array in `MakePCReady.ps1` to install different applications.

### Format
```powershell
"WingetPackageId|Display Name"
```

### Examples

```powershell
$packages = @(
    "Microsoft.VisualStudioCode|Visual Studio Code"
    "JetBrains.IntelliJIDEA.Community|IntelliJ IDEA"
    "Python.Python.3.12|Python 3.12"
    "NodeJS.NodeJS|Node.js"
    "Docker.Docker|Docker Desktop"
    "Microsoft.WindowsTerminal|Windows Terminal"
)
```

### Finding Winget Package IDs

To find package IDs, run:
```powershell
winget search "application name"
```

## Default Packages

The script comes pre-configured with commonly used packages:

| Package | ID | Purpose |
|---------|-----|---------|
| 7-Zip | 7zip.7zip | Archive utility |
| Git | Git.Git | Version control |
| GitHub Desktop | GitHub.GitHubDesktop | Git client |
| Visual Studio Code | Microsoft.VisualStudioCode | Code editor |
| PowerShell 7 | Microsoft.PowerShell | Modern PowerShell |
| Firefox | Mozilla.Firefox | Web browser |
| Google Chrome | Google.Chrome | Web browser |
| Notepad++ | Notepad++.Notepad++ | Text editor |
| WinRAR | WinRAR.WinRAR | Archive utility |
| VLC | VideoLAN.VLC | Media player |

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
- **Test-Winget** - Checks/installs Winget
- **Update-WingetSources** - Refreshes package sources
- **Install-Package** - Installs individual packages
- **Install-Packages** - Batch installation with tracking
- **Invoke-PCSetup** - Main orchestration function

## Notes

- Installation follows the array order
- 500ms delay between each package installation
- Failed installations don't stop the process
- All output appears in console AND log file
- Requires active internet connection
- Some packages may require system restart (not automatic)
