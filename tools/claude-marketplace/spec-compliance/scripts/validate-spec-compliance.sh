#!/bin/bash
# =====================================================
# Spec Compliance Validation Script
# =====================================================
#
# Validates spec/ files against compliance rules defined in spec/README.md
#
# Usage:
#   ./validate-spec-compliance.sh [file1.md file2.md ...]
#
# If no files specified, validates all spec/*.md files
#
# Exit codes:
#   0 = All validations passed
#   1 = Validation failures found
#   2 = Script error (missing dependencies, etc.)
#
# =====================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SPEC_DIR="spec"
SPEC_README="spec/README.md"
REQUIREMENTS_FORMAT="spec/requirements-format.md"

# Validation counters
TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0
TOTAL_VIOLATIONS=0

# =====================================================
# Functions
# =====================================================

# Check if file follows naming convention
validate_naming() {
    local file="$1"
    local basename=$(basename "$file")

    # Pattern: {audience}-{topic}(-{subtopic}).md
    # Valid audiences: prd-, ops-, dev-
    if [[ ! "$basename" =~ ^(prd|ops|dev)-[a-zA-Z0-9_-]+\.md$ ]]; then
        echo -e "${RED}  ❌ Invalid filename format: $basename${NC}"
        echo "     Expected: {audience}-{topic}(-{subtopic}).md"
        echo "     Valid audiences: prd-, ops-, dev-"
        return 1
    fi

    return 0
}

# Check PRD files for code blocks
validate_prd_no_code() {
    local file="$1"
    local basename=$(basename "$file")

    # Only check prd- files
    if [[ ! "$basename" =~ ^prd- ]]; then
        return 0
    fi

    local violations=0

    # Check for code blocks with language tags
    # Allowed: plain ``` blocks (ASCII diagrams)
    # Forbidden: ```sql, ```javascript, ```bash, etc.
    local code_blocks=$(grep -n '```[a-z]' "$file" || true)

    if [ -n "$code_blocks" ]; then
        echo -e "${RED}  ❌ PRD file contains code blocks (forbidden)${NC}"
        echo "     File: $file"
        echo ""
        echo "$code_blocks" | while IFS=: read -r line_num line_content; do
            echo "     Line $line_num: $line_content"
        done
        echo ""
        echo "     Action: Remove all code blocks with language tags"
        echo "     Run: claude /remove-prd-code"
        echo "     See: spec/README.md (Audience Scope Rules)"
        violations=$((violations + 1))
    fi

    # Check for inline code that looks like implementation
    # This is a heuristic - looking for patterns like:
    # - SQL keywords in inline code
    # - Function calls with parentheses
    # - API endpoint paths
    local suspicious_inline=$(grep -n '`[^`]*\(SELECT\|INSERT\|UPDATE\|DELETE\|CREATE\|function\|\.get(\|\.post(\|/api/\)[^`]*`' "$file" || true)

    if [ -n "$suspicious_inline" ]; then
        echo -e "${YELLOW}  ⚠️  PRD file may contain implementation details in inline code${NC}"
        echo "     File: $file"
        echo ""
        echo "$suspicious_inline" | head -5 | while IFS=: read -r line_num line_content; do
            echo "     Line $line_num: ${line_content:0:80}..."
        done
        if [ $(echo "$suspicious_inline" | wc -l) -gt 5 ]; then
            echo "     ... and $(($(echo "$suspicious_inline" | wc -l) - 5)) more"
        fi
        echo ""
        echo "     Review these lines to ensure they describe WHAT, not HOW"
        echo "     See: spec/README.md (Audience Scope Rules)"
        # Warning, not error - don't increment violations
    fi

    if [ $violations -gt 0 ]; then
        return 1
    fi

    return 0
}

# Check requirement format
validate_requirement_format() {
    local file="$1"

    # Check for requirements (### REQ-{level}{number})
    local requirements=$(grep -n '^### REQ-' "$file" || true)

    if [ -z "$requirements" ]; then
        # No requirements in file, skip validation
        return 0
    fi

    local violations=0

    echo "$requirements" | while IFS=: read -r line_num line_content; do
        # Pattern: ### REQ-{p|o|d}00{number}: Title
        if [[ ! "$line_content" =~ ^###\ REQ-[pod][0-9]{5}:\ .+ ]]; then
            echo -e "${RED}  ❌ Invalid requirement format at line $line_num${NC}"
            echo "     Found: $line_content"
            echo "     Expected: ### REQ-{p|o|d}00XXX: Title"
            echo "     See: spec/requirements-format.md"
            violations=$((violations + 1))
        fi
    done

    if [ $violations -gt 0 ]; then
        return 1
    fi

    return 0
}

# Validate a single file
validate_file() {
    local file="$1"

    if [ ! -f "$file" ]; then
        echo -e "${RED}  ❌ File not found: $file${NC}"
        return 1
    fi

    local file_violations=0

    echo -e "${BLUE}Validating: $file${NC}"

    # Run all validations
    validate_naming "$file" || file_violations=$((file_violations + 1))
    validate_prd_no_code "$file" || file_violations=$((file_violations + 1))
    validate_requirement_format "$file" || file_violations=$((file_violations + 1))

    if [ $file_violations -eq 0 ]; then
        echo -e "${GREEN}  ✅ Passed${NC}"
        PASSED_FILES=$((PASSED_FILES + 1))
    else
        echo -e "${RED}  ❌ Failed with $file_violations violation(s)${NC}"
        FAILED_FILES=$((FAILED_FILES + 1))
        TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + file_violations))
    fi

    echo ""

    return $file_violations
}

# =====================================================
# Main
# =====================================================

# Check dependencies
if [ ! -f "$SPEC_README" ]; then
    echo -e "${RED}ERROR: spec/README.md not found${NC}"
    echo "This script must be run from the repository root."
    exit 2
fi

# Get files to validate
FILES_TO_VALIDATE=()

if [ $# -eq 0 ]; then
    # No arguments - validate all spec/*.md files
    while IFS= read -r file; do
        FILES_TO_VALIDATE+=("$file")
    done < <(find "$SPEC_DIR" -maxdepth 1 -name '*.md' -not -name 'README.md' -not -name 'requirements-format.md')
else
    # Validate specified files
    FILES_TO_VALIDATE=("$@")
fi

if [ ${#FILES_TO_VALIDATE[@]} -eq 0 ]; then
    echo "No spec/ files to validate"
    exit 0
fi

TOTAL_FILES=${#FILES_TO_VALIDATE[@]}

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Spec Compliance Validation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Validating $TOTAL_FILES file(s)..."
echo ""

# Validate each file
EXIT_CODE=0
for file in "${FILES_TO_VALIDATE[@]}"; do
    validate_file "$file" || EXIT_CODE=1
done

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Total files:      $TOTAL_FILES"
echo -e "Passed:           ${GREEN}$PASSED_FILES${NC}"

if [ $FAILED_FILES -gt 0 ]; then
    echo -e "Failed:           ${RED}$FAILED_FILES${NC}"
    echo -e "Total violations: ${RED}$TOTAL_VIOLATIONS${NC}"
else
    echo -e "Failed:           $FAILED_FILES"
fi

echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ All validations passed!${NC}"
else
    echo -e "${RED}❌ Validation failed. Fix violations before committing.${NC}"
    echo ""
    echo "Resources:"
    echo "  - Compliance rules: spec/README.md"
    echo "  - Requirement format: spec/requirements-format.md"
    echo "  - Remove PRD code: claude /remove-prd-code"
fi

echo ""

exit $EXIT_CODE
