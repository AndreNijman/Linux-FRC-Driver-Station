#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LATEST_ARCHIVE="$(ls -1t "$ROOT_DIR"/dist/ni-frc-2026-linux-full-*.tar.zst 2>/dev/null | head -n1 || true)"

if [[ -n "$LATEST_ARCHIVE" ]]; then
  "$ROOT_DIR/install.sh" --bundle-file "$LATEST_ARCHIVE"
  exit 0
fi

LATEST_PART0="$(ls -1t "$ROOT_DIR"/dist/ni-frc-2026-linux-full-*.tar.zst.part-000 2>/dev/null | head -n1 || true)"
if [[ -n "$LATEST_PART0" ]]; then
  "$ROOT_DIR/install.sh" --bundle-file "$LATEST_PART0"
  exit 0
fi

echo "No archive in dist/. Run scripts/make-release-archive.sh first."
exit 1
