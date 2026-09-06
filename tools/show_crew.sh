#!/usr/bin/env bash
set -euo pipefail
CREW_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$CREW_ROOT/tools/godot.sh" res://scenes/app/crew_expedition.tscn
