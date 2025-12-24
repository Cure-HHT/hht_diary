#!/bin/bash
# Serves traceability report with review mode enabled
# Usage: ./serve_review.sh [--port PORT] [--user USERNAME] [--no-api]
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00092: HTML Report Integration
#   REQ-d00093: Review Mode Server
#
# Review mode enables:
# - Comment threads on requirements
# - Position-aware comments with fallback
# - Status change request workflow
# - Review flags for requirements
#
# Modes:
#   API (default):    Flask API server, comments persist to .reviews/
#   Static (--no-api): Simple HTTP server, comments in memory only
#
# Data is stored in .reviews/ directory and can be synced via git branches.
#
# API Endpoints (when using API mode):
#   GET  /api/health                                    - Health check
#   GET  /api/reviews                                   - Get all review data
#   GET  /api/reviews/reqs/<id>                         - Get review data for REQ
#   POST /api/reviews/reqs/<id>/threads                 - Create comment thread
#   POST /api/reviews/reqs/<id>/threads/<tid>/comments  - Add comment to thread
#   POST /api/reviews/reqs/<id>/threads/<tid>/resolve   - Resolve thread
#   POST /api/reviews/reqs/<id>/threads/<tid>/unresolve - Unresolve thread
#   GET  /api/reviews/reqs/<id>/flag                    - Get review flag
#   POST /api/reviews/reqs/<id>/flag                    - Set review flag
#   DELETE /api/reviews/reqs/<id>/flag                  - Clear review flag
#   GET  /api/reviews/reqs/<id>/requests                - Get status requests
#   POST /api/reviews/reqs/<id>/requests                - Create status request
#   POST /api/reviews/reqs/<id>/requests/<rid>/approvals - Add approval
#
# Requirements:
#   API mode requires Flask: pip install flask flask-cors

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PORT="8080"
USE_API=true  # API mode is the default

# Default username from git config, fallback to system user, then "anonymous"
USERNAME=$(git config user.name 2>/dev/null || echo "")
if [ -z "$USERNAME" ]; then
    USERNAME="${USER:-anonymous}"
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --user)
            USERNAME="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --no-api)
            USE_API=false
            shift
            ;;
        [0-9]*)
            PORT="$1"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--port PORT] [--user USERNAME] [--no-api]"
            echo ""
            echo "Serves the spec review report with comment/review functionality."
            echo ""
            echo "Options:"
            echo "  --port PORT    Port to serve on (default: 8080)"
            echo "  --user NAME    Your username for comments (default: git user.name)"
            echo "  --no-api       Use simple HTTP server (comments don't persist)"
            echo "  -h, --help     Show this help message"
            echo ""
            echo "By default, uses Flask API server for comment persistence."
            echo "Comments are saved to .reviews/ directory."
            echo ""
            echo "Requirements:"
            echo "  pip install flask flask-cors"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Check if port is already in use
check_port_in_use() {
    local port=$1
    # Try multiple methods to check port availability
    if command -v ss &> /dev/null; then
        ss -tuln 2>/dev/null | grep -q ":${port} " && return 0
    elif command -v netstat &> /dev/null; then
        netstat -tuln 2>/dev/null | grep -q ":${port} " && return 0
    elif command -v lsof &> /dev/null; then
        lsof -i ":${port}" &> /dev/null && return 0
    else
        # Fallback: try to connect to the port
        (echo > /dev/tcp/localhost/${port}) 2>/dev/null && return 0
    fi
    return 1
}

if check_port_in_use "$PORT"; then
    echo "Error: Port $PORT is already in use."
    echo ""
    echo "To fix this, either:"
    echo "  1. Stop the process using port $PORT:"
    echo "     lsof -i :$PORT    # Find the process"
    echo "     kill <PID>        # Stop it"
    echo ""
    echo "  2. Use a different port:"
    echo "     $0 --port 8081 --user $USERNAME"
    echo ""
    exit 1
fi

# Output location
OUTPUT_DIR="$REPO_ROOT/validation-reports"
OUTPUT_FILE="$OUTPUT_DIR/REQ-report-review.html"

mkdir -p "$OUTPUT_DIR"

echo "======================================"
echo "  Spec Review Mode"
echo "======================================"
echo ""
echo "User: $USERNAME"
echo "Port: $PORT"
if [ "$USE_API" = true ]; then
    echo "Mode: API (comments persist to .reviews/)"
else
    echo "Mode: Static (comments in memory only)"
fi
echo ""

# Generate the base report
echo "Generating traceability matrix..."
python3 "$REPO_ROOT/tools/requirements/generate_traceability.py" \
    --format html \
    --embed-content \
    --edit-mode \
    --output "$OUTPUT_FILE"

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "Error: Output file not generated at $OUTPUT_FILE"
    exit 1
fi

# Inject review system assets
echo "Injecting review system..."
STATIC_MODE="true"
if [ "$USE_API" = true ]; then
    STATIC_MODE="false"
fi

python3 - "$OUTPUT_FILE" "$USERNAME" "$REPO_ROOT" "$STATIC_MODE" << 'PYTHON_SCRIPT'
import sys
from pathlib import Path

output_file = Path(sys.argv[1])
username = sys.argv[2]
repo_root = Path(sys.argv[3])
static_mode = sys.argv[4].lower() == 'true'

