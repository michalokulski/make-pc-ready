param(
  [string]$VMName,
  [string]$ISOPath,
  [ValidateSet("auto","fido","uupdump","local")]
  [string]$ISOSource = "auto",
  [string]$DownloadFolder,
  [int]$MemoryGB = 4,
  [int]$CPUCount = 2,
  [int]$DiskSizeGB = 64,
  [string]$VMPath,
  [string]$UnattendISOPath,
  [string]$QemuSystemPath,
  [string]$QemuImgPath,
  [ValidateSet("auto","kvm","whpx","tcg")]
  [string]$Acceleration = "auto",
  [switch]$NonInteractive,
  [switch]$StartVM,
  [switch]$Headless,
  [string]$LogPath
)

# ============================================================================
# QEMU Test VM Creator - Linux (KVM) and Windows (WHPX)
# ============================================================================

$script:scriptRoot = $PSScriptRoot
$script:selectedAcceleration = $null
$script:qemuSystem = $null
$script:qemuImg = $null
$script:ovmfCodePath = $null
$script:isWindowsPlatform = ($env:OS -eq "Windows_NT")
$script:isLinuxPlatform = -not $script:isWindowsPlatform

if ([string]::IsNullOrWhiteSpace($LogPath)) {
  if ($script:isWindowsPlatform) {
    $desktopPath = Join-Path -Path $env:USERPROFILE -ChildPath "Desktop"
    $LogPath = if (Test-Path $desktopPath) { Join-Path -Path $desktopPath -ChildPath "MakeTestVM-QEMU.log" } else { Join-Path -Path $env:TEMP -ChildPath "MakeTestVM-QEMU.log" }
  }
  else {
    $baseLogDir = if ($env:HOME) { $env:HOME } else { (Get-Location).Path }
    $LogPath = Join-Path -Path $baseLogDir -ChildPath "MakeTestVM-QEMU.log"
  }
}

# Import shared VM module (must be imported BEFORE initializing module state)
Import-Module -Force (Join-Path -Path $PSScriptRoot -ChildPath "..\lib\VMCommon.psm1")

# Hand the log path/start time to the module — Import-Module scopes are isolated,
# so assigning $script:logFile here would be invisible to the module's functions.
Initialize-VMCommonState -LogPath $LogPath -StartTime (Get-Date)

function Resolve-CommandPath {
  param(
    [Parameter(Mandatory)]
    [string[]]$Candidates,
    [string]$ExplicitPath
  )

  if ($ExplicitPath) {
    if (Test-Path -Path $ExplicitPath) {
      return (Resolve-Path -Path $ExplicitPath).Path
    }

    throw "Provided path not found: $ExplicitPath"
  }

  foreach ($candidate in $Candidates) {
    $cmd = Get-Command -Name $candidate -ErrorAction SilentlyContinue
    if ($cmd) {
      return $cmd.Source
    }
  }

  return $null
}

