# Testing-QEMU - Automated Windows Test VM Creator (QEMU)

Creates a fresh Windows VM with unattended installation using QEMU.

It is designed to work across both major targets:
- Linux with KVM acceleration
- Windows with WHPX acceleration

If hardware acceleration is not available, it falls back to TCG (software emulation).

## Contents

| File | Purpose |
|---|---|
| `MakeTestVM-QEMU.ps1` | Main cross-platform VM creator script (PowerShell 7+) |
| `MakeTestVM-QEMU.sh` | Linux wrapper that invokes the PowerShell script via `pwsh` |
| `autounattend.xml` | Unattended answer file (source config) |
| `unattend.iso` | ISO-wrapped unattend file attached as a second CD-ROM (auto-created if missing) |

## What This Replaces

This folder provides a QEMU-based equivalent to the Hyper-V flow in `Testing-Hyper-V`.

High-level mapping:
- Hyper-V `Generation 2 VM` -> QEMU `q35` machine type
- Hyper-V VHDX disk -> QEMU `qcow2` disk
- Hyper-V vSwitch (optional) -> QEMU user-mode NAT networking
- Hyper-V unattended DVD attachment -> QEMU second CD-ROM with `unattend.iso`

## Prerequisites

### Linux (KVM target)

- PowerShell 7+ (`pwsh`)
- QEMU packages installed (includes `qemu-system-x86_64` and `qemu-img`)
- OVMF UEFI firmware (`apt install ovmf` or `dnf install edk2-ovmf`)
- KVM enabled in BIOS/UEFI
- User permission for `/dev/kvm` (usually `kvm` group)
- Windows installation ISO (or use script download/build sources in interactive mode)
- An ISO creation tool (`genisoimage`, `mkisofs`, or `xorriso`) if `unattend.iso` needs to be generated

Example package install (Ubuntu/Debian):

```bash
sudo apt update
sudo apt install -y qemu-system-x86 qemu-utils ovmf genisoimage
```

### Windows (WHPX target)

- PowerShell 7+ recommended (Windows PowerShell also works, but PS7 is preferred)
- QEMU for Windows installed and added to PATH (includes OVMF firmware files)
- Windows Hypervisor Platform enabled
- CPU virtualization enabled in BIOS/UEFI
- Windows installation ISO (or use script download/build sources in interactive mode)
- `oscdimg.exe` (from Windows ADK) or `mkisofs` if `unattend.iso` needs to be generated

Enable WHPX feature (Admin PowerShell):

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All
```

Reboot after enabling if required.

## Accelerator Selection Logic

Default mode is `-Acceleration auto`.

Selection order:
1. Linux: use `kvm` when available and `/dev/kvm` exists
2. Windows: use `whpx` when supported by the QEMU build
3. Fallback to `tcg`

You can override explicitly with `-Acceleration kvm`, `-Acceleration whpx`, or `-Acceleration tcg`.

## Quick Start

### Interactive (PowerShell)

```powershell
./MakeTestVM-QEMU.ps1
```

Prompts for:
- ISO source (FIDO, UUP dump, local file)
- Windows ISO path (only when local source is selected)
- VM name / memory / CPU / disk
- acceleration preference
- confirmation and start

### Non-Interactive (PowerShell)

Non-interactive mode currently requires `-ISOPath`.
`-ISOSource` download/build flows are interactive by design.

```powershell
./MakeTestVM-QEMU.ps1 `
  -NonInteractive `
  -ISOPath "C:\ISOs\Win11_24H2_English_x64.iso" `
  -VMName "QemuTest-01" `
  -MemoryGB 6 `
  -CPUCount 4 `
  -DiskSizeGB 80 `
  -Acceleration auto `
  -StartVM
```

## ISO Sources

When `-ISOPath` is not supplied in interactive mode, you can choose:

1. FIDO (`fido`): Direct retail ISO download from Microsoft.
2. UUP dump (`uupdump`): Build ISO from UUP packages (more build flexibility, slower).
3. Local (`local`): Use an ISO already on disk.

You can also preselect a source in interactive mode:

```powershell
./MakeTestVM-QEMU.ps1 -ISOSource fido
./MakeTestVM-QEMU.ps1 -ISOSource uupdump
./MakeTestVM-QEMU.ps1 -ISOSource local
```

Use `-DownloadFolder` to control where downloaded/built ISOs are stored.

## Linux Wrapper Usage

```bash
chmod +x ./MakeTestVM-QEMU.sh
./MakeTestVM-QEMU.sh \
  -NonInteractive \
  -ISOPath "/home/user/iso/Win11.iso" \
  -VMName "QemuLinuxTest" \
  -MemoryGB 4 \
  -CPUCount 2 \
  -DiskSizeGB 64 \
  -StartVM
```

## Headless Mode (CI/SSH)

```powershell
./MakeTestVM-QEMU.ps1 `
  -NonInteractive `
  -ISOPath "D:\ISO\Win11.iso" `
  -VMName "Headless-Test" `
  -StartVM `
  -Headless
```

