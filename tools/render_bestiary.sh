#!/usr/bin/env bash
set -euo pipefail
BESTIARY_ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
exec "$BESTIARY_ROOT/tools/godot.sh" --script res://scripts/showcase/render_bestiary.gd -- "$@"
