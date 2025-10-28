#!/bin/bash
# Validate Docker environment warnings against expected baseline
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00032: Development Tool Specifications
#
# Usage: ./validate-warnings.sh [--role dev|qa|ops]

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ROLE="${1:-dev}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_DIR="./validation-reports"
REPORT_FILE="${REPORT_DIR}/warnings-${ROLE}-${TIMESTAMP}.txt"

mkdir -p "${REPORT_DIR}"

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}Docker Environment Warning Validation${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""
echo "Role: ${ROLE}"
echo "Timestamp: ${TIMESTAMP}"
echo "Report: ${REPORT_FILE}"
echo ""

# Expected warning patterns (from EXPECTED_WARNINGS.md)
declare -A EXPECTED_WARNINGS=(
    ["chrome_web"]="Chrome - develop for the web"
    ["linux_toolchain"]="Linux toolchain - develop for Linux desktop"
    ["android_studio"]="Android Studio.*not installed"
    ["cmdline_tools"]="Observed package id 'cmdline-tools;latest' in inconsistent location"
    ["npm_version"]="New major version of npm available"
)

# Capture warnings from dev image
echo -e "${BLUE}Running flutter doctor...${NC}"
docker run --rm "clinical-diary-${ROLE}:latest" bash -c "flutter doctor -v 2>&1" > "${REPORT_FILE}"

echo -e "${BLUE}Capturing Android SDK warnings...${NC}"
docker run --rm "clinical-diary-${ROLE}:latest" bash -c "sdkmanager --list 2>&1 | head -50" >> "${REPORT_FILE}"

echo ""
echo -e "${BLUE}Analyzing warnings...${NC}"
echo ""

# Check for expected warnings
FOUND_WARNINGS=()
UNEXPECTED_WARNINGS=()
MISSING_EXPECTED=()

# Mark all as missing initially
for key in "${!EXPECTED_WARNINGS[@]}"; do
    MISSING_EXPECTED+=("$key")
done

# Scan report for warnings
while IFS= read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Check if line contains a warning indicator
    if echo "$line" | grep -qE '^\[✗\]|^\[!\]|^Warning:|^npm notice'; then
        # Check against expected warnings
        IS_EXPECTED=false
        for key in "${!EXPECTED_WARNINGS[@]}"; do
            pattern="${EXPECTED_WARNINGS[$key]}"
            if echo "$line" | grep -qE "$pattern"; then
                FOUND_WARNINGS+=("$key: $line")
                # Remove from missing list
                MISSING_EXPECTED=("${MISSING_EXPECTED[@]/$key}")
                IS_EXPECTED=true
                break
            fi
        done

        if [ "$IS_EXPECTED" = false ]; then
            UNEXPECTED_WARNINGS+=("$line")
        fi
    fi
done < "${REPORT_FILE}"

# Report results
echo -e "${GREEN}✓ Expected Warnings Found: ${#FOUND_WARNINGS[@]}${NC}"
for warning in "${FOUND_WARNINGS[@]}"; do
    echo -e "  ${GREEN}•${NC} ${warning%%:*}"
done
echo ""

if [ ${#UNEXPECTED_WARNINGS[@]} -gt 0 ]; then
    echo -e "${RED}✗ UNEXPECTED WARNINGS DETECTED: ${#UNEXPECTED_WARNINGS[@]}${NC}"
    for warning in "${UNEXPECTED_WARNINGS[@]}"; do
        echo -e "  ${RED}✗${NC} $warning"
    done
    echo ""
    echo -e "${YELLOW}ACTION REQUIRED:${NC}"
    echo "  1. Investigate each unexpected warning"
    echo "  2. Assess FDA compliance impact"
    echo "  3. Add to EXPECTED_WARNINGS.md with justification OR fix the issue"
    echo ""
    exit 1
else
    echo -e "${GREEN}✓ No unexpected warnings detected${NC}"
    echo ""
fi

# Check if any expected warnings are missing (might indicate a fix or change)
MISSING_COUNT=0
for key in "${MISSING_EXPECTED[@]}"; do
    [[ -z "$key" ]] && continue
    MISSING_COUNT=$((MISSING_COUNT + 1))
done

if [ $MISSING_COUNT -gt 0 ]; then
    echo -e "${YELLOW}ℹ Expected warnings not found: ${MISSING_COUNT}${NC}"
    echo -e "${YELLOW}  (This may indicate fixes or environmental changes)${NC}"
    for key in "${MISSING_EXPECTED[@]}"; do
        [[ -z "$key" ]] && continue
        echo -e "  ${YELLOW}•${NC} $key: ${EXPECTED_WARNINGS[$key]}"
    done
    echo ""
fi

echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}Validation PASSED${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""
echo "Full report saved to: ${REPORT_FILE}"
echo ""
echo "To review expected warnings, see: EXPECTED_WARNINGS.md"
echo ""

exit 0
