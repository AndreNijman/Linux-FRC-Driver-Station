#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LATEST_ARCHIVE="$(ls -1t "$ROOT_DIR"/dist/ni-frc-2026-linux-full-*.tar.zst 2>/dev/null | head -n1 || true)"

if [[ -z "$LATEST_ARCHIVE" ]]; then
  echo "No archive in dist/. Run scripts/make-release-archive.sh first."
  exit 1
fi

"$ROOT_DIR/install.sh" --bundle-file "$LATEST_ARCHIVE"
