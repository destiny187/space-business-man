#!/usr/bin/env bash
set -euo pipefail
GAME_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$GAME_ROOT/builds/windows" "$GAME_ROOT/test-results"
GAME_STAGE="$(mktemp -d "$GAME_ROOT/builds/windows/.export-XXXXXX")"
trap 'rm -rf -- "$GAME_STAGE"' EXIT
"$GAME_ROOT/tools/godot.sh" --headless --editor --quit > "$GAME_ROOT/test-results/windows-import.log" 2>&1
"$GAME_ROOT/tools/godot.sh" --headless --export-release "Windows Desktop" "$GAME_STAGE/Locus.exe" > "$GAME_ROOT/test-results/windows-export.log" 2>&1
python3 "$GAME_ROOT/tools/package_windows.py" "$GAME_STAGE"
python3 "$GAME_ROOT/tools/verify_windows.py"