function Test-Prerequisites {
  Write-Log "Checking prerequisites..." -Level "INFO"

  if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Log "PowerShell 7+ is recommended for cross-platform usage." -Level "WARNING"
  }

  $systemCandidates = if ($script:isWindowsPlatform) {
    @("qemu-system-x86_64.exe","qemu-system-x86_64")
  }
  else {
    @("qemu-system-x86_64")
  }

  $imgCandidates = if ($script:isWindowsPlatform) {
    @("qemu-img.exe","qemu-img")
  }
  else {
    @("qemu-img")
  }

  try {
    $script:qemuSystem = Resolve-CommandPath -Candidates $systemCandidates -ExplicitPath $QemuSystemPath
    $script:qemuImg = Resolve-CommandPath -Candidates $imgCandidates -ExplicitPath $QemuImgPath
  }
  catch {
    Write-Log $_.Exception.Message -Level "ERROR"
    return $false
  }

  if (-not $script:qemuSystem) {
    Write-Log "qemu-system-x86_64 was not found in PATH. Install QEMU or pass -QemuSystemPath." -Level "ERROR"
    return $false
  }

  if (-not $script:qemuImg) {
    Write-Log "qemu-img was not found in PATH. Install QEMU tools or pass -QemuImgPath." -Level "ERROR"
    return $false
  }

  if ($script:isLinuxPlatform) {
    if (-not (Test-Path -Path "/dev/kvm")) {
      Write-Log "KVM device (/dev/kvm) not found. Falling back to TCG unless -Acceleration tcg was already selected." -Level "WARNING"
    }
  }

  $script:ovmfCodePath = Find-OVMFFirmware
  if (-not $script:ovmfCodePath) {
    Write-Log "OVMF UEFI firmware not found. Windows UEFI boot requires OVMF (OVMF_CODE.fd / OVMF_CODE_4M.fd)." -Level "ERROR"
    if ($script:isWindowsPlatform) {
      Write-Log "Install OVMF via the QEMU installer (ensure the firmware files are included) or download from https://www.kraxel.org/repos/" -Level "ERROR"
    } else {
      Write-Log "Install OVMF: apt install ovmf (Debian/Ubuntu) or dnf install edk2-ovmf (Fedora/RHEL)" -Level "ERROR"
    }
    return $false
  }
  Write-Log "OVMF firmware: $script:ovmfCodePath" -Level "INFO"

  Write-Log "Prerequisites verified" -Level "SUCCESS"
  Write-Log "QEMU system binary: $script:qemuSystem" -Level "INFO"
  Write-Log "QEMU img binary: $script:qemuImg" -Level "INFO"
  return $true
}

function Find-OVMFFirmware {
  $candidates = @()

  if ($script:isWindowsPlatform) {
    $qemuDir = Split-Path -Path $script:qemuSystem -Parent
    $shareDir = Join-Path -Path $qemuDir -ChildPath "share"
    $candidates += @(
      (Join-Path -Path $shareDir -ChildPath "OVMF_CODE_4M.fd"),
      (Join-Path -Path $shareDir -ChildPath "OVMF_CODE.fd"),
      (Join-Path -Path $shareDir -ChildPath "edk2-x86_64-code.fd"),
      (Join-Path -Path $qemuDir -ChildPath "OVMF_CODE_4M.fd"),
      (Join-Path -Path $qemuDir -ChildPath "OVMF_CODE.fd")
    )
  }
  else {
    $candidates += @(
      "/usr/share/OVMF/OVMF_CODE_4M.fd",
      "/usr/share/OVMF/OVMF_CODE.fd",
      "/usr/share/edk2/x64/OVMF_CODE.4m.fd",
      "/usr/share/edk2/x64/OVMF_CODE.fd",
      "/usr/share/edk2-ovmf/x64/OVMF_CODE.fd",
      "/usr/share/qemu/OVMF_CODE_4M.fd",
      "/usr/share/qemu/OVMF_CODE.fd"
    )
  }

  foreach ($path in $candidates) {
    if (Test-Path -Path $path) {
      return (Resolve-Path -Path $path).Path
    }
  }

  return $null
}

function Get-QemuSupportedAccelerators {
  $supports = @{}

  try {
    $output = @(& $script:qemuSystem -accel help 2>&1)
    $joined = ($output -join "`n").ToLowerInvariant()

    $supports["kvm"] = $joined -match "\bkvm\b"
    $supports["whpx"] = $joined -match "\bwhpx\b"
    $supports["tcg"] = $joined -match "\btcg\b"

    return $supports
  }
  catch {
    Write-Log "Could not query QEMU accelerators; assuming tcg support." -Level "WARNING"
    return @{ kvm = $false; whpx = $false; tcg = $true }
  }
}

