#!/usr/bin/env bash
set -euo pipefail
EXPLORATION_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$EXPLORATION_ROOT/tools/godot.sh" res://scenes/app/exploration.tscn "$@"
