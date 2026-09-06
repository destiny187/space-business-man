#!/usr/bin/env bash
set -euo pipefail
LITHOTHERM_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$LITHOTHERM_ROOT/tools/godot.sh" res://scenes/showcase/lithotherm.tscn "$@"
