# ============================================================================
# VMCommon.psm1 — Shared module for VM creator scripts
# ============================================================================
# Dot-sourced by Testing-Hyper-V/MakeTestVM.ps1 and Testing-QEMU/MakeTestVM-QEMU.ps1.
# Contains: logging, integer validation, ISO source menu, log finalizer.
# ============================================================================

# --- Module-scoped state ---
$script:logFile = $null
$script:logStartTime = $null

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
    param (
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet("SUCCESS", "INFO", "WARNING", "ERROR")]
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
    } while ($choice -notin @("1", "2", "3"))

    return [int]$choice
}

# ============================================================================
# Log Finalizer
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
        Write-Host "VM operation completed successfully!" -ForegroundColor Green
        Write-Host "Log: $script:logFile" -ForegroundColor Gray
    }
    else {
        Write-Host ""
        Write-Host "VM operation failed. Check the log for details." -ForegroundColor Red
        Write-Host "Log: $script:logFile" -ForegroundColor Gray
    }
}