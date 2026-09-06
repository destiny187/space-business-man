#!/usr/bin/env bash
set -euo pipefail
GAME_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${GAME_GODOT_BIN:-}" ]]; then
  if command -v godot >/dev/null 2>&1; then
    GAME_GODOT_BIN="$(command -v godot)"
  elif command -v godot4 >/dev/null 2>&1; then
    GAME_GODOT_BIN="$(command -v godot4)"
  elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
    GAME_GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
  elif [[ -x "$HOME/Downloads/Godot.app/Contents/MacOS/Godot" ]]; then
    GAME_GODOT_BIN="$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
  else
    echo "Godot 실행 파일을 찾을 수 없습니다. GAME_GODOT_BIN에 실행 파일 경로를 설정하세요." >&2
    exit 1
  fi
fi
exec "$GAME_GODOT_BIN" --path "$GAME_ROOT/우주-비즈니스" "$@"
