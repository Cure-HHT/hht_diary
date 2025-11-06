#!/bin/bash
# =====================================================
# parse-req-refs.sh
# =====================================================
#
# Parses requirement references (REQ-*) from text input.
# This is a reusable utility for extracting REQ references
# from any text source (tickets, files, commit messages, etc.)
#
# Usage:
#   echo "text" | ./parse-req-refs.sh [OPTIONS]
#   ./parse-req-refs.sh [OPTIONS] < file.txt
#   ./parse-req-refs.sh [OPTIONS] --text "Some text with REQ-p00042"
#
# Options:
#   --format=json       Output as JSON array (default)
#   --format=csv        Output as comma-separated list
#   --format=lines      Output one per line
#   --format=human      Output human-readable format
#   --text="..."        Parse from command-line argument instead of stdin
#   --unique            Remove duplicates (default: true)
#   --no-unique         Keep duplicates
#   --sort              Sort results (default: false)
#   --help              Show this help message
#
# REQ Format:
#   REQ-{type}{number}
#   - type: p (PRD), o (Ops), d (Dev)
#   - number: 5 digits (e.g., 00042)
#
# Examples:
#   # From stdin
#   echo "Implements REQ-p00042 and REQ-d00027" | ./parse-req-refs.sh
#
#   # From file
#   ./parse-req-refs.sh < ticket-description.txt
#
#   # From command line
#   ./parse-req-refs.sh --text "Fix REQ-o00015"
#
#   # Different formats
#   ./parse-req-refs.sh --format=csv < file.txt
#   ./parse-req-refs.sh --format=lines --sort < file.txt
#
# Exit codes:
#   0  Success (even if no matches found)
#   1  Invalid arguments
#
# =====================================================

set -e

# =====================================================
# Arguments
# =====================================================

FORMAT="json"
TEXT=""
UNIQUE=true
SORT_OUTPUT=false
SHOW_HELP=false

while [ $# -gt 0 ]; do
    case $1 in
        --format=*)
            FORMAT="${1#*=}"
            shift
            ;;
        --text=*)
            TEXT="${1#*=}"
            shift
            ;;
        --unique)
            UNIQUE=true
            shift
            ;;
        --no-unique)
            UNIQUE=false
            shift
            ;;
        --sort)
            SORT_OUTPUT=true
            shift
            ;;
        --help)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "❌ ERROR: Unknown option: $1" >&2
            echo "   Run with --help for usage" >&2
            exit 1
            ;;
    esac
done

# =====================================================
# Help
# =====================================================

if [ "$SHOW_HELP" = true ]; then
    cat << 'EOF'
parse-req-refs.sh - Parse requirement references from text

Extracts REQ-* references from text input using the format:
  REQ-{type}{number}
  - type: p (PRD), o (Ops), d (Dev)
  - number: 5 digits (e.g., 00042)

Usage:
  echo "text" | ./parse-req-refs.sh [OPTIONS]
  ./parse-req-refs.sh [OPTIONS] < file.txt
  ./parse-req-refs.sh [OPTIONS] --text "Some text"

Options:
  --format=json       Output as JSON array (default)
  --format=csv        Output as comma-separated list
  --format=lines      Output one per line
  --format=human      Output human-readable format
  --text="..."        Parse from command-line argument
  --unique            Remove duplicates (default: true)
  --no-unique         Keep duplicates
  --sort              Sort results (default: false)
  --help              Show this help message

Examples:
  # Basic usage
  echo "Implements REQ-p00042 and REQ-d00027" | ./parse-req-refs.sh

  # From file
  ./parse-req-refs.sh < ticket-description.txt

  # CSV format for commit messages
  ./parse-req-refs.sh --format=csv --text "Fix REQ-o00015"

  # Sorted list
  ./parse-req-refs.sh --format=lines --sort < file.txt

Output Examples:
  json:   ["REQ-p00042","REQ-d00027"]
  csv:    REQ-p00042, REQ-d00027
  lines:  REQ-p00042
          REQ-d00027
  human:  Found 2 requirement references:
          - REQ-p00042 (PRD requirement)
          - REQ-d00027 (Dev requirement)
EOF
    exit 0
fi

# Validate format
if [[ "$FORMAT" != "json" && "$FORMAT" != "csv" && "$FORMAT" != "lines" && "$FORMAT" != "human" ]]; then
    echo "❌ ERROR: Invalid format: $FORMAT" >&2
    echo "   Expected: json, csv, lines, or human" >&2
    exit 1
fi

# =====================================================
# Get Input Text
# =====================================================

if [ -n "$TEXT" ]; then
    INPUT_TEXT="$TEXT"
else
    # Read from stdin
    INPUT_TEXT=$(cat)
fi

# =====================================================
# Extract REQ References
# =====================================================

# Extract all REQ references matching the pattern: REQ-{p|o|d}{5 digits}
REFS=$(echo "$INPUT_TEXT" | grep -oE 'REQ-[pdo][0-9]{5}' || true)

if [ -z "$REFS" ]; then
    # No matches found - output empty based on format
    case $FORMAT in
        json)
            echo "[]"
            ;;
        csv)
            echo ""
            ;;
        lines)
            echo ""
            ;;
        human)
            echo "No requirement references found"
            ;;
    esac
    exit 0
fi

# =====================================================
# Process Results
# =====================================================

# Remove duplicates if requested
if [ "$UNIQUE" = true ]; then
    REFS=$(echo "$REFS" | sort -u)
fi

# Sort if requested (only if not already sorted by unique)
if [ "$SORT_OUTPUT" = true ] && [ "$UNIQUE" = false ]; then
    REFS=$(echo "$REFS" | sort)
fi

# =====================================================
# Format Output
# =====================================================

case $FORMAT in
    json)
        echo "$REFS" | jq -R . | jq -s .
        ;;

    csv)
        echo "$REFS" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g'
        ;;

    lines)
        echo "$REFS"
        ;;

    human)
        COUNT=$(echo "$REFS" | wc -l)
        echo "Found $COUNT requirement reference(s):"
        echo "$REFS" | while IFS= read -r ref; do
            TYPE=$(echo "$ref" | sed -E 's/REQ-([pdo]).*/\1/')
            case $TYPE in
                p) TYPE_NAME="PRD" ;;
                o) TYPE_NAME="Ops" ;;
                d) TYPE_NAME="Dev" ;;
            esac
            echo "  - $ref ($TYPE_NAME requirement)"
        done
        ;;
esac

exit 0
