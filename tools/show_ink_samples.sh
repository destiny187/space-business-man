#!/usr/bin/env bash
set -euo pipefail
INK_STUDY_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$INK_STUDY_ROOT/tools/godot.sh" res://scenes/showcase/ink_samples.tscn "$@"