Headless mode adds:
- `-display none`
- `-serial mon:stdio`

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-VMName` | string | `TestVM-yyyyMMdd-HHmmss` | VM name and VM folder name |
| `-ISOPath` | string | interactive source selection | Path to Windows installation ISO |
| `-ISOSource` | string | `auto` | ISO source when `-ISOPath` is omitted: `auto`, `fido`, `uupdump`, `local` |
| `-DownloadFolder` | string | OS Downloads folder | Target folder for downloaded/built ISOs |
| `-MemoryGB` | int | `4` | RAM size in GB |
| `-CPUCount` | int | `2` | vCPU count |
| `-DiskSizeGB` | int | `64` | qcow2 virtual disk size in GB |
| `-VMPath` | string | `./VMs` under script folder | Base VM storage directory |
| `-UnattendISOPath` | string | `./unattend.iso` | Path to unattend ISO |
| `-QemuSystemPath` | string | auto-detected from PATH | Explicit path to `qemu-system-x86_64` |
| `-QemuImgPath` | string | auto-detected from PATH | Explicit path to `qemu-img` |
| `-Acceleration` | string | `auto` | `auto`, `kvm`, `whpx`, `tcg` |
| `-NonInteractive` | switch | off | Skip prompts (requires `-ISOPath`) |
| `-StartVM` | switch | off | Launch VM after preparing disk/config |
| `-Headless` | switch | off | Run without graphical window |
| `-LogPath` | string | desktop/home log path | Log file path |

## VM Storage Layout

VM files are created at:

- default: `Testing-QEMU/VMs/<VMName>/`
- disk file: `<VMName>.qcow2`

The script reuses an existing qcow2 disk if present.

## Networking

The script uses QEMU user-mode NAT networking by default:

- `-netdev user,id=n1`
- `-device virtio-net-pci,netdev=n1`

This is simple and portable but does not create a bridge on the host.

## Notes About Unattend

The included `autounattend.xml`/`unattend.iso` is intended for English Windows media.

If your ISO language differs, unattended setup may require manual intervention.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| "OVMF UEFI firmware not found" | OVMF not installed or not in expected path | Install OVMF package (see Prerequisites) |
| Installer can't find disk | Disk interface mismatch | Ensure you're using the latest script (uses IDE disk interface) |
| "No ISO creation tool found" | Missing `oscdimg`, `mkisofs`, `genisoimage`, or `xorriso` | Install one of these tools (see Prerequisites) |
| VM window opens but shows SeaBIOS shell | OVMF firmware not loaded | Verify `Find-OVMFFirmware` resolves a valid path; check log for firmware line |
| Unattended setup stalls asking for language | ISO language doesn't match `autounattend.xml` | Use an en-US ISO, or customize `autounattend.xml` for your language |
| QEMU exits immediately with "cannot set up KVM" | KVM not enabled or no permissions | Run `ls -la /dev/kvm`, ensure user is in `kvm` group, or use `-Acceleration tcg` |
| WHPX error on Windows | Hypervisor Platform feature not enabled | Run `Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All` and reboot |

## ISO download/build options not available in non-interactive mode

- Use `-ISOPath` with `-NonInteractive`
- Or run interactive mode and select `fido` or `uupdump`

## "kvm" not used on Linux

- Verify `/dev/kvm` exists
- Verify your user is in the `kvm` group
- Confirm virtualization is enabled in BIOS/UEFI

## "whpx" not used on Windows

- Confirm the Windows Hypervisor Platform feature is enabled
- Reboot after enabling
- Ensure your QEMU build includes WHPX support

## QEMU binaries not found

Pass explicit paths:

```powershell
./MakeTestVM-QEMU.ps1 `
  -NonInteractive `
  -ISOPath "C:\ISOs\Win11.iso" `
  -QemuSystemPath "C:\Program Files\qemu\qemu-system-x86_64.exe" `
  -QemuImgPath "C:\Program Files\qemu\qemu-img.exe"
```

## Logging

The script writes structured logs with level tags:
- `SUCCESS`
- `INFO`
- `WARNING`
- `ERROR`

Default log locations:
- Windows: `%USERPROFILE%\Desktop\MakeTestVM-QEMU.log`
- Linux: `$HOME/MakeTestVM-QEMU.log`

## Example Workflows

Create disk only:

```powershell
./MakeTestVM-QEMU.ps1 `
  -NonInteractive `
  -ISOPath "C:\ISOs\Win11.iso" `
  -VMName "PrepOnly"
```

Interactive run with preselected FIDO source:

```powershell
./MakeTestVM-QEMU.ps1 -ISOSource fido
```

Create and boot with explicit WHPX:

```powershell
./MakeTestVM-QEMU.ps1 `
  -NonInteractive `
  -ISOPath "C:\ISOs\Win11.iso" `
  -VMName "WHPX-VM" `
  -Acceleration whpx `
  -StartVM
```

Create and boot with explicit KVM:

```bash
./MakeTestVM-QEMU.sh \
  -NonInteractive \
  -ISOPath "/home/user/iso/Win11.iso" \
  -VMName "KVM-VM" \
  -Acceleration kvm \
  -StartVM
```
