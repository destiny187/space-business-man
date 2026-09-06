#!/usr/bin/env bash
set -euo pipefail
ASSET_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! git lfs version >/dev/null 2>&1; then
  printf '%s\n' 'Git LFS를 먼저 설치하세요. macOS: brew install git-lfs / Windows: Git LFS 설치 프로그램' >&2
  exit 1
fi
git -C "$ASSET_ROOT" lfs install --local
git -C "$ASSET_ROOT" lfs pull
printf '%s\n' '현재 체크아웃의 LFS 에셋을 받았습니다.'
