#!/usr/bin/env bash
set -euo pipefail
GAME_REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_COMPARE=/tmp/terrain-optimization-20260909
mkdir -p "$GAME_COMPARE"
# This commit is the verified first optimization, before tiled streaming.
for GAME_SOURCE in terrain_mesher distant_terrain; do
  git -C "$GAME_REPO" show "95ad7efe:우주-비즈니스/scripts/world/$GAME_SOURCE.gd" | sed '/^class_name /d' > "$GAME_COMPARE/legacy_${GAME_SOURCE#terrain_}.gd"
done
mv "$GAME_COMPARE/legacy_distant_terrain.gd" "$GAME_COMPARE/legacy_distant.gd"
"$GAME_REPO/tools/godot.sh" --script res://tests/check_terrain_streaming_optimization.gd "$@" > "$GAME_COMPARE/run.log" 2>&1
cat "$GAME_COMPARE/run.log"
if [[ "$(<"$GAME_COMPARE/run.log")" == *"ERROR:"* ]]; then exit 1; fi
