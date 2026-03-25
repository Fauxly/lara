#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build_ipa_theos_linux.sh [options]

Options:
  --app-name NAME        App bundle name (default: lara)
  --project-dir PATH     Theos project directory (default: repo root)
  --dist-dir PATH        Output directory for .ipa (default: repo_root/dist)
  -h, --help             Show this help

Environment:
  THEOS                  Path to Theos (auto-detected if unset)
  THEOS_PLATFORM_SDK_ROOT Path to iOS SDK (auto-detected from $THEOS/sdks)
  THEOS_PACKAGE_SCHEME   Packaging scheme (default: jailed)
  THEOS_STAGING_DIR      Theos staging dir (default: repo_root/build/theos-staging)
  LDID_SIGN              1 to ldid-sign app (default: 1)
  LDID_ENTITLEMENTS      Entitlements plist (default: Config/lara.entitlements)
  MAKE_JOBS              Parallelism for make (default: CPU count)
USAGE
}

APP_NAME="lara"
PROJECT_DIR=""
DIST_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-name)
      APP_NAME="$2"
      shift 2
      ;;
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --dist-dir)
      DIST_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$REPO_ROOT}"
DIST_DIR="${DIST_DIR:-$REPO_ROOT/dist}"

if [[ -z "${THEOS:-}" ]]; then
  for candidate in "$REPO_ROOT/theos" "$HOME/theos" "/opt/theos"; do
    if [[ -d "$candidate" ]]; then
      export THEOS="$candidate"
      break
    fi
  done
fi

if [[ -z "${THEOS:-}" || ! -d "$THEOS" ]]; then
  echo "ERROR: THEOS not set and no Theos installation found." >&2
  echo "Set THEOS to your Theos path (e.g. ~/theos)." >&2
  exit 1
fi

if [[ ! -f "$PROJECT_DIR/Makefile" ]]; then
  echo "ERROR: No Theos Makefile found at: $PROJECT_DIR/Makefile" >&2
  echo "Point --project-dir to your Theos project root." >&2
  exit 1
fi

if [[ -z "${THEOS_PLATFORM_SDK_ROOT:-}" ]]; then
  SDK_CANDIDATE=$(ls -d "$THEOS/sdks/iPhoneOS"*.sdk 2>/dev/null | sort -V | tail -n 1 || true)
  if [[ -n "$SDK_CANDIDATE" ]]; then
    export THEOS_PLATFORM_SDK_ROOT="$SDK_CANDIDATE"
  else
    echo "ERROR: No iPhoneOS SDK found under $THEOS/sdks" >&2
    echo "Set THEOS_PLATFORM_SDK_ROOT to an iOS SDK path." >&2
    exit 1
  fi
fi

export THEOS_PACKAGE_SCHEME="${THEOS_PACKAGE_SCHEME:-jailed}"
export THEOS_STAGING_DIR="${THEOS_STAGING_DIR:-$REPO_ROOT/build/theos-staging}"

MAKE_JOBS="${MAKE_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

echo "Using THEOS=$THEOS"
echo "Using SDK=$THEOS_PLATFORM_SDK_ROOT"
echo "Using package scheme=$THEOS_PACKAGE_SCHEME"

echo "Building Theos project in $PROJECT_DIR"
make -C "$PROJECT_DIR" clean
make -C "$PROJECT_DIR" -j"$MAKE_JOBS" stage

APP_DIR="$THEOS_STAGING_DIR/Applications/$APP_NAME.app"
if [[ ! -d "$APP_DIR" ]]; then
  APP_DIR=$(find "$THEOS_STAGING_DIR" -maxdepth 3 -name "*.app" -print -quit || true)
fi

if [[ -z "$APP_DIR" || ! -d "$APP_DIR" ]]; then
  echo "ERROR: Built .app not found in staging dir: $THEOS_STAGING_DIR" >&2
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/Payload"
cp -a "$APP_DIR" "$DIST_DIR/Payload/"

rm -rf "$DIST_DIR/Payload/$(basename "$APP_DIR")/_CodeSignature" \
       "$DIST_DIR/Payload/$(basename "$APP_DIR")/embedded.mobileprovision" || true

LDID_SIGN="${LDID_SIGN:-1}"
LDID_ENTITLEMENTS="${LDID_ENTITLEMENTS:-$REPO_ROOT/Config/lara.entitlements}"
if [[ "$LDID_SIGN" == "1" ]]; then
  if ! command -v ldid >/dev/null 2>&1; then
    echo "ERROR: LDID_SIGN=1 but 'ldid' not found in PATH." >&2
    exit 1
  fi
  if [[ -f "$LDID_ENTITLEMENTS" ]]; then
    echo "Signing with ldid entitlements: $LDID_ENTITLEMENTS"
    ldid -S"$LDID_ENTITLEMENTS" "$DIST_DIR/Payload/$(basename "$APP_DIR")/$APP_NAME"
  else
    echo "WARN: Entitlements not found ($LDID_ENTITLEMENTS), skipping ldid signing." >&2
  fi
fi

IPA_PATH="$DIST_DIR/$APP_NAME.ipa"
rm -f "$IPA_PATH"
(
  cd "$DIST_DIR"
  zip -qr "$IPA_PATH" Payload
)

echo "Created: $IPA_PATH"