function Resolve-Acceleration {
  param(
    [Parameter(Mandatory)]
    [string]$RequestedAcceleration,
    [Parameter(Mandatory)]
    [hashtable]$Supported
  )

  if ($RequestedAcceleration -ne "auto") {
    if (-not $Supported.ContainsKey($RequestedAcceleration) -or -not $Supported[$RequestedAcceleration]) {
      throw "Requested accelerator '$RequestedAcceleration' is not available in this QEMU build."
    }

    if ($RequestedAcceleration -eq "kvm" -and $script:isLinuxPlatform -and -not (Test-Path -Path "/dev/kvm")) {
      throw "Requested accelerator 'kvm' but /dev/kvm is not available."
    }

    return $RequestedAcceleration
  }

  if ($script:isLinuxPlatform -and $Supported["kvm"] -and (Test-Path -Path "/dev/kvm")) {
    return "kvm"
  }

  if ($script:isWindowsPlatform -and $Supported["whpx"]) {
    return "whpx"
  }

  if ($Supported["tcg"]) {
    return "tcg"
  }

  throw "Could not determine a usable accelerator (kvm/whpx/tcg)."
}

function Test-NonInteractiveConfig {
  param(
    [Parameter(Mandatory)]
    [hashtable]$Config,
    [string]$BasePath
  )

  $errors = @()

  if ([string]::IsNullOrWhiteSpace($Config.VMName)) {
    $errors += "VM name cannot be empty in non-interactive mode."
  }
  else {
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    if ($Config.VMName.IndexOfAny($invalidChars) -ge 0) {
      $errors += "VM name '$($Config.VMName)' contains invalid file name characters."
    }
  }

  $maxCPU = [Environment]::ProcessorCount
  if ($Config.CPUs -lt 1 -or $Config.CPUs -gt $maxCPU) {
    $errors += "CPUCount must be between 1 and $maxCPU. Received: $($Config.CPUs)."
  }

  if ($Config.Memory -lt 1GB) {
    $errors += "MemoryGB must be at least 1. Received: $([math]::Round($Config.Memory / 1GB, 2)) GB."
  }

  if ($Config.DiskSize -lt 40GB) {
    $errors += "DiskSizeGB must be at least 40. Received: $([math]::Round($Config.DiskSize / 1GB, 2)) GB."
  }

  if ($BasePath -and -not (Test-Path -Path $BasePath)) {
    try {
      New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
      Write-Log "Created VM base path: $BasePath" -Level "INFO"
    }
    catch {
      $errors += "VMPath '$BasePath' does not exist and could not be created: $($_.Exception.Message)"
    }
  }

  if ($errors.Count -gt 0) {
    Write-Log "Non-interactive parameter validation failed:" -Level "ERROR"
    foreach ($err in $errors) {
      Write-Log "  - $err" -Level "ERROR"
    }

    return $false
  }

  Write-Log "Non-interactive parameter validation passed." -Level "SUCCESS"
  return $true
}

function Get-DefaultDownloadFolder {
  param([string]$ConfiguredFolder)

  $folder = $ConfiguredFolder
  if ([string]::IsNullOrWhiteSpace($folder)) {
    if ($script:isWindowsPlatform) {
      $folder = Join-Path -Path $env:USERPROFILE -ChildPath "Downloads"
    }
    else {
      $homePath = if ($env:HOME) { $env:HOME } else { (Get-Location).Path }
      $folder = Join-Path -Path $homePath -ChildPath "Downloads"
    }
  }

  if (-not (Test-Path -Path $folder)) {
    Write-Log "Creating download folder: $folder" -Level "INFO"
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
  }

  return (Resolve-Path -Path $folder).Path
}

# Invoke-FileDownload, Get-WindowsISOViaFido and Get-WindowsISOViaUUPDump
# now live in lib\VMCommon.psm1 (shared with Testing-Hyper-V).

