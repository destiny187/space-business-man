#!/usr/bin/env bash
set -euo pipefail
QUALITY_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
QUALITY_EVIDENCE="$(mktemp -d "${TMPDIR:-/tmp}/locus-play-quality-XXXXXX")"
"$QUALITY_ROOT/tools/godot.sh" --script res://tests/test_expedition_presentation.gd -- --crew-ui-test "--crew-folder=$QUALITY_EVIDENCE" > "$QUALITY_EVIDENCE/presentation.log" 2>&1 || { cat "$QUALITY_EVIDENCE/presentation.log"; exit 1; }
cat "$QUALITY_EVIDENCE/presentation.log"
if rg -q 'SCRIPT ERROR:|ERROR:|FAIL:' "$QUALITY_EVIDENCE/presentation.log"; then exit 1; fi
rg -q 'SOLO_ENTRY_CHECKS .* FAILURES 0' "$QUALITY_EVIDENCE/presentation.log"
printf 'Play quality evidence: %s\n' "$QUALITY_EVIDENCE"
