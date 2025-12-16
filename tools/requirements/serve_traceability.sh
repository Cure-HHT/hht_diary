#!/bin/bash
# Generates traceability report with embedded content and serves it locally
# Usage: ./serve_traceability.sh [port]
#
# When served locally, edit mode is enabled for batch moving requirements.
# The portable version (in git) does not include edit mode.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PORT="${1:-8080}"

# Output location
OUTPUT_DIR="$REPO_ROOT/validation-reports"
OUTPUT_FILE="$OUTPUT_DIR/REQ-report.html"

mkdir -p "$OUTPUT_DIR"

echo "Generating traceability matrix with embedded content and edit mode..."
python3 "$SCRIPT_DIR/generate_traceability.py" --format html --embed-content --edit-mode --output "$OUTPUT_FILE"

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: Output file not generated at $OUTPUT_FILE"
    exit 1
fi

echo ""
echo "Starting server at http://localhost:$PORT/validation-reports/REQ-report.html"
echo "Press Ctrl+C to stop"
echo ""

# Cache-busting timestamp
CACHE_BUST="?t=$(date +%s)"
URL="http://localhost:$PORT/validation-reports/REQ-report.html${CACHE_BUST}"

# Open browser (works on Linux/macOS)
if command -v xdg-open &> /dev/null; then
    xdg-open "$URL" &
elif command -v open &> /dev/null; then
    open "$URL" &
fi

# Serve from repo root so spec/ links work
cd "$REPO_ROOT"
python3 -m http.server "$PORT"