function Resolve-WindowsISOPath {
  param(
    [string]$ProvidedISOPath,
    [bool]$IsNonInteractive,
    [string]$ConfiguredSource,
    [string]$ConfiguredDownloadFolder
  )

  if (-not [string]::IsNullOrWhiteSpace($ProvidedISOPath)) {
    if (-not (Test-Path -Path $ProvidedISOPath)) {
      throw "Windows ISO not found: $ProvidedISOPath"
    }

    return (Resolve-Path -Path $ProvidedISOPath).Path
  }

  if ($IsNonInteractive) {
    throw "Non-interactive mode requires -ISOPath. Download/build sources are interactive only."
  }

  $resolvedSource = if ($ConfiguredSource -eq "auto") { Show-ISOSourceMenu } else { $ConfiguredSource }
  $resolvedDownloadFolder = Get-DefaultDownloadFolder -ConfiguredFolder $ConfiguredDownloadFolder

  # Normalize source to int (shared Show-ISOSourceMenu returns int; -ISOSource param may be string)
  $sourceMap = @{ "fido" = 1; "uupdump" = 2; "local" = 3 }
  $sourceInt = if ($resolvedSource -is [int]) { $resolvedSource } else { $sourceMap[$resolvedSource] }
  if (-not $sourceInt) { throw "Unsupported ISOSource '$resolvedSource'." }

  switch ($sourceInt) {
    1 {
      return Get-WindowsISOViaFido -TargetDownloadFolder $resolvedDownloadFolder
    }
    2 {
      return Get-WindowsISOViaUUPDump -TargetDownloadFolder $resolvedDownloadFolder
    }
    3 {
      return Resolve-PathFromPrompt -Prompt "Path to Windows ISO" -RequiredSuffix ".iso"
    }
    default {
      throw "Unsupported ISOSource '$resolvedSource'."
    }
  }
}

function Show-VMConfigMenu {
  param([string]$DefaultVMName)

  Write-Host ""
  Write-Host "============================================" -ForegroundColor Cyan
  Write-Host "  QEMU VM Configuration" -ForegroundColor Cyan
  Write-Host "============================================" -ForegroundColor Cyan
  Write-Host ""

  $defaultName = if ($DefaultVMName) { $DefaultVMName } else { "TestVM-$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
  $nameInput = Read-Host "VM Name [$defaultName]"
  $vmName = if ([string]::IsNullOrWhiteSpace($nameInput)) { $defaultName } else { $nameInput }

  $memGB = Read-PositiveInteger -Prompt "Memory in GB [4]" -DefaultValue 4
  $maxCPU = [Environment]::ProcessorCount
  $defaultCPU = [math]::Min(2,$maxCPU)
  $cpus = Read-ValidatedInteger -Prompt "CPU cores (1-$maxCPU) [$defaultCPU]" -Min 1 -Max $maxCPU -DefaultValue $defaultCPU

  $diskGB = Read-PositiveInteger -Prompt "Disk size in GB (min 40) [64]" -DefaultValue 64
  if ($diskGB -lt 40) {
    Write-Host "Minimum disk size is 40 GB. Using 40 GB." -ForegroundColor Yellow
    $diskGB = 40
  }

  $accelOptions = @("auto","kvm","whpx","tcg")
  Write-Host ""
  Write-Host "Acceleration options:" -ForegroundColor Gray
  for ($i = 0; $i -lt $accelOptions.Count; $i++) {
    Write-Host "  [$($i + 1)] $($accelOptions[$i])" -ForegroundColor White
  }
  $accelChoice = Read-ValidatedInteger -Prompt "Acceleration [1]" -Min 1 -Max $accelOptions.Count -DefaultValue 1
  $accel = $accelOptions[$accelChoice - 1]

  return @{
    VMName = $vmName
    Memory = [int64]$memGB * 1GB
    CPUs = $cpus
    DiskSize = [int64]$diskGB * 1GB
    Acceleration = $accel
  }
}

function Resolve-PathFromPrompt {
  param(
    [Parameter(Mandatory)]
    [string]$Prompt,
    [string]$DefaultValue,
    [string]$RequiredSuffix
  )

  do {
    $inputPath = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
      $inputPath = $DefaultValue
    }

    if (-not [string]::IsNullOrWhiteSpace($RequiredSuffix) -and -not $inputPath.EndsWith($RequiredSuffix,[System.StringComparison]::OrdinalIgnoreCase)) {
      Write-Host "Path must end with '$RequiredSuffix'." -ForegroundColor Yellow
      $isValid = $false
      continue
    }

    if (-not (Test-Path -Path $inputPath)) {
      Write-Host "Path not found: $inputPath" -ForegroundColor Yellow
      $isValid = $false
      continue
    }

    $isValid = $true
  } while (-not $isValid)

  return (Resolve-Path -Path $inputPath).Path
}

