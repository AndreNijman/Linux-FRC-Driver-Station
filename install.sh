#!/usr/bin/env bash
set -euo pipefail

DEFAULT_ASSET_PATTERN='ni-frc-2026-linux-full.*\.tar\.zst(\.part-[0-9]{3})?$'

usage() {
  cat <<USAGE
Install NI FRC 2026 Linux Wine bundle.

Usage:
  $0 [--bundle-file PATH | --bundle-url URL | --repo OWNER/REPO]
     [--asset-pattern REGEX] [--target-home PATH] [--skip-udev]

Examples:
  $0 --bundle-file ./dist/ni-frc-2026-linux-full.tar.zst
  $0 --bundle-file ./dist/ni-frc-2026-linux-full.tar.zst.part-000
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
  if [[ ! -e "$BUNDLE_FILE" ]]; then
    echo "Bundle file not found: $BUNDLE_FILE" >&2
    exit 1
  fi
  if [[ "$BUNDLE_FILE" =~ \.part-[0-9]{3}$ ]]; then
    STEM="${BUNDLE_FILE%.part-*}"
    ARCHIVE_PATH="$TMP_DIR/bundle.tar.zst"
    echo "Reassembling local split parts from: ${STEM}.part-###"
    cat "${STEM}.part-"[0-9][0-9][0-9] > "$ARCHIVE_PATH"
  else
    ARCHIVE_PATH="$BUNDLE_FILE"
  fi
elif [[ -n "$BUNDLE_URL" ]]; then
  ARCHIVE_PATH="$TMP_DIR/bundle.tar.zst"
  echo "Downloading bundle from URL..."
  curl -fL "$BUNDLE_URL" -o "$ARCHIVE_PATH"
else
  API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
  echo "Resolving latest release asset from ${GITHUB_REPO}..."
  RELEASE_JSON="$TMP_DIR/release.json"
  curl -fsSL "$API_URL" -o "$RELEASE_JSON"
  mapfile -t ASSET_URLS < <(
    sed -n 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$RELEASE_JSON" | \
      grep -E "$ASSET_PATTERN" || true
  )
  if [[ "${#ASSET_URLS[@]}" -eq 0 ]]; then
    echo "Could not find release asset matching pattern: $ASSET_PATTERN" >&2
    echo "Tip: publish assets like ni-frc-2026-linux-full-YYYYMMDD-HHMMSS.tar.zst.part-000" >&2
    exit 1
  fi

  ARCHIVE_PATH="$TMP_DIR/bundle.tar.zst"
  mapfile -t PART_URLS < <(printf '%s\n' "${ASSET_URLS[@]}" | grep -E '\.part-[0-9]{3}$' || true)
  if [[ "${#PART_URLS[@]}" -gt 0 ]]; then
    # If multiple split sets exist, pick the lexicographically newest stem.
    mapfile -t STEMS < <(printf '%s\n' "${PART_URLS[@]}" | sed -E 's/\.part-[0-9]{3}$//' | sort -u)
    SELECTED_STEM="$(printf '%s\n' "${STEMS[@]}" | sort | tail -n1)"
    mapfile -t SELECTED_PARTS < <(printf '%s\n' "${PART_URLS[@]}" | grep -F "${SELECTED_STEM}.part-" | sort)
    echo "Downloading split bundle parts (${#SELECTED_PARTS[@]})..."
    mkdir -p "$TMP_DIR/parts"
    for url in "${SELECTED_PARTS[@]}"; do
      file="$TMP_DIR/parts/$(basename "$url")"
      echo "  - $(basename "$url")"
      curl -fL "$url" -o "$file"
    done
    cat "$TMP_DIR/parts"/"$(basename "$SELECTED_STEM").part-"[0-9][0-9][0-9] > "$ARCHIVE_PATH"
  else
    ASSET_URL="$(printf '%s\n' "${ASSET_URLS[@]}" | sort | tail -n1)"
    echo "Downloading ${ASSET_URL} ..."
    curl -fL "$ASSET_URL" -o "$ARCHIVE_PATH"
  fi
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
