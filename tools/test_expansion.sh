#!/usr/bin/env bash
set -euo pipefail
EXPANSION_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
run_expansion_check() {
  local EXPANSION_LOG
  EXPANSION_LOG="$(mktemp)"
  if ! "$EXPANSION_ROOT/tools/godot.sh" "$@" > "$EXPANSION_LOG" 2>&1; then
    cat "$EXPANSION_LOG"
    rm -f "$EXPANSION_LOG"
    return 1
  fi
  cat "$EXPANSION_LOG"
  if rg -q 'SCRIPT ERROR:|ERROR:|FAIL:' "$EXPANSION_LOG"; then
    rm -f "$EXPANSION_LOG"
    return 1
  fi
  rm -f "$EXPANSION_LOG"
}
python3 "$EXPANSION_ROOT/tools/verify_astronomy.py"
run_expansion_check --headless --editor --quit
run_expansion_check --headless --script res://tests/test_universe.gd
if [[ "${1:-}" == "--with-ui" ]]; then
  run_expansion_check --script res://tests/test_exploration_ui.gd -- --exploration-test
fi