function Initialize-VMStorage {
  param(
    [Parameter(Mandatory)]
    [string]$BasePath,
    [Parameter(Mandatory)]
    [string]$VMName,
    [Parameter(Mandatory)]
    [int64]$DiskSize
  )

  if (-not (Test-Path -Path $BasePath)) {
    New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
  }

  $vmFolder = Join-Path -Path $BasePath -ChildPath $VMName
  if (-not (Test-Path -Path $vmFolder)) {
    New-Item -ItemType Directory -Path $vmFolder -Force | Out-Null
  }

  $diskPath = Join-Path -Path $vmFolder -ChildPath "$VMName.qcow2"

  if (-not (Test-Path -Path $diskPath)) {
    Write-Log "Creating qcow2 disk: $diskPath" -Level "INFO"
    $sizeGB = [math]::Round($DiskSize / 1GB,0)
    & $script:qemuImg create -f qcow2 $diskPath "${sizeGB}G" | Out-Null

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -Path $diskPath)) {
      throw "Failed to create qcow2 disk at $diskPath"
    }

    Write-Log "Disk created successfully" -Level "SUCCESS"
  }
  else {
    Write-Log "Disk already exists, reusing: $diskPath" -Level "INFO"
  }

  return $diskPath
}

function Get-QemuLaunchParameters {
  param(
    [Parameter(Mandatory)]
    [string]$VMName,
    [Parameter(Mandatory)]
    [string]$DiskPath,
    [Parameter(Mandatory)]
    [string]$WindowsISOPath,
    [Parameter(Mandatory)]
    [string]$AnswerISOPath,
    [Parameter(Mandatory)]
    [int64]$MemoryBytes,
    [Parameter(Mandatory)]
    [int]$CPUs,
    [Parameter(Mandatory)]
    [string]$ResolvedAcceleration,
    [switch]$UseHeadless
  )

  $memoryMB = [int][math]::Round($MemoryBytes / 1MB)
  $cpuType = if ($ResolvedAcceleration -in @("kvm","whpx")) { "host" } else { "qemu64" }

  $launchParameters = @(
    "-name",$VMName,
    "-machine","q35",
    "-accel",$ResolvedAcceleration,
    "-cpu",$cpuType,
    "-smp","$CPUs",
    "-m","$memoryMB",
    "-drive","if=pflash,format=raw,readonly=on,file=$($script:ovmfCodePath)",
    "-drive","if=ide,format=qcow2,file=$DiskPath",
    "-drive","if=ide,media=cdrom,index=0,file=$WindowsISOPath",
    "-drive","if=ide,media=cdrom,index=1,file=$AnswerISOPath",
    "-boot","order=d",
    "-netdev","user,id=n1",
    "-device","virtio-net-pci,netdev=n1"
  )

  if ($UseHeadless) {
    $launchParameters += @("-display","none","-serial","mon:stdio")
  }

  return ,$launchParameters
}

