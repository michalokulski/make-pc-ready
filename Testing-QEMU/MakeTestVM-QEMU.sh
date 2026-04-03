#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS_SCRIPT="$SCRIPT_DIR/MakeTestVM-QEMU.ps1"

if ! command -v pwsh >/dev/null 2>&1; then
    echo "Error: 'pwsh' was not found. Install PowerShell 7 first."
    exit 1
fi

if [[ ! -f "$PS_SCRIPT" ]]; then
    echo "Error: PowerShell script not found at $PS_SCRIPT"
    exit 1
fi

pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT" "$@"
