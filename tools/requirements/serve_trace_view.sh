#!/bin/bash
# Generates traceability report with embedded content and serves it locally
# Usage: ./serve_traceability.sh [port]
#
# Uses trace_view (trace-view) to generate interactive HTML reports.
# When served locally, edit mode is enabled for batch moving requirements.
# The portable version (in git) does not include edit mode.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PORT="${1:-8080}"

# Get output directory from elspais config (uses traceability.output_dir)
OUTPUT_DIR_REL=$(elspais config show --json 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('traceability', {}).get('output_dir', 'build-reports/combined/traceability'))
except:
    print('build-reports/combined/traceability')
")
OUTPUT_DIR="$REPO_ROOT/$OUTPUT_DIR_REL"
OUTPUT_FILE="$OUTPUT_DIR/REQ-report.html"

mkdir -p "$OUTPUT_DIR"

echo "Generating traceability matrix with embedded content and edit mode..."
python3 "$SCRIPT_DIR/trace_view.py" --format html --embed-content --edit-mode --output "$OUTPUT_FILE"

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: Output file not generated at $OUTPUT_FILE"
    exit 1
fi

echo ""
echo "Starting server at http://localhost:$PORT/$OUTPUT_DIR_REL/REQ-report.html"
echo "Press Ctrl+C to stop"
echo ""

# Cache-busting timestamp
CACHE_BUST="?t=$(date +%s)"
URL="http://localhost:$PORT/$OUTPUT_DIR_REL/REQ-report.html${CACHE_BUST}"

# Open browser (works on Linux/macOS)
if command -v xdg-open &> /dev/null; then
    xdg-open "$URL" &
elif command -v open &> /dev/null; then
    open "$URL" &
fi

# Serve from repo root so spec/ links work
cd "$REPO_ROOT"
python3 -m http.server "$PORT"
