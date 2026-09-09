#!/usr/bin/env bash
# Native Python runner. The environment belongs to this repository only.
set -euo pipefail
RELAY_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RELAY_ENV="$RELAY_ROOT/.local/crew-relay/venv"
RELAY_REQUIREMENTS="$RELAY_ROOT/services/crew-relay/requirements.txt"
if ! command -v python3 >/dev/null 2>&1; then
  echo 'Python 3.10 이상이 필요합니다. 설치 후 다시 실행하세요.' >&2
  exit 1
fi
if [[ ! -x "$RELAY_ENV/bin/python" ]]; then
  echo '이 저장소 전용 Python 실행 환경을 준비합니다.'
  python3 -m venv "$RELAY_ENV"
fi
if ! cmp -s "$RELAY_REQUIREMENTS" "$RELAY_ENV/crew-requirements.txt"; then
  "$RELAY_ENV/bin/python" -m pip install --disable-pip-version-check -r "$RELAY_REQUIREMENTS"
  cp "$RELAY_REQUIREMENTS" "$RELAY_ENV/crew-requirements.txt"
fi
export CREW_RELAY_BIND="${CREW_RELAY_BIND:-127.0.0.1}"
export CREW_RELAY_PORT="${CREW_RELAY_PORT:-24680}"
echo "초대 서버를 실행합니다: ws://${CREW_RELAY_BIND}:${CREW_RELAY_PORT}/relay"
echo '이 터미널을 켜 두세요. 종료하려면 Ctrl+C를 누르세요.'
exec "$RELAY_ENV/bin/python" -u "$RELAY_ROOT/services/crew-relay/server.py"
