#!/usr/bin/env bash
# Independent rendering study: no campaign save is read or modified.
set -euo pipefail
SHOWCASE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$SHOWCASE_ROOT/test-results/showcase"
exec "$SHOWCASE_ROOT/tools/godot.sh" --resolution 1920x1080 res://scenes/showcase/quality_showcase.tscn "$@"
