param (
    [string]$LogPath = "$env:USERPROFILE\Desktop\MakePCReady.log"
)

# ============================================================================
# PowerShell PC Setup & Package Installation Script with Logging
# ============================================================================

# Initialize logging
$script:logFile = $LogPath
$script:logStartTime = Get-Date

# Create log file with header
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

# Write-Log function
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
        $color = $colors[$Level] ?? "White"
        Write-Host $logMessage -ForegroundColor $color
    }
}

# Check admin privileges
function Test-AdminPrivileges {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Log "ERROR: This script requires administrator privileges!" -Level "ERROR"
        Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Red
        exit 1
    }
    
    Write-Log "Administrator privileges verified" -Level "SUCCESS"
}

# Check if Winget is installed
function Test-Winget {
    Write-Log "Checking for Winget installation..." -Level "INFO"
    
    try {
        $wingetVersion = winget --version
        Write-Log "Winget found: $wingetVersion" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Winget not found. Installing from Microsoft Store..." -Level "WARNING"
        
        try {
            $uri = "https://aka.ms/getwinget"
            Invoke-WebRequest -Uri $uri -OutFile "$env:TEMP\winget.msixbundle"
            Add-AppxPackage -Path "$env:TEMP\winget.msixbundle"
            Write-Log "Winget installation completed" -Level "SUCCESS"
            return $true
        }
        catch {
            Write-Log "Failed to install Winget: $_" -Level "ERROR"
            return $false
        }
    }
}

# Update Winget package list
function Update-WingetSources {
    Write-Log "Updating Winget package sources..." -Level "INFO"
    
    try {
        winget source update
        Write-Log "Winget sources updated successfully" -Level "SUCCESS"
    }
    catch {
        Write-Log "Warning: Could not update Winget sources: $_" -Level "WARNING"
    }
}

# Install a package using Winget
function Install-Package {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageId,
        [string]$PackageName = $PackageId
    )
    
    Write-Log "Installing: $PackageName ($PackageId)..." -Level "INFO"
    
    try {
        $output = winget install --id $PackageId --accept-package-agreements --accept-source-agreements -e 2>&1
        Write-Log "✓ Successfully installed: $PackageName" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "✗ Failed to install $PackageName : $_" -Level "ERROR"
        return $false
    }
}

# Install multiple packages
function Install-Packages {
    param (
        [string[]]$Packages
    )
    
    Write-Log "========================================" -Level "INFO"
    Write-Log "Starting package installation (Total: $($Packages.Count) packages)" -Level "INFO"
    Write-Log "========================================" -Level "INFO"
    
    $installed = 0
    $failed = 0
    
    foreach ($package in $Packages) {
        $packageId = $package.Split('|')[0]
        $packageName = $package.Split('|')[1] ?? $packageId
        
        if (Install-Package -PackageId $packageId -PackageName $packageName) {
            $installed++
        }
        else {
            $failed++
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    Write-Log "========================================" -Level "INFO"
    Write-Log "Installation Summary: $installed installed, $failed failed" -Level "INFO"
    Write-Log "========================================" -Level "INFO"
    
    return @{ Installed = $installed; Failed = $failed }
}

# Install Visual C++ Redistributables
function Install-VCRedist {
    Write-Log "========================================" -Level "INFO"
    Write-Log "Installing Visual C++ Redistributables..." -Level "INFO"
    Write-Log "========================================" -Level "INFO"
    
    try {
        $vcRedists = @(
            "Microsoft.VCRedist.2005.x64"
            "Microsoft.VCRedist.2005.x86"
            "Microsoft.VCRedist.2008.x64"
            "Microsoft.VCRedist.2008.x86"
            "Microsoft.VCRedist.2010.x64"
            "Microsoft.VCRedist.2010.x86"
            "Microsoft.VCRedist.2012.x64"
            "Microsoft.VCRedist.2012.x86"
            "Microsoft.VCRedist.2013.x64"
            "Microsoft.VCRedist.2013.x86"
            "Microsoft.VCRedist.2015+.x64"
            "Microsoft.VCRedist.2015+.x86"
        )
        
        $command = "winget install " + ($vcRedists -join " ") + " --accept-package-agreements --accept-source-agreements -e"
        Write-Log "Running: $command" -Level "INFO"
        
        Invoke-Expression $command 2>&1 | Out-Null
        Write-Log "✓ Successfully installed Visual C++ Redistributables" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "✗ Failed to install Visual C++ Redistributables: $_" -Level "ERROR"
        return $false
    }
}

# Enable Hyper-V
function Enable-HyperV {
    Write-Log "========================================" -Level "INFO"
    Write-Log "Enabling Hyper-V..." -Level "INFO"
    Write-Log "========================================" -Level "INFO"
    
    try {
        Write-Log "Running: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All" -Level "INFO"
        $result = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
        
        if ($result.RestartNeeded) {
            Write-Log "✓ Hyper-V enabled successfully (System restart required)" -Level "SUCCESS"
            Write-Log "WARNING: System restart is required to complete Hyper-V installation" -Level "WARNING"
        }
        else {
            Write-Log "✓ Hyper-V enabled successfully" -Level "SUCCESS"
        }
        return $true
    }
    catch {
        Write-Log "✗ Failed to enable Hyper-V: $_" -Level "ERROR"
        return $false
    }
}

# Main function
function Invoke-PCSetup {
    Initialize-Log
    Test-AdminPrivileges
    
    if (-not (Test-Winget)) {
        Write-Log "Cannot continue without Winget. Exiting..." -Level "ERROR"
        exit 1
    }
    
    Update-WingetSources
    
    # Define packages to install
    # Format: "WingetPackageId|Display Name"
    $packages = @(
        "7zip.7zip|7-Zip"
        "Git.Git|Git"
        "Microsoft.VisualStudioCode|Visual Studio Code"
        "Microsoft.PowerShell|PowerShell 7"
        "Microsoft.WSL|Windows Subsystem for Linux"
        "Microsoft.Sysinternals.Suite|Sysinternals Suite"
        "Notepad++.Notepad++|Notepad++"
        "REALiX.HWiNFO|HWiNFO"
        "WinDirStat.WinDirStat|WinDirStat"
    )
    
    $results = Install-Packages -Packages $packages
    
    # Install Visual C++ Redistributables
    Install-VCRedist
    
    # Enable Hyper-V
    Enable-HyperV
    
    # Final summary
    Write-Log "" -Level "INFO" -NoConsole
    Write-Log "========================================" -Level "INFO"
    Write-Log "Setup Complete!" -Level "SUCCESS"
    Write-Log "Total Installed: $($results.Installed)" -Level "INFO"
    Write-Log "Total Failed: $($results.Failed)" -Level "INFO"
    Write-Log "Log file: $script:logFile" -Level "INFO"
    Write-Log "Elapsed time: $((Get-Date) - $script:logStartTime)" -Level "INFO"
    Write-Log "========================================" -Level "INFO"
    
    Write-Host "`nLog file saved to: $script:logFile" -ForegroundColor Green
}

# Run the main function
Invoke-PCSetup
