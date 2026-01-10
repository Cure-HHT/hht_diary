#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00006: Mobile App Build and Release Process

# Run the Clinical Diary app with UAT flavor
# Usage: ./tool/run_uat.sh [OPTIONS]
#
# Options:
#   --import-file <path>   Path to JSON export file to auto-import on startup
#   --device <device>      Device to run on (e.g., chrome, macos, iPhone)
#   --web                  Shortcut for --device chrome
#
# Examples:
#   ./tool/run_uat.sh                                           # Run on default device
#   ./tool/run_uat.sh --web                                     # Run on Chrome
#   ./tool/run_uat.sh --import-file ./test/data/export.json     # Run with test data
#   ./tool/run_uat.sh --device macos --import-file data.json    # Run on macOS with data

set -e

IMPORT_FILE=""
DEVICE=""

# Parse arguments
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
        *)
            echo "Unknown option: $1"
            echo "Usage: ./tool/run_uat.sh [--import-file <path>] [--device <device>] [--web]"
            exit 1
            ;;
    esac
done

echo "Running Clinical Diary (UAT flavor)..."

# Build the flutter run command
CMD="flutter run --dart-define=APP_FLAVOR=uat"

# Add device if specified
if [[ -n "$DEVICE" ]]; then
    CMD="$CMD -d $DEVICE"
    # Don't use --flavor on web
    if [[ "$DEVICE" != "chrome" ]]; then
        CMD="$CMD --flavor uat"
    fi
else
    # Default to using flavor for mobile devices
    CMD="$CMD --flavor uat"
fi

# Add import file if specified
if [[ -n "$IMPORT_FILE" ]]; then
    # Convert to absolute path if relative
    if [[ ! "$IMPORT_FILE" = /* ]]; then
        IMPORT_FILE="$(pwd)/$IMPORT_FILE"
    fi
    echo "Will import data from: $IMPORT_FILE"
    CMD="$CMD --dart-define=IMPORT_FILE=$IMPORT_FILE"
fi

echo "Command: doppler run -- $CMD"
echo ""

# Run with Doppler for secrets injection
doppler run -- $CMD
