#!/usr/bin/env bash
set -euo pipefail
RELAY_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:-up}" in
  up) docker compose -f "$RELAY_ROOT/services/crew-relay/compose.yaml" up -d --build ;;
  down) docker compose -f "$RELAY_ROOT/services/crew-relay/compose.yaml" down ;;
  logs) docker compose -f "$RELAY_ROOT/services/crew-relay/compose.yaml" logs --tail=60 ;;
  status) docker compose -f "$RELAY_ROOT/services/crew-relay/compose.yaml" ps ;;
  *) echo '사용법: tools/crew_relay.sh [up|down|logs|status]' >&2; exit 2 ;;
esac
