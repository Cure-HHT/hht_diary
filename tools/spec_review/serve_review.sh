#!/bin/bash
# Serves traceability report with review mode enabled
# Usage: ./serve_review.sh [port] [--user username]
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
# Data is stored in .reviews/ directory and can be synced via git branches.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PORT="8080"
USERNAME="anonymous"

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
        [0-9]*)
            PORT="$1"
            shift
            ;;
        *)
            echo "Usage: $0 [port] [--user username]"
            exit 1
            ;;
    esac
done

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
python3 - "$OUTPUT_FILE" "$USERNAME" "$REPO_ROOT" << 'PYTHON_SCRIPT'
import sys
from pathlib import Path

output_file = Path(sys.argv[1])
username = sys.argv[2]
repo_root = Path(sys.argv[3])

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

# Generate embedded review data
review_data_js = generate_embedded_review_data(repo_root, req_ids)

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
        <input type="checkbox" id="review-mode-toggle" style="margin-right: 8px;">
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
echo "Data storage:"
echo "  - Review data is stored in: $REPO_ROOT/.reviews/"
echo "  - Use git branches for collaboration"
echo "  - CLI: python3 $SCRIPT_DIR/review_cli.py --help"
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

# Serve from repo root so spec/ links work
cd "$REPO_ROOT"
python3 -m http.server "$PORT"
