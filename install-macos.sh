#!/usr/bin/env bash
set -euo pipefail

DEFAULT_ASSET_PATTERN='ni-frc-2026-linux-full.*\.tar\.zst(\.part-[0-9]{3})?$'

usage() {
  cat <<USAGE
Install NI FRC 2026 Wine bundle on macOS.

Usage:
  $0 [--bundle-file PATH | --bundle-url URL | --repo OWNER/REPO]
     [--asset-pattern REGEX] [--target-home PATH]

Examples:
  $0 --bundle-file ./dist/ni-frc-2026-linux-full.tar.zst
  $0 --bundle-file ./dist/ni-frc-2026-linux-full.tar.zst.part-000
  $0 --repo yourname/FRC-2026-Linux-Portable
  curl -fsSL https://raw.githubusercontent.com/OWNER/REPO/main/install-macos.sh | bash -s -- --repo OWNER/REPO
USAGE
}

BUNDLE_FILE=""
BUNDLE_URL=""
GITHUB_REPO=""
ASSET_PATTERN="$DEFAULT_ASSET_PATTERN"
TARGET_HOME="${HOME}"

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

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer is for macOS (Darwin)." >&2
  echo "Use ./install.sh on Linux." >&2
  exit 1
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }
}

need_cmd tar
need_cmd rsync
need_cmd curl
need_cmd zstd
need_cmd sed
need_cmd grep
need_cmd sort
need_cmd head
need_cmd find
need_cmd dirname
need_cmd basename

ensure_wine() {
  if command -v wine >/dev/null 2>&1; then
    return 0
  fi

  echo "Wine not found. Attempting macOS install via Homebrew..."
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required to install Wine automatically." >&2
    echo "Install Homebrew first, then rerun this script." >&2
    exit 1
  fi

  brew install --cask wine-stable
  command -v wine >/dev/null 2>&1 || { echo "Wine install failed." >&2; exit 1; }
}

ensure_wine

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ni-frc-2026-macos.XXXXXX")"
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

  ASSET_URLS=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && ASSET_URLS+=("$line")
  done < <(
    sed -n 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$RELEASE_JSON" | \
      grep -E "$ASSET_PATTERN" || true
  )

  if [[ "${#ASSET_URLS[@]}" -eq 0 ]]; then
    echo "Could not find release asset matching pattern: $ASSET_PATTERN" >&2
    echo "Tip: publish assets like ni-frc-2026-linux-full-YYYYMMDD-HHMMSS.tar.zst.part-000" >&2
    exit 1
  fi

  ARCHIVE_PATH="$TMP_DIR/bundle.tar.zst"

  PART_URLS=()
  for url in "${ASSET_URLS[@]}"; do
    if [[ "$url" =~ \.part-[0-9]{3}$ ]]; then
      PART_URLS+=("$url")
    fi
  done

  if [[ "${#PART_URLS[@]}" -gt 0 ]]; then
    STEMS=()
    for url in "${PART_URLS[@]}"; do
      STEMS+=("${url%.part-*}")
    done
    SELECTED_STEM="$(printf '%s\n' "${STEMS[@]}" | sort -u | tail -n1)"

    SELECTED_PARTS=()
    for url in "${PART_URLS[@]}"; do
      case "$url" in
        "${SELECTED_STEM}.part-"*)
          SELECTED_PARTS+=("$url")
          ;;
      esac
    done

    echo "Downloading split bundle parts (${#SELECTED_PARTS[@]})..."
    mkdir -p "$TMP_DIR/parts"
    while IFS= read -r url; do
      [[ -z "$url" ]] && continue
      file="$TMP_DIR/parts/$(basename "$url")"
      echo "  - $(basename "$url")"
      curl -fL "$url" -o "$file"
    done < <(printf '%s\n' "${SELECTED_PARTS[@]}" | sort)

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
zstd -dc "$ARCHIVE_PATH" | tar -xf - -C "$EXTRACT_DIR"

RESTORE_SCRIPT="$(find "$EXTRACT_DIR" -type f -name restore-to-home.sh | head -n1)"
if [[ -z "$RESTORE_SCRIPT" ]]; then
  echo "Invalid bundle: restore-to-home.sh not found." >&2
  exit 1
fi
BUNDLE_ROOT="$(dirname "$RESTORE_SCRIPT")"

echo "Restoring into ${TARGET_HOME} ..."
"$BUNDLE_ROOT/restore-to-home.sh" "$TARGET_HOME"

patch_runtime_dir() {
  launcher="$1"
  if [[ ! -f "$launcher" ]]; then
    return 0
  fi
  if grep -q '/run/user/\$(id -u)' "$launcher"; then
    sed -i '' \
      's|export XDG_RUNTIME_DIR="/run/user/$(id -u)"|export XDG_RUNTIME_DIR="${TMPDIR:-/tmp}/frc-runtime-$(id -u)"; mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true|' \
      "$launcher"
  fi
}

patch_runtime_dir "$TARGET_HOME/.local/bin/ni-frc-2026-driver-station"
patch_runtime_dir "$TARGET_HOME/.local/bin/ni-frc-2026-joystick-panel"

echo
echo "Done. Run Driver Station with:"
echo "  ${TARGET_HOME}/.local/bin/ni-frc-2026-driver-station"
