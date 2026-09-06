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
run_expansion_check --headless --script res://tests/test_terrain.gd
run_expansion_check --headless --script res://tests/test_terrain_navigation.gd
run_expansion_check --headless --script res://tests/test_surface_logistics.gd
run_expansion_check --headless --script res://tests/test_crew_authority.gd
run_expansion_check --headless --script res://tests/test_crew_navigation.gd
run_expansion_check --headless --script res://tests/test_crew_surface.gd
run_expansion_check --headless --script res://tests/test_expedition_business.gd
run_expansion_check --headless --script res://tests/test_vessel_refit.gd
run_expansion_check --headless --script res://tests/test_vessel_visuals.gd
run_expansion_check --headless --script res://tests/test_field_engineering.gd
run_expansion_check --headless --script res://tests/test_industry_replica_budget.gd
run_expansion_check --headless --script res://tests/test_ecology.gd
run_expansion_check --headless --script res://tests/test_ecology_recovery.gd -- --exploration-test
if [[ "${1:-}" == "--with-ui" ]]; then
  run_expansion_check --script res://tests/test_exploration_ui.gd -- --exploration-test
  run_expansion_check --script res://tests/test_surface_ui.gd -- --exploration-test
  run_expansion_check --script res://tests/test_courier_ui.gd -- --exploration-test
  run_expansion_check --script res://tests/test_ink_local_light.gd
  run_expansion_check --script res://tests/test_ecology_ui.gd -- --exploration-test
  run_expansion_check --script res://tests/test_ecology_workflow.gd -- --exploration-test
fi
