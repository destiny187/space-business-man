#!/usr/bin/env bash
set -euo pipefail
INK_CATALOG_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$INK_CATALOG_ROOT/tools/godot.sh" res://scenes/showcase/ink_catalog.tscn -- --capture
