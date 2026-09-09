#!/bin/bash
set -euo pipefail
# Finder double-click entry point on macOS.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
exec "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/crew_relay_local.sh" "$@"
