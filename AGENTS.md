# AGENTS.md — MakePCReady Repository Guide for LLM Agents

## Overview

This repo automates Windows PC setup after a fresh install. Two main capabilities:

1. **Bulk app installation** via Winget (`MakePCReady.ps1`, `MakePCReadyAlternativeGUI.ps1`)
2. **Test VM creation** for Windows testing (`Testing-Hyper-V/`, `Testing-QEMU/`)

All scripts are **PowerShell 5.1+** (Windows PowerShell compatible). QEMU script also supports PowerShell 7+ on Linux.

---

## File Map

```
MakePCReady.ps1                  # Console TUI app installer (collapsible tree)
MakePCReadyAlternativeGUI.ps1    # WPF GUI app installer (same catalog, different UI)
README.md                        # User-facing docs
AGENTS.md                        # This file — LLM agent guide
.editorconfig                    # Consistent formatting rules
.gitignore                       # Ignore logs, ISOs, VM storage
PSScriptAnalyzerSettings.psd1    # Lint rule config (used by CI + local runs)

lib/
  PCSetup.Common.psm1            # Shared module: catalog, winget, install, actions, Invoke-PCSetup
  VMCommon.psm1                  # Shared module: logging, validation, ISO menu, ISO download/build, Complete-Log

.github/workflows/
  lint.yml                       # CI: PSScriptAnalyzer + PowerShell-Beautifier on push/PR

Testing-Hyper-V/
  MakeTestVM.ps1                 # Hyper-V VM creator (Gen2, VHDX, unattended)
  autounattend.xml               # Windows unattended answer file (en-US, IDE/SCSI check)
  unattend.iso                   # ISO-wrapped autounattend.xml (auto-generated if missing)
  README.md                      # Hyper-V usage docs

Testing-QEMU/
  MakeTestVM-QEMU.ps1            # QEMU VM creator (cross-platform, qcow2)
  MakeTestVM-QEMU.sh             # Linux bash wrapper → calls pwsh
  autounattend.xml               # Windows unattended answer file (en-US, no disk check)
  unattend.iso                   # ISO-wrapped autounattend.xml (auto-generated if missing)
  README.md                      # QEMU usage docs
```

---

## Architecture & Shared Code

### Architecture (as of 2026-08-22)

Shared code lives in two modules under `lib/`:

- **`lib/PCSetup.Common.psm1`** — All shared logic for app installers: `Initialize-PCSetupState`, `$appCatalog`, `$vcRedistPackages`, `$vcRedistAioPackage`, `Initialize-Log`, `Write-Log`, `Test-AdminPrivileges`, `Resolve-WingetPath`, `Invoke-WingetCommand`, `Ensure-Winget`, `Update-WingetSources`, `Initialize-InstalledCacheFromWinget`, `Test-PackageInstalled`, `Test-BundleInstalled`, `Test-WindowsFeatureEnabled`, `Enable-WindowsFeatureIfNeeded`, `Test-DotNetFx4xInstalled`, `Ensure-DotNetFramework4x`, `Get-CatalogItemInstalledState`, `Invoke-SelectedAction`, `Install-Package`, `Install-Packages`, `Install-VCRedist`, `Install-VCRedistAIO`, `Install-WSLFromWinget`, `Upgrade-AllWingetPackages`, `Trigger-WindowsUpdate`, `Enable-HyperV`, `Invoke-PCSetup`.
- **`lib/VMCommon.psm1`** — Shared logic for VM scripts: `Initialize-VMCommonState`, `Initialize-Log`, `Write-Log`, `Read-ValidatedInteger`, `Read-PositiveInteger`, `Show-ISOSourceMenu`, `Invoke-FileDownload`, `Get-WindowsISOViaFido`, `Get-WindowsISOViaUUPDump`, `Set-SelectedISOLanguage`, `Get-SelectedISOLanguage`, `Complete-Log`.

**`MakePCReady.ps1`** and **`MakePCReadyAlternativeGUI.ps1`** only define their respective `Show-InteractiveAppSelector` (TUI tree vs WPF GUI) and call `Invoke-PCSetup -ShowSelector`.

**`Testing-Hyper-V/MakeTestVM.ps1`** and **`Testing-QEMU/MakeTestVM-QEMU.ps1`** import `VMCommon.psm1` and only define their hypervisor-specific logic:
- Hyper-V keeps: `Test-HyperVAvailable`, `Test-NonInteractiveConfig`, `Select-LocalISO`, `Get-AvailableVMSwitches`, `Show-VMConfigMenu`, `New-TestVM`, `Send-VMBootKeystroke`, `Show-Summary`, `New-UnattendISO`
- QEMU keeps: `Resolve-CommandPath`, `Test-Prerequisites`, `Find-OVMFFirmware`, accelerator logic, `Resolve-WindowsISOPath`, `Show-VMConfigMenu`, `Initialize-VMStorage`, `Get-QemuLaunchParameters`, `New-UnattendISO`

ISO acquisition (`Get-WindowsISOViaFido`, `Get-WindowsISOViaUUPDump`, `Invoke-FileDownload`) is fully shared. The QEMU script must call `Get-WindowsISOViaUUPDump -IncludeLinuxRunner` to enable the Linux UUP runner; Hyper-V omits the switch (Windows-only).

### Remaining Duplication

- `Show-VMConfigMenu` — similar pattern but hypervisor-specific parameters (Hyper-V uses Get-VMSwitch; QEMU selects accelerator)

### Two autounattend.xml Differences

Both files are generated from schneegans.de with nearly identical config. The **only difference** is the disk assertion VBScript in `RunSynchronous` order 5:
- **Hyper-V version:** Checks `drive.InterfaceType = "IDE" Or drive.InterfaceType = "SCSI"` (QEMU virtio disks appear as SCSI)
- **QEMU version:** Skips the interface check entirely (`WScript.Quit 0` unconditionally)

