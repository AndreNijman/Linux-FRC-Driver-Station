#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"

if [[ $# -gt 0 ]]; then
  BUNDLE_DIR="$1"
else
  BUNDLE_DIR="$(ls -1dt "$HOME"/Downloads/ni-frc-2026-linux-full-* 2>/dev/null | head -n1 || true)"
fi

if [[ -z "${BUNDLE_DIR:-}" || ! -d "$BUNDLE_DIR" ]]; then
  echo "Bundle directory not found."
  echo "Pass it explicitly: $0 /path/to/ni-frc-2026-linux-full-..."
  exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_FILE="$DIST_DIR/ni-frc-2026-linux-full-${STAMP}.tar.zst"

echo "Creating archive from: $BUNDLE_DIR"
tar --zstd -cf "$OUT_FILE" -C "$(dirname "$BUNDLE_DIR")" "$(basename "$BUNDLE_DIR")"

echo "Archive created: $OUT_FILE"
ls -lh "$OUT_FILE"
