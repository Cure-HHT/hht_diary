#!/bin/bash
# Generates traceability report with embedded content and serves it locally
# Usage: ./serve_trace_view.sh [port] [--review]
#
# Uses trace_view (trace-view) to generate interactive HTML reports.
# When served locally, edit mode is enabled for batch moving requirements.
# The portable version (in git) does not include edit mode.
#
# Options:
#   port      Port number (default: 8080)
#   --review  Enable review mode for collaborative spec reviews

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PORT="8080"
REVIEW_MODE=""

# Parse arguments
for arg in "$@"; do
    case $arg in
        --review)
            REVIEW_MODE="--review-mode"
            ;;
        [0-9]*)
            PORT="$arg"
            ;;
    esac
done

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

if [ -n "$REVIEW_MODE" ]; then
    echo "Generating traceability matrix with embedded content, edit mode, and review mode..."
else
    echo "Generating traceability matrix with embedded content and edit mode..."
fi
python3 "$SCRIPT_DIR/trace_view.py" --format html --embed-content --edit-mode $REVIEW_MODE --output "$OUTPUT_FILE"

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

if [ -n "$REVIEW_MODE" ]; then
    # Review mode: Use Flask API server for full functionality
    echo "Starting Review API server at http://localhost:$PORT"
    echo "Review features: comment threads, status requests, git sync"
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
    auto_sync=True,
    register_static_routes=False
)

# Serve static files from repo root
@app.route('/')
def index():
    return send_from_directory('$REPO_ROOT', '$OUTPUT_DIR_REL/REQ-report.html')

@app.route('/<path:path>')
def serve_static(path):
    return send_from_directory('$REPO_ROOT', path)

@app.route('/help/<path:filename>')
def serve_help(filename):
    help_dir = Path('$SCRIPT_DIR/trace_view/html/templates/partials/review/help')
    return send_from_directory(str(help_dir), filename)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=$PORT, debug=False)
" 2>&1
else
    # Edit mode: Use Flask server with apply-moves API
    echo "Starting Edit Mode server at http://localhost:$PORT"
    echo "Edit features: batch move requirements via Apply Moves button"
    echo ""

    # Open browser (works on Linux/macOS)
    if command -v xdg-open &> /dev/null; then
        xdg-open "$URL" &
    elif command -v open &> /dev/null; then
        open "$URL" &
    fi

    # Serve from repo root with Flask for API support
    cd "$REPO_ROOT"
    python3 -c "
import json
import subprocess
from pathlib import Path
from flask import Flask, send_from_directory, request, jsonify

app = Flask(__name__)
REPO_ROOT = Path('$REPO_ROOT')

@app.route('/')
def index():
    return send_from_directory(str(REPO_ROOT), '$OUTPUT_DIR_REL/REQ-report.html')

@app.route('/<path:path>')
def serve_static(path):
    return send_from_directory(str(REPO_ROOT), path)

@app.route('/api/apply-moves', methods=['POST'])
def apply_moves():
    '''Execute requirement moves via elspais edit --from-json'''
    try:
        moves = request.get_json()
        if not moves or not isinstance(moves, list):
            return jsonify({'success': False, 'error': 'Invalid moves data'}), 400

        # Convert to elspais format (reqId -> move-to mapping)
        elspais_moves = []
        for move in moves:
            req_id = move.get('reqId', '')
            target = move.get('target', '')
            if req_id and target:
                # elspais expects REQ- prefix
                if not req_id.startswith('REQ-'):
                    req_id = f'REQ-{req_id}'
                elspais_moves.append({
                    'req_id': req_id,
                    'move_to': target
                })

        if not elspais_moves:
            return jsonify({'success': False, 'error': 'No valid moves'}), 400

        # Run elspais edit --from-json with moves piped to stdin
        result = subprocess.run(
            ['elspais', 'edit', '--from-json', '-'],
            input=json.dumps(elspais_moves),
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT)
        )

        if result.returncode != 0:
            return jsonify({
                'success': False,
                'error': result.stderr or 'elspais edit failed',
                'stdout': result.stdout
            }), 500

        return jsonify({
            'success': True,
            'message': f'Moved {len(elspais_moves)} requirement(s)',
            'moves': elspais_moves,
            'stdout': result.stdout
        })

    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=$PORT, debug=False)
" 2>&1
fi