# Add spec_review to path
sys.path.insert(0, str(repo_root / 'tools'))

from spec_review.review_integration import (
    get_review_css,
    get_review_js_content,
    get_review_init_js,
    generate_embedded_review_data,
    get_review_mode_toggle_html,
)
from spec_review.review_data import get_reqs_dir
from spec_review.review_storage import list_sessions

# Read the existing HTML
html = output_file.read_text()

# Find all REQ IDs in the document
import re
req_pattern = r'data-req-id="([pod]\d{5})"'
req_ids = list(set(re.findall(req_pattern, html)))
print(f"Found {len(req_ids)} requirements in report")

# Generate embedded review data (static_mode disables push features)
review_data_js = generate_embedded_review_data(repo_root, req_ids, static_mode=static_mode)

# Get CSS and JS content
review_css = get_review_css()
review_js = get_review_js_content()
init_js = get_review_init_js(username)
toggle_html = get_review_mode_toggle_html()

# Inject CSS before </head> - only replace FIRST occurrence (the actual HTML tag)
# Requirement bodies might contain </head> in examples
css_injection = f"<style id='review-system-css'>\n{review_css}\n</style>\n</head>"
html = html.replace("</head>", css_injection, 1)

# Inject review data and JS before </body> - only replace LAST occurrence
# Requirement bodies might contain </body> in examples
js_injection = f"""
<script id="review-data">
{review_data_js}
</script>
<script id="review-system-js">
{review_js}
</script>
<script id="review-init-js">
{init_js}
</script>
</body>"""
# Find last </body> and replace only that one
last_body_idx = html.rfind("</body>")
if last_body_idx >= 0:
    html = html[:last_body_idx] + js_injection
else:
    html = html.replace("</body>", js_injection, 1)

# Inject toggle button after Edit Mode button
# Create toggle HTML that matches the Edit Mode button style
review_toggle_html = '''<span style="margin-left: 20px; border-left: 1px solid #ccc; padding-left: 20px;">
    <label style="display: inline-flex; align-items: center; cursor: pointer;">
        <input type="checkbox" id="review-mode-toggle" style="margin-right: 8px;" checked>
        <span class="btn toggle-btn" style="pointer-events: none;">👁️ Review Mode</span>
    </label>
</span>'''

# Find the Edit Mode button span and insert after it
edit_mode_marker = 'id="btnEditMode"'
if edit_mode_marker in html:
    idx = html.find(edit_mode_marker)
    # Find the closing </span> after the button
    close_span_idx = html.find('</span>', idx)
    if close_span_idx > 0:
        insert_point = close_span_idx + len('</span>')
        html = html[:insert_point] + review_toggle_html + html[insert_point:]
        print("Review mode toggle injected after Edit Mode button")

# Write modified HTML
output_file.write_text(html)
print(f"Review system injected into {output_file}")
PYTHON_SCRIPT

echo ""
echo "======================================"
echo "  Starting Review Server"
echo "======================================"
echo ""
echo "Report URL: http://localhost:$PORT/validation-reports/REQ-report-review.html"
echo ""
echo "Review features:"
echo "  - Toggle 'Review Mode' checkbox in the header"
echo "  - Click on requirements to see/add comments"
echo "  - Comments support line/block/word positions"
echo "  - Request status changes with approval workflow"
echo ""
if [ "$USE_API" = true ]; then
    echo "API Mode:"
    echo "  - Comments persist automatically to .reviews/"
    echo "  - Changes saved in real-time"
else
    echo "Static Mode:"
    echo "  - Comments only live in browser memory"
    echo "  - Use CLI for persistence: python3 $SCRIPT_DIR/review_cli.py --help"
    echo "  - Restart with --api flag for persistence"
fi
echo ""
echo "Data storage:"
echo "  - Review data is stored in: $REPO_ROOT/.reviews/"
echo "  - Use git branches for collaboration"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Cache-busting timestamp
CACHE_BUST="?t=$(date +%s)"
URL="http://localhost:$PORT/validation-reports/REQ-report-review.html${CACHE_BUST}"

# Open browser (works on Linux/macOS)
if command -v xdg-open &> /dev/null; then
    xdg-open "$URL" &
elif command -v open &> /dev/null; then
    open "$URL" &
fi

# Start the appropriate server
cd "$REPO_ROOT"
if [ "$USE_API" = true ]; then
    # Check for Flask
    if ! python3 -c "import flask" 2>/dev/null; then
        echo ""
        echo "========================================"
        echo "  Flask Not Installed"
        echo "========================================"
        echo ""
        echo "API mode requires Flask. Install it with:"
        echo ""
        echo "  pip install flask flask-cors"
        echo ""
        echo "Or use static mode (comments won't persist):"
        echo ""
        echo "  $0 --no-api"
        echo ""
        exit 1
    fi
    # Check for flask-cors
    if ! python3 -c "import flask_cors" 2>/dev/null; then
        echo ""
        echo "========================================"
        echo "  flask-cors Not Installed"
        echo "========================================"
        echo ""
        echo "API mode requires flask-cors. Install it with:"
        echo ""
        echo "  pip install flask-cors"
        echo ""
        exit 1
    fi
    python3 "$SCRIPT_DIR/review_server.py" --port "$PORT" --repo "$REPO_ROOT"
else
    python3 -m http.server "$PORT"
fi
