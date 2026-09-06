#!/usr/bin/env bash
set -euo pipefail
BESTIARY_ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
exec "$BESTIARY_ROOT/tools/godot.sh" res://scenes/showcase/bestiary.tscn "$@"
