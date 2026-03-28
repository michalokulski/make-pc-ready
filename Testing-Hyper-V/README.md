
# Testing-Hyper-V — Automated Test VM Creator

Creates a fresh Windows VM in Hyper-V with fully unattended installation. Designed for quick, repeatable testing environments — spin up a clean Windows VM in one command.

## Contents

| File | Purpose |
|---|---|
| `MakeTestVM.ps1` | Main script — downloads ISO, configures VM, launches installation |
| `autounattend.xml` | Unattended answer file — automates Windows setup (zero user interaction) |
| `unattend.iso` | ISO-wrapped answer file attached as a second DVD drive to the VM |

## Prerequisites

- **Windows 10/11** with Hyper-V enabled (`MakePCReady.ps1` can enable it)
- **PowerShell 5.1+** running as **Administrator**
- **Internet connection** (for ISO download options)
- `unattend.iso` in the same directory as the script (see [Unattend ISO](#unattend-iso) below)

## Quick Start

### Interactive Mode

```powershell
# Guided wizard — prompts for ISO source, VM config, network switch
.\MakeTestVM.ps1
```

The wizard walks through:
1. **ISO source** — download from Microsoft (FIDO), build from UUP dump, or pick a local `.iso`
2. **VM settings** — name, memory, CPU cores, disk size, network switch
3. **Summary + confirmation** — review and approve before creation
4. **Start + connect** — optionally boot the VM and open the console

### Non-Interactive Mode

```powershell
# Fully automated — no prompts
.\MakeTestVM.ps1 -NonInteractive -ISOPath "C:\ISOs\Windows11.iso" -VMName "TestVM-01" -StartVM -OpenConsole
```

### Semi-Interactive Mode

```powershell
# Skip the interactive menu by providing VM name + ISO — still shows confirmation
.\MakeTestVM.ps1 -VMName "QuickTest" -ISOPath "D:\Win11.iso" -SwitchName "Default Switch"
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-VMName` | string | Auto-generated (`TestVM-yyyyMMdd-HHmmss`) | Name for the new VM |
| `-ISOPath` | string | *(interactive)* | Path to a Windows installation ISO |
| `-SwitchName` | string | *(interactive)* | Hyper-V virtual switch name |
| `-MemoryBytes` | int64 | `4GB` | Startup memory |
| `-CPUCount` | int | `2` | Virtual processor count |
| `-DiskSizeBytes` | int64 | `64GB` | Dynamic VHDX size |
| `-VMPath` | string | Hyper-V default | Base folder for VM storage |
| `-UnattendISOPath` | string | `.\unattend.iso` | Path to the unattend ISO |
| `-LogPath` | string | `~\Desktop\MakeTestVM.log` | Log file location |
| `-NonInteractive` | switch | | Skip all prompts (requires `-ISOPath`) |
| `-StartVM` | switch | | Auto-start VM after creation (non-interactive) |
| `-OpenConsole` | switch | | Open `vmconnect` after start (requires `-StartVM`) |

## ISO Sources

### 1. FIDO (Microsoft Direct Download)

Downloads the latest retail ISO directly from Microsoft using [FIDO.ps1](https://github.com/pbatard/Fido). Supports Windows 10/11, 17 languages, x64/ARM64. Uses BITS transfer with `Invoke-WebRequest` fallback.

### 2. UUP Dump (Build from Update Packages)

Queries the [UUP dump API](https://uupdump.net) for available builds, downloads Windows Update packages, and converts them into a bootable ISO. Slower but supports older/specific builds and editions not available as retail ISOs.

### 3. Local ISO

Browse for an existing `.iso` file on disk.

## VM Configuration

The script creates a **Generation 2** (UEFI) Hyper-V VM with:

| Setting | Value |
|---|---|
| Generation | 2 (UEFI) |
| Secure Boot | Disabled (for broad ISO compatibility) |
| Virtual TPM | Enabled when possible (HgsGuardian) |
| VHDX | Dynamic, attached to SCSI |
| DVD 1 | Windows installation ISO |
| DVD 2 | Unattend ISO |
| Boot order | DVD → Hard drive |
| Checkpoints | Standard (automatic checkpoints disabled) |

## Unattend ISO

The `unattend.iso` contains `autounattend.xml` which fully automates Windows Setup. The included configuration:

### What It Automates

- **Disk partitioning** — GPT layout: 300 MB EFI + 16 MB MSR + remaining NTFS (via diskpart)
- **Edition selection** — Windows Enterprise (generic key `XGVPP-NMH47-7TTHJ-W3FW7-8HV2C`, not activated)
- **Hardware bypass** — TPM, Secure Boot, RAM, storage, and CPU checks bypassed via `LabConfig` registry keys
- **Network bypass** — OOBE network requirement bypassed (`BypassNRO`)
- **Recovery partition** — Disabled and `Winre.wim` removed to save space
- **Password policy** — Set to never expire (`net accounts /maxpwage:UNLIMITED`)

### User Accounts

| Account | Group | Password |
|---|---|---|
| `Admin` | Administrators | *(empty)* |
| `User` | Users | *(empty)* |

Auto-logon is configured for `Admin` (1 logon count). The auto-logon count is reset to 0 on first logon.

### Post-Install Cleanup

The answer file includes self-extracting scripts (via the `<Extensions>` block from [schneegans.de](https://schneegans.de/windows/unattend-generator/)):
- **Specialize pass** — Extracts embedded scripts, runs `Specialize.ps1` (bypass registries, disable recovery, unlock passwords)
- **First logon** — Runs `FirstLogon.ps1` (clears auto-logon, deletes `unattend.xml` from Panther)

### Regenerating the Unattend ISO

1. Go to [schneegans.de/windows/unattend-generator](https://schneegans.de/windows/unattend-generator/)
2. Configure your settings (the URL in the XML comment preserves the current config)
3. Download as **"autounattend.xml wrapped in an ISO image"**
4. Rename to `unattend.iso` and place in this directory

## Validation

Non-interactive and semi-interactive modes validate all parameters before VM creation:

- VM name: not empty, no invalid filename characters, no duplicate VM names
- CPU count: between 1 and host logical processor count
- Memory: at least 1 GB, no more than host physical memory
- Disk: at least 40 GB
- Switch: must exist in Hyper-V if specified
- VM path: created automatically if it doesn't exist

## Logging

All operations are logged to a timestamped file (default: `~\Desktop\MakeTestVM.log`) with:
- Timestamps and severity levels (`SUCCESS`, `INFO`, `WARNING`, `ERROR`)
- Full configuration dump in non-interactive mode
- Duration and final result in the log footer

## Examples

```powershell
# Create a minimal test VM with 2 GB RAM, auto-start it
.\MakeTestVM.ps1 -NonInteractive `
    -ISOPath "C:\ISOs\Win11_24H2_English_x64.iso" `
    -VMName "Minimal-Test" `
    -MemoryBytes 2GB `
    -CPUCount 1 `
    -DiskSizeBytes 40GB `
    -StartVM

# Create a VM on a specific drive and switch
.\MakeTestVM.ps1 -NonInteractive `
    -ISOPath "C:\ISOs\Win11.iso" `
    -VMName "Dev-VM" `
    -VMPath "D:\VMs" `
    -SwitchName "External" `
    -MemoryBytes 8GB `
    -CPUCount 4 `
    -StartVM -OpenConsole

# Connect to a running VM manually
vmconnect localhost "TestVM-01"
```

## Cleanup

The script does not provide a teardown command. To remove a VM:

```powershell
$vmName = "TestVM-01"
Stop-VM -Name $vmName -Force -ErrorAction SilentlyContinue
Remove-VM -Name $vmName -Force
Remove-Item -Path (Get-VMHost).VirtualMachinePath\$vmName -Recurse -Force
Remove-HgsGuardian -Name "UntrustedGuardian_$vmName" -ErrorAction SilentlyContinue
```
