#!/usr/bin/env bash
set -euo pipefail

DEFAULT_ASSET_PATTERN='ni-frc-2026-linux-full.*\.tar\.zst'

usage() {
  cat <<USAGE
Install NI FRC 2026 Linux Wine bundle.

Usage:
  $0 [--bundle-file PATH | --bundle-url URL | --repo OWNER/REPO]
     [--asset-pattern REGEX] [--target-home PATH] [--skip-udev]

Examples:
  $0 --bundle-file ./dist/ni-frc-2026-linux-full.tar.zst
  $0 --repo yourname/FRC-2026-Linux-Portable
  curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/install.sh | bash -s -- --repo OWNER/REPO
USAGE
}

BUNDLE_FILE=""
BUNDLE_URL=""
GITHUB_REPO=""
ASSET_PATTERN="$DEFAULT_ASSET_PATTERN"
TARGET_HOME="${HOME}"
SKIP_UDEV=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle-file)
      BUNDLE_FILE="$2"; shift 2 ;;
    --bundle-url)
      BUNDLE_URL="$2"; shift 2 ;;
    --repo)
      GITHUB_REPO="$2"; shift 2 ;;
    --asset-pattern)
      ASSET_PATTERN="$2"; shift 2 ;;
    --target-home)
      TARGET_HOME="$2"; shift 2 ;;
    --skip-udev)
      SKIP_UDEV=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2 ;;
  esac
done

if [[ -n "$BUNDLE_FILE" && -n "$BUNDLE_URL" ]] || \
   [[ -n "$BUNDLE_FILE" && -n "$GITHUB_REPO" ]] || \
   [[ -n "$BUNDLE_URL" && -n "$GITHUB_REPO" ]]; then
  echo "Pick only one source: --bundle-file OR --bundle-url OR --repo" >&2
  exit 2
fi

if [[ -z "$BUNDLE_FILE" && -z "$BUNDLE_URL" && -z "$GITHUB_REPO" ]]; then
  echo "No bundle source provided." >&2
  usage
  exit 2
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }
}

need_cmd tar
need_cmd rsync
need_cmd curl
need_cmd zstd

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

ARCHIVE_PATH=""

if [[ -n "$BUNDLE_FILE" ]]; then
  ARCHIVE_PATH="$BUNDLE_FILE"
elif [[ -n "$BUNDLE_URL" ]]; then
  ARCHIVE_PATH="$TMP_DIR/bundle.tar.zst"
  echo "Downloading bundle from URL..."
  curl -fL "$BUNDLE_URL" -o "$ARCHIVE_PATH"
else
  API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
  echo "Resolving latest release asset from ${GITHUB_REPO}..."
  ASSET_URL="$(curl -fsSL "$API_URL" | grep -Eo 'https://[^\"]+' | grep -E "$ASSET_PATTERN" | head -n1 || true)"
  if [[ -z "$ASSET_URL" ]]; then
    echo "Could not find release asset matching pattern: $ASSET_PATTERN" >&2
    echo "Tip: publish an asset like ni-frc-2026-linux-full-YYYYMMDD-HHMMSS.tar.zst" >&2
    exit 1
  fi
  ARCHIVE_PATH="$TMP_DIR/bundle.tar.zst"
  echo "Downloading ${ASSET_URL} ..."
  curl -fL "$ASSET_URL" -o "$ARCHIVE_PATH"
fi

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Bundle archive not found: $ARCHIVE_PATH" >&2
  exit 1
fi

EXTRACT_DIR="$TMP_DIR/extracted"
mkdir -p "$EXTRACT_DIR"

echo "Extracting bundle..."
tar --zstd -xf "$ARCHIVE_PATH" -C "$EXTRACT_DIR"

BUNDLE_ROOT="$(find "$EXTRACT_DIR" -maxdepth 2 -type f -name restore-to-home.sh | head -n1 | xargs -r dirname)"
if [[ -z "$BUNDLE_ROOT" ]]; then
  echo "Invalid bundle: restore-to-home.sh not found." >&2
  exit 1
fi

echo "Restoring into ${TARGET_HOME} ..."
"$BUNDLE_ROOT/restore-to-home.sh" "$TARGET_HOME"

UDEV_RULE="$BUNDLE_ROOT/system/etc/udev/rules.d/99-gamesir-g7-frc.rules"
if [[ "$SKIP_UDEV" -eq 0 && -f "$UDEV_RULE" ]]; then
  if command -v sudo >/dev/null 2>&1; then
    echo "Installing optional udev rule (requires sudo)..."
    sudo cp -f "$UDEV_RULE" /etc/udev/rules.d/99-gamesir-g7-frc.rules
    sudo udevadm control --reload-rules || true
    sudo udevadm trigger || true
  else
    echo "sudo not found; skipping udev rule install."
  fi
fi

echo
echo "Done. Run Driver Station with:"
echo "  ${TARGET_HOME}/.local/bin/ni-frc-2026-driver-station"
