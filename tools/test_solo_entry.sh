#!/usr/bin/env bash
set -euo pipefail
SOLO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SOLO_EVIDENCE="$(mktemp -d "${TMPDIR:-/tmp}/locus-solo-entry-XXXXXX")"
for SOLO_SCRIPT in test_solo_entry test_solo_shortcuts test_client_settings; do
  "$SOLO_ROOT/tools/godot.sh" --script "res://tests/$SOLO_SCRIPT.gd" -- --crew-ui-test "--crew-folder=$SOLO_EVIDENCE" > "$SOLO_EVIDENCE/$SOLO_SCRIPT.log" 2>&1 || { cat "$SOLO_EVIDENCE/$SOLO_SCRIPT.log"; exit 1; }
  cat "$SOLO_EVIDENCE/$SOLO_SCRIPT.log"
  if rg -q 'SCRIPT ERROR:|ERROR:|FAIL:' "$SOLO_EVIDENCE/$SOLO_SCRIPT.log"; then exit 1; fi
done
printf 'Solo evidence: %s\n' "$SOLO_EVIDENCE"
