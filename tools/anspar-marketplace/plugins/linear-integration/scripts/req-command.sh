#!/bin/bash
# =====================================================
# req-command.sh
# =====================================================
#
# Implements /req and /requirement slash commands
# Provides requirement management and querying
#
# Usage:
#   /req                    # Show help
#   /req REQ-xxx            # Display requirement
#   /req search <term>      # Search requirements
#   /req new                # Create requirement guide
#   /req validate           # Validate requirements
#
# =====================================================

set -euo pipefail

# Find paths
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
    REPO_ROOT="$(cd "$PLUGIN_DIR/../../../.." && pwd)"
fi
SPEC_DIR="$REPO_ROOT/spec"
REQ_TOOLS_DIR="$REPO_ROOT/tools/requirements"

# =====================================================
# Parse Arguments
# =====================================================

COMMAND="${1:-}"
ARG2="${2:-}"

# =====================================================
# Case 1: No arguments - show help and recent reqs
# =====================================================

if [ -z "$COMMAND" ]; then
    cat <<EOF
📋 REQUIREMENT MANAGEMENT

Usage:
  /req REQ-xxx          Display requirement details
  /req search <term>    Search for requirements
  /req new              Guide for creating new requirement
  /req validate         Validate all requirements

Recent requirements (last 5):
EOF

    if [ -f "$SPEC_DIR/INDEX.md" ]; then
        tail -n 10 "$SPEC_DIR/INDEX.md" | grep "REQ-" | tail -n 5 || echo "  (none found)"
    else
        echo "  ⚠️  INDEX.md not found"
    fi

    echo
    echo "📁 Total requirements: $(grep -c "^| REQ-" "$SPEC_DIR/INDEX.md" 2>/dev/null || echo "unknown")"
    exit 0
fi

# =====================================================
# Case 2: REQ-xxx - display requirement
# =====================================================

if echo "$COMMAND" | grep -qE '^REQ-[pod][0-9]{5}$'; then
    REQ_ID="$COMMAND"

    echo "🔍 Looking up: $REQ_ID"
    echo

    # Find which file contains this requirement
    REQ_FILE=$(grep -l "^| $REQ_ID " "$SPEC_DIR/INDEX.md" 2>/dev/null | head -1 || echo "")

    if [ -z "$REQ_FILE" ]; then
        # Try grepping spec files directly
        REQ_FILE=$(grep -l "^# $REQ_ID:" "$SPEC_DIR"/*.md 2>/dev/null | head -1 || echo "")
    fi

    if [ -n "$REQ_FILE" ]; then
        # Extract requirement details from INDEX.md
        DETAILS=$(grep "^| $REQ_ID " "$SPEC_DIR/INDEX.md" 2>/dev/null || echo "")

        if [ -n "$DETAILS" ]; then
            echo "$DETAILS" | awk -F'|' '{
                printf "📌 %s\n", $2
                printf "📄 File: %s\n", $3
                printf "📝 Title: %s\n", $4
                printf "🔑 Hash: %s\n", $5
            }'
            echo
        fi

        # Try to extract the file name from INDEX.md
        FILE_NAME=$(echo "$DETAILS" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')

        if [ -n "$FILE_NAME" ] && [ -f "$SPEC_DIR/$FILE_NAME" ]; then
            echo "📖 Content:"
            echo "─────────────────────────────────────"
            # Show the requirement section
            sed -n "/^# $REQ_ID:/,/^# REQ-/p" "$SPEC_DIR/$FILE_NAME" | sed '$d' || \
            sed -n "/^## $REQ_ID:/,/^## REQ-/p" "$SPEC_DIR/$FILE_NAME" | sed '$d' || \
            sed -n "/^### $REQ_ID:/,/^### REQ-/p" "$SPEC_DIR/$FILE_NAME" | sed '$d' || \
            echo "Could not extract content"
        else
            echo "⚠️  Could not find file: $FILE_NAME"
        fi
    else
        echo "❌ Requirement not found: $REQ_ID"
        echo
        echo "💡 Try: /req search <keyword>"
        exit 1
    fi

    exit 0
fi

# =====================================================
# Case 3: search - search requirements
# =====================================================

if [ "$COMMAND" = "search" ]; then
    if [ -z "$ARG2" ]; then
        echo "❌ Usage: /req search <term>"
        exit 1
    fi

    SEARCH_TERM="$ARG2"

    echo "🔍 Searching requirements for: $SEARCH_TERM"
    echo

    # Search in spec files
    RESULTS=$(grep -i "$SEARCH_TERM" "$SPEC_DIR"/*.md 2>/dev/null | grep -E "^[^:]+:# REQ-" || echo "")

    if [ -n "$RESULTS" ]; then
        echo "Found in:"
        echo "$RESULTS" | while IFS=: read -r file content; do
            REQ_ID=$(echo "$content" | grep -oE "REQ-[pod][0-9]{5}" | head -1)
            FILE_BASE=$(basename "$file")
            echo "  📄 $FILE_BASE - $REQ_ID"
        done
    else
        echo "❌ No requirements found matching: $SEARCH_TERM"
    fi

    exit 0
fi

# =====================================================
# Case 4: new - create new requirement guide
# =====================================================

if [ "$COMMAND" = "new" ]; then
    cat <<EOF
📝 CREATE NEW REQUIREMENT

To create a new requirement:

1. **Claim a requirement number**:
   Go to GitHub → Actions → "Claim Requirement Number"
   This will assign you the next available REQ number

2. **Create the requirement file**:
   - PRD requirements: spec/prd-{topic}.md
   - Ops requirements: spec/ops-{topic}.md
   - Dev requirements: spec/dev-{topic}.md

3. **Use the standard format**:
   # REQ-{type}{number}: Title - TBD

   **Type**: [PRD/Ops/Dev]
   **Status**: [Proposed/Approved/Implemented]
   **Priority**: [High/Medium/Low]

   ## Overview
   [Description]

   ## Requirements
   - REQ-xxx.1: [sub-requirement]

   ## Implementation
   [Details]

4. **Update the hash**:
   python3 tools/requirements/update-REQ-hashes.py --req-id={number}

5. **Add to INDEX.md**:
   python3 tools/requirements/add-missing-to-index.py

6. **Validate**:
   python3 tools/requirements/validate_requirements.py

See spec/README.md for full documentation.
EOF
    exit 0
fi

# =====================================================
# Case 5: validate - run validation
# =====================================================

if [ "$COMMAND" = "validate" ]; then
    echo "🔍 Validating requirements..."
    echo

    if [ -f "$REQ_TOOLS_DIR/validate_requirements.py" ]; then
        python3 "$REQ_TOOLS_DIR/validate_requirements.py"
    else
        echo "❌ Validation script not found: $REQ_TOOLS_DIR/validate_requirements.py"
        exit 1
    fi

    exit 0
fi

# =====================================================
# Unknown command
# =====================================================

echo "❌ Unknown command: $COMMAND"
echo
echo "Usage:"
echo "  /req                    Show help"
echo "  /req REQ-xxx            Display requirement"
echo "  /req search <term>      Search requirements"
echo "  /req new                Create new requirement guide"
echo "  /req validate           Validate requirements"
exit 1
