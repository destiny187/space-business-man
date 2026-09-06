#!/usr/bin/env bash
set -euo pipefail
GAME_TOOLS="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
run_check() {
  local GAME_CHECK_LOG
  GAME_CHECK_LOG="$(mktemp -t locus-check)"
  if ! "$GAME_TOOLS/godot.sh" "$@" > "$GAME_CHECK_LOG" 2>&1; then
    cat "$GAME_CHECK_LOG"
    rm -f "$GAME_CHECK_LOG"
    return 1
  fi
  cat "$GAME_CHECK_LOG"
  if [[ "$(<"$GAME_CHECK_LOG")" == *"ERROR:"* ]]; then
    rm -f "$GAME_CHECK_LOG"
    return 1
  fi
  rm -f "$GAME_CHECK_LOG"
}
run_check --headless --editor --quit
run_check --headless --script res://tests/test_ink_contract.gd
run_check --headless --script res://tests/test_campaign.gd
run_check --headless --script res://tests/test_events.gd
run_check --headless --script res://tests/test_reliability.gd
run_check --headless --script res://tests/test_workflow.gd
run_check --headless --script res://tests/test_onboarding.gd
GAME_AUDIO_DRIVER="Dummy"
if [[ "$(uname -s)" == "Darwin" ]]; then GAME_AUDIO_DRIVER="CoreAudio"; fi
run_check --headless --audio-driver "$GAME_AUDIO_DRIVER" --script res://tests/test_audio.gd
if [[ "${1:-}" == "--with-ui" ]]; then
  run_check --script res://tests/test_input.gd
  run_check --script res://tests/test_presentation.gd
  run_check --script res://tests/test_graphics.gd
  run_check --script res://tests/test_ink_rendering.gd -- --capture-output="$GAME_TOOLS/../test-results/ink-rendering"
fi