function Show-Summary {
  param(
    [Parameter(Mandatory)]
    [hashtable]$Config,
    [Parameter(Mandatory)]
    [string]$ISOPath,
    [Parameter(Mandatory)]
    [string]$UnattendPath,
    [Parameter(Mandatory)]
    [string]$BasePath,
    [Parameter(Mandatory)]
    [string]$ResolvedAcceleration
  )

  Write-Host ""
  Write-Host "============================================" -ForegroundColor Cyan
  Write-Host "  QEMU VM Creation Summary" -ForegroundColor Cyan
  Write-Host "============================================" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "  VM Name:      $($Config.VMName)" -ForegroundColor White
  Write-Host "  Memory:       $([math]::Round($Config.Memory / 1GB, 1)) GB" -ForegroundColor White
  Write-Host "  CPUs:         $($Config.CPUs)" -ForegroundColor White
  Write-Host "  Disk:         $([math]::Round($Config.DiskSize / 1GB, 0)) GB (qcow2)" -ForegroundColor White
  Write-Host "  VM Path:      $BasePath" -ForegroundColor White
  Write-Host "  Accelerator:  $ResolvedAcceleration" -ForegroundColor White
  Write-Host "  Headless:     $([bool]$Headless)" -ForegroundColor White
  Write-Host ""
  Write-Host "  ISO:          $ISOPath" -ForegroundColor White
  Write-Host "  Unattend ISO: $UnattendPath" -ForegroundColor White
  Write-Host ""

  $selectedISOLanguage = Get-SelectedISOLanguage
  if ($selectedISOLanguage) {
    $isEnglishIso = $selectedISOLanguage -in @("English","English International") -or $selectedISOLanguage -match '^en-'
    if (-not $isEnglishIso) {
      Write-Host "  WARNING: ISO language '$($selectedISOLanguage)' differs from" -ForegroundColor Yellow
      Write-Host "  the bundled autounattend.xml (en-US). Setup may require manual input." -ForegroundColor Yellow
      Write-Host ""
    }
  }
  else {
    Write-Host "  NOTE: ISO language unknown. Bundled autounattend.xml targets en-US." -ForegroundColor Yellow
    Write-Host ""
  }

  $confirm = Read-Host "Proceed with VM creation/start? (Y/n)"
  return ($confirm -eq "" -or $confirm -imatch "^y")
}

function New-UnattendISO {
  param(
    [Parameter(Mandatory)]
    [string]$XmlSourcePath,
    [Parameter(Mandatory)]
    [string]$OutputISOPath
  )

  $stagingDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "unattend_iso_staging"
  if (Test-Path -Path $stagingDir) {
    Remove-Item -Path $stagingDir -Recurse -Force
  }
  New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

  Copy-Item -Path $XmlSourcePath -Destination (Join-Path -Path $stagingDir -ChildPath "autounattend.xml") -Force

  $isoTool = $null
  if ($script:isWindowsPlatform) {
    $oscdimg = Get-Command -Name "oscdimg.exe" -ErrorAction SilentlyContinue
    if ($oscdimg) {
      $isoTool = "oscdimg"
    }
    else {
      $qemuDir = Split-Path -Path $script:qemuSystem -Parent
      $mkisofs = Get-Command -Name "mkisofs.exe" -ErrorAction SilentlyContinue
      if (-not $mkisofs) {
        $mkisofsCandidate = Join-Path -Path $qemuDir -ChildPath "mkisofs.exe"
        if (Test-Path -Path $mkisofsCandidate) {
          $mkisofs = Get-Item -Path $mkisofsCandidate
        }
      }
      if ($mkisofs) {
        $isoTool = "mkisofs"
      }
    }
  }
  else {
    foreach ($tool in @("genisoimage","mkisofs","xorriso")) {
      if (Get-Command -Name $tool -ErrorAction SilentlyContinue) {
        $isoTool = $tool
        break
      }
    }
  }

  if (-not $isoTool) {
    throw "No ISO creation tool found. Install oscdimg (Windows ADK), mkisofs, genisoimage, or xorriso."
  }

  Write-Log "Creating unattend.iso using $isoTool..." -Level "INFO"

  switch ($isoTool) {
    "oscdimg" {
      & oscdimg.exe -o -lCIDATA $stagingDir $OutputISOPath
    }
    "xorriso" {
      & xorriso -As mkisofs -o $OutputISOPath -V "CIDATA" -J -r $stagingDir
    }
    default {
      & $isoTool -o $OutputISOPath -V "CIDATA" -J -r $stagingDir
    }
  }

  Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue

  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -Path $OutputISOPath)) {
    throw "$isoTool failed to create unattend.iso (exit code: $LASTEXITCODE)."
  }

  Write-Log "unattend.iso created successfully: $OutputISOPath" -Level "SUCCESS"
}

