param(
  [string]$VMName,
  [string]$ISOPath,
  [string]$SwitchName,
  [int]$MemoryGB = 4,
  [int]$CPUCount = 2,
  [int]$DiskSizeGB = 64,
  [string]$VMPath,
  [string]$UnattendISOPath,
  [string]$LogPath = $(if (Test-Path "$env:USERPROFILE\Desktop") { "$env:USERPROFILE\Desktop\MakeTestVM.log" } else { "$env:TEMP\MakeTestVM.log" }),
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

$script:scriptRoot = $PSScriptRoot

# Import shared VM module (must be imported BEFORE initializing module state)
Import-Module -Force (Join-Path -Path $PSScriptRoot -ChildPath "..\lib\VMCommon.psm1")

# Hand the log path/start time to the module — Import-Module scopes are isolated,
# so assigning $script:logFile here would be invisible to the module's functions.
Initialize-VMCommonState -LogPath $LogPath -StartTime (Get-Date)

# ============================================================================
# Prerequisites
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
  param(
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
    $validationErrors += "MemoryGB must be at least 1. Received: $([math]::Round($Config.Memory / 1GB, 2)) GB."
  }

  $hostMemory = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
  if ($Config.Memory -gt $hostMemory) {
    $validationErrors += "MemoryGB cannot exceed host physical memory ($([math]::Round($hostMemory / 1GB, 2)) GB). Received: $([math]::Round($Config.Memory / 1GB, 2)) GB."
  }

  if ($Config.DiskSize -lt 40GB) {
    $validationErrors += "DiskSizeGB must be at least 40. Received: $([math]::Round($Config.DiskSize / 1GB, 2)) GB."
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
# Get-WindowsISOViaFido and Get-WindowsISOViaUUPDump now live in lib\VMCommon.psm1.
# Only the Windows-only local file picker remains here.
# ============================================================================

function Select-LocalISO {
  Add-Type -AssemblyName System.Windows.Forms
  $dialog = New-Object System.Windows.Forms.OpenFileDialog
  $dialog.title = "Select Windows Installation ISO"
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
  param(
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

  # Memory (in GB)
  Write-Host ""
  $hostMemoryGB = [math]::Floor((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
  $memGB = Read-PositiveInteger -Prompt "Memory in GB (host has $hostMemoryGB GB) [4]" -DefaultValue 4
  $memory = [int64]$memGB * 1GB

  # CPUs
  $maxCPU = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
  $defaultCPU = [math]::Min(2,$maxCPU)
  $cpus = Read-ValidatedInteger -Prompt "CPU cores (1-$maxCPU) [$defaultCPU]" -Min 1 -Max $maxCPU -DefaultValue $defaultCPU

  # Disk Size (in GB)
  Write-Host ""
  $diskGB = Read-PositiveInteger -Prompt "Disk size in GB (min 40) [64]" -DefaultValue 64
  if ($diskGB -lt 40) {
    Write-Host "Minimum disk size is 40 GB. Using 40 GB." -ForegroundColor Yellow
    $diskGB = 40
  }
  $diskSize = [int64]$diskGB * 1GB

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
    VMName = $vmName
    Memory = $memory
    CPUs = $cpus
    DiskSize = $diskSize
    SwitchName = $selectedSwitch
  }
}

# ============================================================================
# VM Creation
# ============================================================================

function New-TestVM {
  param(
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
      Name = $VMName
      MemoryStartupBytes = $Memory
      Generation = 2
      VHDPath = $vhdxPath
      Path = $BasePath
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

    # Set boot order: HDD first, then DVD drives
    # On first boot the empty HDD is skipped and UEFI falls through to DVD.
    # After Windows installs, HDD boots directly.
    # A boot keystroke is sent as a safety net (see Send-VMBootKeystroke).
    $dvdDrives = Get-VMDvdDrive -VMName $VMName
    $hdd = Get-VMHardDiskDrive -VMName $VMName
    $bootDevices = @($hdd) + @($dvdDrives)
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
# Boot Keystroke Helper
# ============================================================================

function Send-VMBootKeystroke {
  param(
    [Parameter(Mandatory)]
    [string]$VMName
  )

  Write-Log "Sending keystroke to VM to boot from CD/DVD ('Press any key' prompt)..." -Level "INFO"

  try {
    # Brief pause for VM to reach the UEFI/BIOS boot prompt
    Start-Sleep -Seconds 1

    $vm = Get-CimInstance -Namespace 'root\virtualization\v2' -ClassName 'Msvm_ComputerSystem' -Filter "ElementName='$VMName'"
    if (-not $vm) {
      Write-Log "Could not find VM '$VMName' via CIM to send keystroke." -Level "WARNING"
      return
    }

    $keyboard = Get-CimAssociatedInstance -InputObject $vm -ResultClassName 'Msvm_Keyboard'
    if (-not $keyboard) {
      Write-Log "Could not access virtual keyboard for VM '$VMName'." -Level "WARNING"
      return
    }

    # Send Enter key (VK_RETURN = 0x0D) a few times to ensure it's caught
    for ($i = 0; $i -lt 3; $i++) {
      Invoke-CimMethod -InputObject $keyboard -MethodName 'TypeKey' -Arguments @{ keyCode = 0x0D } | Out-Null
      Start-Sleep -Milliseconds 500
    }

    Write-Log "Boot keystroke sent to VM." -Level "SUCCESS"
  }
  catch {
    Write-Log "Could not send boot keystroke (non-critical): $($_.Exception.Message)" -Level "WARNING"
    Write-Log "If the VM shows 'Press any key to boot from CD/DVD', connect and press a key manually." -Level "INFO"
  }
}

# ============================================================================
# Summary & Confirmation
# ============================================================================

function Show-Summary {
  param(
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

  # Language compatibility warning
  $selectedISOLanguage = Get-SelectedISOLanguage
  $isEnglishISO = $selectedISOLanguage -and (
    $selectedISOLanguage -in @("English","English International") -or
    $selectedISOLanguage -match '^en-'
  )
  if ($selectedISOLanguage -and -not $isEnglishISO) {
    Write-Host "  WARNING: ISO language '$($selectedISOLanguage)' differs from the" -ForegroundColor Yellow
    Write-Host "  bundled autounattend.xml (en-US). Installation may not be fully automatic." -ForegroundColor Yellow
    Write-Host ""
  }
  elseif (-not $selectedISOLanguage) {
    Write-Host "  NOTE: ISO language unknown. The bundled autounattend.xml is for English (en-US)." -ForegroundColor Yellow
    Write-Host "  If the ISO uses a different language, installation may require manual steps." -ForegroundColor Yellow
    Write-Host ""
  }

  $confirm = Read-Host "Proceed with VM creation? (Y/n)"
  return ($confirm -eq "" -or $confirm -imatch "^y")
}

# ============================================================================
# Unattend ISO Auto-Generation
# ============================================================================

function New-UnattendISO {
  param(
    [Parameter(Mandatory)]
    [string]$XmlSourcePath,
    [Parameter(Mandatory)]
    [string]$OutputISOPath
  )

  $stagingDir = Join-Path -Path $env:TEMP -ChildPath "unattend_iso_staging"
  if (Test-Path -Path $stagingDir) {
    Remove-Item -Path $stagingDir -Recurse -Force
  }
  New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

  Copy-Item -Path $XmlSourcePath -Destination (Join-Path -Path $stagingDir -ChildPath "autounattend.xml") -Force

  $oscdimg = Get-Command -Name "oscdimg.exe" -ErrorAction SilentlyContinue
  if (-not $oscdimg) {
    throw "oscdimg.exe not found. Install Windows ADK or copy oscdimg.exe to PATH."
  }

  Write-Log "Creating unattend.iso using oscdimg..." -Level "INFO"
  & oscdimg.exe -o -lCIDATA $stagingDir $OutputISOPath

  Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue

  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -Path $OutputISOPath)) {
    throw "oscdimg failed to create unattend.iso (exit code: $LASTEXITCODE)."
  }

  Write-Log "unattend.iso created successfully: $OutputISOPath" -Level "SUCCESS"
}

# ============================================================================
# Main Flow
# ============================================================================

function Main {
  Initialize-Log -Title "Hyper-V Test VM Creator Log"
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

  # Warn if ISO language is unknown (local file or parameter-provided)
  if (-not (Get-SelectedISOLanguage)) {
    Write-Log "ISO language could not be determined. The bundled autounattend.xml is for English (en-US)." -Level "WARNING"
    if (-not $isNonInteractive) {
      Write-Host ""
      Write-Host "  NOTE: Ensure the Windows ISO is English (en-US). The bundled autounattend.xml" -ForegroundColor Yellow
      Write-Host "  is configured for English. A non-English ISO may require manual intervention." -ForegroundColor Yellow
      Write-Host ""
    }
  }

  # ---- Step 2: Resolve Unattend ISO ----
  $unattendISOPath = $UnattendISOPath
  if (-not $unattendISOPath) {
    $unattendISOPath = Join-Path -Path $script:scriptRoot -ChildPath "unattend.iso"
  }

  if (-not (Test-Path -Path $unattendISOPath)) {
    Write-Log "Unattend ISO not found at: $unattendISOPath" -Level "WARNING"
    Write-Log "Attempting to create unattend.iso from autounattend.xml..." -Level "INFO"
    $xmlSource = Join-Path -Path $script:scriptRoot -ChildPath "autounattend.xml"
    if (-not (Test-Path -Path $xmlSource)) {
      Write-Log "autounattend.xml not found in script folder. Cannot create unattend.iso." -Level "ERROR"
      Write-Log "Generate your autounattend.xml at https://schneegans.de/windows/unattend-generator/" -Level "INFO"
      Complete-Log -Success $false
      exit 1
    }
    try {
      New-UnattendISO -XmlSourcePath $xmlSource -OutputISOPath $unattendISOPath
    }
    catch {
      Write-Log "Failed to create unattend.iso: $($_.Exception.Message)" -Level "ERROR"
      Complete-Log -Success $false
      exit 1
    }
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
      VMName = $resolvedVMName
      Memory = [int64]$MemoryGB * 1GB
      CPUs = $CPUCount
      DiskSize = [int64]$DiskSizeGB * 1GB
      SwitchName = $SwitchName
    }
  }
  elseif ($VMName -and $ISOPath) {
    # Enough CLI params provided - skip interactive menu but still validate
    $vmConfig = @{
      VMName = $VMName
      Memory = [int64]$MemoryGB * 1GB
      CPUs = $CPUCount
      DiskSize = [int64]$DiskSizeGB * 1GB
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
    VMName = $vmConfig.VMName
    WindowsISOPath = $isoPath
    UnattendISOPath = $unattendISOPath
    Memory = $vmConfig.Memory
    CPUs = $vmConfig.CPUs
    DiskSize = $vmConfig.DiskSize
    SwitchName = $vmConfig.SwitchName
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
        Send-VMBootKeystroke -VMName $vmConfig.VMName
        Write-Log "VM started! Windows installation is running unattended." -Level "SUCCESS"
        Write-Log "You can connect via: vmconnect localhost $($vmConfig.VMName)" -Level "INFO"

        if ($OpenConsole) {
          Start-Process "vmconnect" -ArgumentList "localhost","`"$($vmConfig.VMName)`""
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
        Send-VMBootKeystroke -VMName $vmConfig.VMName
        Write-Log "VM started! Windows installation is running unattended." -Level "SUCCESS"
        Write-Log "You can connect via: vmconnect localhost $($vmConfig.VMName)" -Level "INFO"

        Write-Host ""
        $connectNow = Read-Host "Open VM console now? (Y/n)"
        if ($connectNow -eq "" -or $connectNow -imatch "^y") {
          Start-Process "vmconnect" -ArgumentList "localhost","`"$($vmConfig.VMName)`""
        }
      }
    }
  }

  Complete-Log -Success $success
}

# Run
Main
