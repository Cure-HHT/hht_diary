#!/bin/bash
# Implements: DIARY-OPS-single-promotable-artifact/C

# Run the Clinical Diary app with the LOCAL flavor (talks to the
# diary-server published by deployment/local-stack on the sponsor repo).
#
# Web/desktop default to http://localhost:8081 via the FlavorConfig.local
# entry. Mobile builds need DIARY_API_BASE set to a host-reachable URL
# (10.0.2.2 for the Android emulator, the host machine's LAN IP for a
# physical device) since localhost on the device is the device, not the
# host.
#
# Note: flavorizr.yaml has no `local` native flavor (only dev/qa/uat/prod).
# Mobile invocations use --flavor dev for the native build config; the
# Dart-side env comes from the stamped assets/config/env.json (local).
#
# Usage: ./tool/run_local.sh [OPTIONS]
#
# Options:
#   --import-file <path>    Path to JSON export file to auto-import on startup
#   --device <device>       Device to run on (e.g., chrome, macos, iPhone)
#   --web                   Shortcut for --device chrome (default)
#   --api-base <url>        Override the diary-server URL (sets DIARY_API_BASE)
#
# Examples:
#   ./tool/run_local.sh                                           # Chrome -> localhost:8081
#   ./tool/run_local.sh --device macos                            # macOS  -> localhost:8081
#   ./tool/run_local.sh --device emulator-5554 \
#       --api-base http://10.0.2.2:8081                           # Android emulator
#   ./tool/run_local.sh --import-file ./test/data/export.json     # Run with test data

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMPORT_FILE=""
DEVICE="chrome"
API_BASE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --import-file)
            IMPORT_FILE="$2"
            shift 2
            ;;
        --device)
            DEVICE="$2"
            shift 2
            ;;
        --web)
            DEVICE="chrome"
            shift
            ;;
        --api-base)
            API_BASE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./tool/run_local.sh [--import-file <path>] [--device <device>] [--web] [--api-base <url>]"
            exit 1
            ;;
    esac
done

echo "Running Clinical Diary (LOCAL flavor) on device: ${DEVICE}"

# Stamp the bundled env pointer so `flutter run` targets local; restored on exit.
source "$SCRIPT_DIR/_write_env_pointer.sh" local

CMD="flutter run -d ${DEVICE}"

# flavorizr only knows dev/qa/uat/prod. For non-desktop/web targets we still
# need a native flavor; dev's bundle id and Firebase config are the closest fit.
if [[ "$DEVICE" != "chrome" && "$DEVICE" != "macos" && "$DEVICE" != "linux" && "$DEVICE" != "windows" ]]; then
    CMD="$CMD --flavor dev"
fi

if [[ -n "$API_BASE" ]]; then
    CMD="$CMD --dart-define=DIARY_API_BASE=${API_BASE}"
fi

if [[ -n "$IMPORT_FILE" ]]; then
    if [[ ! "$IMPORT_FILE" = /* ]]; then
        IMPORT_FILE="$(pwd)/$IMPORT_FILE"
    fi
    echo "Will import data from: $IMPORT_FILE"
    CMD="$CMD --dart-define=IMPORT_FILE=$IMPORT_FILE"
fi

echo "Command: doppler run -- $CMD"
echo ""

doppler run -- $CMD