function Main {
  Initialize-Log -Title "QEMU Test VM Creator Log"

  if (-not (Test-Prerequisites)) {
    Complete-Log -Success $false
    exit 1
  }

  $baseVMPath = if ($VMPath) {
    $VMPath
  }
  else {
    Join-Path -Path $script:scriptRoot -ChildPath "VMs"
  }

  if (-not (Test-Path -Path $baseVMPath)) {
    New-Item -ItemType Directory -Path $baseVMPath -Force | Out-Null
  }

  $isNonInteractive = $NonInteractive.IsPresent
  if ($isNonInteractive) {
    Write-Log "Running in non-interactive mode." -Level "INFO"
  }

  $resolvedISOPath = $null
  try {
    $resolvedISOPath = Resolve-WindowsISOPath `
       -ProvidedISOPath $ISOPath `
       -IsNonInteractive $isNonInteractive `
       -ConfiguredSource $ISOSource `
       -ConfiguredDownloadFolder $DownloadFolder
  }
  catch {
    Write-Log $_.Exception.Message -Level "ERROR"
    Complete-Log -Success $false
    exit 1
  }

  if ([string]::IsNullOrWhiteSpace($resolvedISOPath) -or -not (Test-Path -Path $resolvedISOPath)) {
    Write-Log "No valid Windows ISO selected or downloaded. Aborting." -Level "ERROR"
    Complete-Log -Success $false
    exit 1
  }

  $resolvedISOPath = (Resolve-Path -Path $resolvedISOPath).Path
  Write-Log "Windows ISO: $resolvedISOPath" -Level "SUCCESS"

  if (-not (Get-SelectedISOLanguage)) {
    Write-Log "ISO language unknown. Bundled autounattend.xml is configured for en-US." -Level "WARNING"
  }

  $resolvedUnattend = if ($UnattendISOPath) { $UnattendISOPath } else { Join-Path -Path $script:scriptRoot -ChildPath "unattend.iso" }
  if (-not (Test-Path -Path $resolvedUnattend)) {
    Write-Log "Unattend ISO not found at: $resolvedUnattend" -Level "WARNING"
    Write-Log "Attempting to create unattend.iso from autounattend.xml..." -Level "INFO"
    $xmlSource = Join-Path -Path $script:scriptRoot -ChildPath "autounattend.xml"
    if (-not (Test-Path -Path $xmlSource)) {
      Write-Log "autounattend.xml not found in script folder. Cannot create unattend.iso." -Level "ERROR"
      Complete-Log -Success $false
      exit 1
    }
    try {
      New-UnattendISO -XmlSourcePath $xmlSource -OutputISOPath $resolvedUnattend
    }
    catch {
      Write-Log "Failed to create unattend.iso: $($_.Exception.Message)" -Level "ERROR"
      Complete-Log -Success $false
      exit 1
    }
  }
  $resolvedUnattend = (Resolve-Path -Path $resolvedUnattend).Path

  $vmConfig = $null
  if ($isNonInteractive -or ($VMName -and $ISOPath)) {
    $resolvedName = if ([string]::IsNullOrWhiteSpace($VMName)) { "TestVM-$(Get-Date -Format 'yyyyMMdd-HHmmss')" } else { $VMName }
    $vmConfig = @{
      VMName = $resolvedName
      Memory = [int64]$MemoryGB * 1GB
      CPUs = $CPUCount
      DiskSize = [int64]$DiskSizeGB * 1GB
      Acceleration = $Acceleration
    }

    if (-not (Test-NonInteractiveConfig -Config $vmConfig -BasePath $baseVMPath)) {
      Complete-Log -Success $false
      exit 1
    }
  }
  else {
    $vmConfig = Show-VMConfigMenu -DefaultVMName $VMName
  }

  $supported = Get-QemuSupportedAccelerators

  try {
    $script:selectedAcceleration = Resolve-Acceleration -RequestedAcceleration $vmConfig.Acceleration -Supported $supported
    Write-Log "Selected accelerator: $script:selectedAcceleration" -Level "SUCCESS"
  }
  catch {
    Write-Log $_.Exception.Message -Level "ERROR"
    Complete-Log -Success $false
    exit 1
  }

  if ($isNonInteractive) {
    Write-Log "Non-interactive config: VMName='$($vmConfig.VMName)', ISOPath='$resolvedISOPath', ISOSource='$ISOSource', UnattendISOPath='$resolvedUnattend', MemoryGB=$([math]::Round($vmConfig.Memory / 1GB, 2)), CPUs=$($vmConfig.CPUs), DiskGB=$([math]::Round($vmConfig.DiskSize / 1GB, 2)), Accel='$($vmConfig.Acceleration)', VMPath='$baseVMPath'" -Level "INFO"
  }

  if (-not $isNonInteractive) {
    if (-not (Show-Summary -Config $vmConfig -ISOPath $resolvedISOPath -UnattendPath $resolvedUnattend -BasePath $baseVMPath -ResolvedAcceleration $script:selectedAcceleration)) {
      Write-Log "User cancelled operation." -Level "WARNING"
      Complete-Log -Success $false
      exit 0
    }
  }

  $diskPath = $null
  try {
    $diskPath = Initialize-VMStorage -BasePath $baseVMPath -VMName $vmConfig.VMName -DiskSize $vmConfig.DiskSize
  }
  catch {
    Write-Log $_.Exception.Message -Level "ERROR"
    Complete-Log -Success $false
    exit 1
  }

  $shouldStart = $false
  if ($isNonInteractive) {
    $shouldStart = $StartVM.IsPresent
    if (-not $shouldStart) {
      Write-Log "Non-interactive mode: VM disk prepared but not started (use -StartVM)." -Level "INFO"
    }
  }
  else {
    $startNow = Read-Host "Start the VM now? (Y/n)"
    $shouldStart = ($startNow -eq "" -or $startNow -imatch "^y")
  }

  if ($shouldStart) {
    $launchArgs = Get-QemuLaunchParameters `
       -VMName $vmConfig.VMName `
       -DiskPath $diskPath `
       -WindowsISOPath $resolvedISOPath `
       -AnswerISOPath $resolvedUnattend `
       -MemoryBytes $vmConfig.Memory `
       -CPUs $vmConfig.CPUs `
       -ResolvedAcceleration $script:selectedAcceleration `
       -UseHeadless:$Headless

    Write-Log "Launching VM with QEMU..." -Level "INFO"
    Write-Log "Command: $script:qemuSystem $($launchArgs -join ' ')" -Level "INFO" -NoConsole

    try {
      & $script:qemuSystem @launchArgs

      if ($LASTEXITCODE -ne 0) {
        Write-Log "QEMU exited with code $LASTEXITCODE" -Level "ERROR"
        Complete-Log -Success $false
        exit 1
      }

      Write-Log "QEMU exited normally." -Level "SUCCESS"
    }
    catch {
      Write-Log "Failed to launch QEMU VM: $($_.Exception.Message)" -Level "ERROR"
      Complete-Log -Success $false
      exit 1
    }
  }

  Write-Log "VM assets are ready under: $(Join-Path -Path $baseVMPath -ChildPath $vmConfig.VMName)" -Level "SUCCESS"
  Complete-Log -Success $true
}

Main
