#!/usr/bin/env bash
# Patch (or --check) Demons' Timeline's Easy Save 3 IO for CrossOver.
# Usage: ./patch.sh [dll] [--check]   (dll defaults to the CrossOver Steam bottle)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
default="$HOME/Library/Application Support/CrossOver/Bottles/Steam/drive_c/Program Files (x86)/Steam/steamapps/common/Demons'Timeline/DemonsTimeline_Data/Managed/Assembly-CSharp-firstpass.dll"
dll="$default"
if [[ $# -gt 0 && $1 != --* ]]; then dll="$1"; shift; fi
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
exec nix shell nixpkgs#dotnet-sdk_8 -c dotnet run --project "$here" -c Release -- "$dll" "$@"
