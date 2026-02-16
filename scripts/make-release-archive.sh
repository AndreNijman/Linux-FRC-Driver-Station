#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"

SPLIT_SIZE="1900M"
NO_SPLIT=0
BUNDLE_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-split)
      NO_SPLIT=1; shift ;;
    --split-size)
      SPLIT_SIZE="$2"; shift 2 ;;
    -h|--help)
      cat <<USAGE
Usage: $0 [BUNDLE_DIR] [--no-split] [--split-size 1900M]

Default behavior:
- Builds a .tar.zst in dist/
- Splits it into <2GB parts for GitHub release upload
USAGE
      exit 0 ;;
    *)
      if [[ -z "$BUNDLE_DIR" ]]; then
        BUNDLE_DIR="$1"
      else
        echo "Unexpected arg: $1" >&2
        exit 2
      fi
      shift ;;
  esac
done

if [[ -z "$BUNDLE_DIR" ]]; then
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
sha256sum "$OUT_FILE" > "$OUT_FILE.sha256"

echo "Archive created: $OUT_FILE"
ls -lh "$OUT_FILE"

if [[ "$NO_SPLIT" -eq 0 ]]; then
  echo "Splitting archive for GitHub release limit (<2GB each): $SPLIT_SIZE"
  rm -f "$OUT_FILE.part-"[0-9][0-9][0-9] 2>/dev/null || true
  split -d -a 3 -b "$SPLIT_SIZE" "$OUT_FILE" "$OUT_FILE.part-"
  sha256sum "$OUT_FILE.part-"[0-9][0-9][0-9] > "$OUT_FILE.parts.sha256"
  ls -lh "$OUT_FILE.part-"[0-9][0-9][0-9]
fi
