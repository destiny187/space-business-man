#!/usr/bin/env bash
set -euo pipefail
GAME_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$GAME_ROOT/builds/macos"
"$GAME_ROOT/tools/godot.sh" --headless --editor --quit
"$GAME_ROOT/tools/godot.sh" --headless --export-release macOS "$GAME_ROOT/builds/macos/Locus-Space-Business.zip"
/usr/bin/ditto -xk "$GAME_ROOT/builds/macos/Locus-Space-Business.zip" "$GAME_ROOT/builds/macos"
GAME_APP="$GAME_ROOT/builds/macos/Locus.app"
python3 "$GAME_ROOT/tools/package_macos.py"
/usr/bin/codesign --force --deep --sign - --timestamp=none "$GAME_APP"
/usr/bin/codesign --verify --deep --strict "$GAME_APP"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$GAME_APP" "$GAME_ROOT/builds/macos/Locus-Space-Business.zip"
(cd "$GAME_ROOT/builds/macos" && /usr/bin/shasum -a256 Locus-Space-Business.zip > SHA256SUMS.txt)
