#!/usr/bin/env bash
# =====================================================
# Doppler Secret Dump for Offline Development
# =====================================================
#
# Dumps Doppler secrets to a local .env file for offline use.
# The generated file is gitignored and should never be committed.
#
# Usage:
#   ./tool/doppler-dump.sh              # Dump 'dev' environment (default)
#   ./tool/doppler-dump.sh --env qa     # Dump 'qa' environment
#   ./tool/doppler-dump.sh --help       # Show help
#
# After dumping, run offline with:
#   ./tool/run_local.sh --offline --reset
#
# =====================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.offline"

# Default environment
DOPPLER_ENV="dev"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --env)
            shift
            DOPPLER_ENV="$1"
            shift
            ;;
        --env=*)
            DOPPLER_ENV="${arg#*=}"
            shift
            ;;
        --help|-h)
            echo "Doppler Secret Dump for Offline Development"
            echo ""
            echo "Usage: ./tool/doppler-dump.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --env ENV    Doppler environment to dump (default: dev)"
            echo "               Available: dev, qa, uat, prod"
            echo "  --help, -h   Show this help message"
            echo ""
            echo "Output: $ENV_FILE"
            echo ""
            echo "After dumping secrets, run offline with:"
            echo "  ./tool/run_local.sh --offline --reset"
            echo ""
            echo "SECURITY NOTE:"
            echo "  The generated .env.offline file contains secrets!"
            echo "  It is gitignored and should NEVER be committed."
            exit 0
            ;;
    esac
done

echo "=========================================="
echo "  Doppler Secret Dump"
echo "=========================================="
echo ""
echo "Environment: $DOPPLER_ENV"
echo "Output file: $ENV_FILE"
echo ""

# Check if doppler is available
if ! command -v doppler &> /dev/null; then
    echo "ERROR: doppler CLI not found"
    echo "Install: https://docs.doppler.com/docs/install-cli"
    exit 1
fi

# Dump secrets to .env format
echo "Fetching secrets from Doppler..."
doppler secrets download --config "$DOPPLER_ENV" --format env --no-file > "$ENV_FILE"

# Add metadata header
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TEMP_FILE=$(mktemp)
cat > "$TEMP_FILE" << EOF
# =====================================================
# Doppler Secrets Dump - OFFLINE USE ONLY
# =====================================================
# Generated: $TIMESTAMP
# Environment: $DOPPLER_ENV
#
# WARNING: This file contains secrets!
# - Do NOT commit this file to git
# - Do NOT share this file
# - Regenerate periodically for fresh secrets
#
# Usage: ./tool/run_local.sh --offline
# =====================================================

EOF
cat "$ENV_FILE" >> "$TEMP_FILE"
mv "$TEMP_FILE" "$ENV_FILE"

# Set restrictive permissions
chmod 600 "$ENV_FILE"

echo ""
echo "SUCCESS: Secrets dumped to $ENV_FILE"
echo ""
echo "To run offline:"
echo "  ./tool/run_local.sh --offline --reset"
echo ""
echo "REMINDER: This file is gitignored. Never commit secrets!"
