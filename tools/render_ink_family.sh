#!/usr/bin/env bash
set -euo pipefail
INK_FAMILY_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$INK_FAMILY_ROOT/tools/godot.sh" res://scenes/showcase/ink_family.tscn