If you regenerate one, check whether the other needs the same change.

---

## Key Patterns & Conventions

### PowerShell Patterns
- **Module state initialization** — `Import-Module` gives modules an isolated scope. Entry scripts must call `Initialize-PCSetupState` (PCSetup.Common) or `Initialize-VMCommonState` (VMCommon) with `-LogPath`/`-StartTime` AFTER importing; never assign `$script:logFile` in the entry script, module functions cannot see it.
- **`$script:` scope** for module-level variables (not `$global:`)
- **`[PSCustomObject]@{}`** for catalog entries and config hashmaps
- **`Write-Log`** with levels: `SUCCESS`, `INFO`, `WARNING`, `ERROR`; `-NoConsole` for log-only
- **`Invoke-WingetCommand`** wrapper — always use this, never call `winget.exe` directly
- **`--accept-source-agreements`** auto-appended to all winget subcommands
- **`[int]::TryParse`** for validated integer input (never `[int]$input`)
- **`Unblock-File`** after downloading `.ps1` files

### Catalog Entry Types
```powershell
# Winget package (has Id)
@{ Group="Applications"; SubGroup="General"; Id="7zip.7zip"; Name="7-Zip"; DefaultSelected=$true }

# Action entry (has Action instead of Id)
@{ Group="Platform Features"; SubGroup="Windows"; Action="EnableHyperV"; Name="Hyper-V"; DefaultSelected=$false }
```

Actions dispatch through `Invoke-SelectedAction` → switch on Action name.

### Installed Detection
Two-strategy cache in `Initialize-InstalledCacheFromWinget`:
1. JSON (`winget list --output json`) — Winget ≥ v1.6
2. Text table parsing — fallback for older Winget

Cache stored in `$script:installedCache` (hashtable: PackageId → $true/$false).

---

## How to Add a New App

1. Add entry to `$appCatalog` in `lib/PCSetup.Common.psm1` (single shared catalog — both UIs pick it up automatically)
2. Format: `[PSCustomObject]@{ Group = "..."; SubGroup = "..."; Id = "Winget.PackageId"; Name = "Display Name"; DefaultSelected = $false }`
3. Verify the Winget ID exists: `winget search "name"`
4. Update README.md catalog tables

---

## How to Add a New Action

1. Add entry to `$appCatalog` with `Action = "YourActionName"` (no `Id`)
2. Add case to `Get-CatalogItemInstalledState` (return `$true`/`$false` for installed detection)
3. Add case to `Invoke-SelectedAction` (call your implementation function)
4. Implement the function

All steps happen in `lib/PCSetup.Common.psm1` — the shared catalog means no per-UI duplication.

---

## Testing

### App Installer
```powershell
# Non-interactive (installs only defaults: 7-Zip, Git, VS Code)
.\MakePCReady.ps1 -SkipInteractiveSelection

# Custom log path
.\MakePCReady.ps1 -LogPath "C:\Temp\test.log"
```

### Hyper-V VM
```powershell
.\Testing-Hyper-V\MakeTestVM.ps1 -NonInteractive -ISOPath "C:\ISOs\Win11.iso" -VMName "TestVM" -StartVM
```

### QEMU VM
```powershell
.\Testing-QEMU\MakeTestVM-QEMU.ps1 -NonInteractive -ISOPath "C:\ISOs\Win11.iso" -VMName "QemuTest" -StartVM
```

---

## Known Issues / Tech Debt

1. **~~Remaining ISO download duplication~~ RESOLVED (2026-08-22)** — `Get-WindowsISOViaFido`, `Get-WindowsISOViaUUPDump`, and `Invoke-FileDownload` now live in `lib/VMCommon.psm1`. The QEMU script passes `-IncludeLinuxRunner` to enable the Linux UUP runner; the selected ISO language is shared via `Set-SelectedISOLanguage`/`Get-SelectedISOLanguage`.
2. **No unattend.iso in repo** — Both `Testing-*/unattend.iso` are gitignored (binary). Both scripts now auto-generate from `autounattend.xml` if missing.
3. **Two diverged autounattend.xml** — Hyper-V and QEMU versions differ in disk assertion. Both files now have inline comments documenting the difference.
4. **README says "115+"** — Catalog count is 117 entries. Update when adding/removing entries.
5. **WPF GUI script** — `MakePCReadyAlternativeGUI.ps1` uses Windows-only WPF. No fallback for PowerShell 7 without Windows Desktop.
6. **`winget install --silent`** — Some packages ignore `--silent` and show GUI installers. No workaround.

---

## PowerShell Version Requirements

| Script | Min PS Version | Notes |
|---|---|---|
| `MakePCReady.ps1` | 5.1 | Windows PowerShell |
| `MakePCReadyAlternativeGUI.ps1` | 5.1 | Requires WPF (Windows only) |
| `Testing-Hyper-V/MakeTestVM.ps1` | 5.1 | Requires Hyper-V module |
| `Testing-QEMU/MakeTestVM-QEMU.ps1` | 7.0+ | Cross-platform; PS 5.1 may work on Windows |
| `Testing-QEMU/MakeTestVM-QEMU.sh` | N/A | Bash wrapper, calls `pwsh` |

---

## Winget Notes

- Winget path resolution is complex (4 strategies in `Resolve-WingetPath`). App Execution Aliases in `WindowsApps` are reparse points often invisible to `Get-Command` in elevated shells.
- Exit code `-1978335138` (`0x8A150102`) = source agreement not accepted. The `Invoke-WingetCommand` wrapper auto-appends `--accept-source-agreements`.
- `winget upgrade --all` uses `-r -h` for reduced/hidden output in non-interactive mode.