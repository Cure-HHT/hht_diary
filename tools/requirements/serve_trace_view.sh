#!/bin/bash
# Generates traceability report with embedded content and serves it locally
# Usage: ./serve_trace_view.sh [options] [port]
#
# Options:
#   --review    Enable review mode with Flask API server for full review functionality
#               (comment threads, status requests, git sync)
#   --edit      Enable edit mode only (default, uses simple HTTP server)
#
# Uses trace_view (trace-view) to generate interactive HTML reports.
# When served locally, edit mode is enabled for batch moving requirements.
# Review mode provides collaborative review features with the Flask API server.
# The portable version (in git) does not include edit/review mode.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
REVIEW_MODE=false
PORT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --review)
            REVIEW_MODE=true
            shift
            ;;
        --edit)
            REVIEW_MODE=false
            shift
            ;;
        *)
            PORT="$1"
            shift
            ;;
    esac
done

PORT="${PORT:-8080}"

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

if [ "$REVIEW_MODE" = true ]; then
    echo "Generating traceability matrix with embedded content and REVIEW mode..."
    python3 "$SCRIPT_DIR/trace_view.py" --format html --embed-content --review-mode --output "$OUTPUT_FILE"
else
    echo "Generating traceability matrix with embedded content and EDIT mode..."
    python3 "$SCRIPT_DIR/trace_view.py" --format html --embed-content --edit-mode --output "$OUTPUT_FILE"
fi

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: Output file not generated at $OUTPUT_FILE"
    exit 1
fi

echo ""

# Cache-busting timestamp
CACHE_BUST="?t=$(date +%s)"

if [ "$REVIEW_MODE" = true ]; then
    # Review mode: Use Flask API server for full functionality
    echo "Starting Review API server at http://localhost:$PORT"
    echo "Review features: comment threads, status requests, git sync"
    echo "Press Ctrl+C to stop"
    echo ""

    URL="http://localhost:$PORT/$OUTPUT_DIR_REL/REQ-report.html${CACHE_BUST}"

    # Open browser (works on Linux/macOS)
    if command -v xdg-open &> /dev/null; then
        xdg-open "$URL" &
    elif command -v open &> /dev/null; then
        open "$URL" &
    fi

    # Start Flask API server with static file serving
    cd "$REPO_ROOT"
    python3 -c "
from pathlib import Path
from flask import send_from_directory
from tools.requirements.trace_view.review.server import create_app

app = create_app(
    repo_root=Path('$REPO_ROOT'),
    auto_sync=True
)

# Serve static files from repo root
@app.route('/')
def index():
    return send_from_directory('$REPO_ROOT', '$OUTPUT_DIR_REL/REQ-report.html')

@app.route('/<path:path>')
def serve_static(path):
    return send_from_directory('$REPO_ROOT', path)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=$PORT, debug=False)
" 2>&1
else
    # Edit mode: Use simple HTTP server
    echo "Starting server at http://localhost:$PORT/$OUTPUT_DIR_REL/REQ-report.html"
    echo "Press Ctrl+C to stop"
    echo ""

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
fi
