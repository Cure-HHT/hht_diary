#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00028: Role-Based Environment Separation
#   REQ-d00031: Automated QA Testing
#   REQ-d00033: FDA Validation Documentation
#
# Clinical Diary QA Test Runner
# Comprehensive test suite runner for local development and CI/CD
#
# Usage:
#   qa-runner.sh              # Run all tests
#   qa-runner.sh unit         # Run only unit tests
#   qa-runner.sh integration  # Run only integration tests
#   qa-runner.sh e2e          # Run only E2E tests
#
# Environment Variables:
#   TEST_SUITE    - Test suite to run (all, unit, integration, e2e)
#   PR_NUMBER     - Pull request number (for CI)
#   COMMIT_SHA    - Commit SHA (for CI)
#   REPORT_DIR    - Directory for test reports (default: /workspace/reports)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TEST_SUITE="${TEST_SUITE:-${1:-all}}"
REPORT_DIR="${REPORT_DIR:-/workspace/reports}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
if [ -z "$REPO_DIR" ]; then
  REPO_DIR="/workspace/repos/daily-diary/clinical_diary"
fi

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# ============================================================
# Helper Functions
# ============================================================

info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

success() {
  echo -e "${GREEN}✓${NC} $1"
}

warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

error() {
  echo -e "${RED}✗${NC} $1"
}

# ============================================================
# Setup
# ============================================================

setup_environment() {
  info "Setting up QA test environment..."

  # Create report directories
  mkdir -p "$REPORT_DIR"/{flutter,playwright,coverage,screenshots,pdfs}

  # Initialize summary file
  cat > "$REPORT_DIR/test-summary.md" <<EOF
# QA Test Suite Results

**Test Suite**: $TEST_SUITE
**Timestamp**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Commit**: ${COMMIT_SHA:-N/A}
**PR**: ${PR_NUMBER:-N/A}

---

EOF

  success "Environment setup complete"
}

# ============================================================
# Flutter Tests
# ============================================================

run_flutter_unit_tests() {
  info "Running Flutter unit tests..."

  if [ ! -f "$REPO_DIR/pubspec.yaml" ]; then
    warning "No Flutter pubspec.yaml found in $REPO_DIR, skipping Flutter tests"
    echo "- **Flutter Unit Tests**: Skipped (no Flutter project)" >> "$REPORT_DIR/test-summary.md"
    return 0
  fi

  cd "$REPO_DIR"

  # Get dependencies
  flutter pub get

  # Run tests with coverage
  if flutter test --coverage --reporter json > "$REPORT_DIR/flutter/test-results.json" 2>&1; then
    success "Flutter unit tests passed"

    # Parse results
    local passed=$(grep -c '"result":"success"' "$REPORT_DIR/flutter/test-results.json" || echo "0")
    local failed=$(grep -c '"result":"error"' "$REPORT_DIR/flutter/test-results.json" || echo "0")

    TESTS_RUN=$((TESTS_RUN + passed + failed))
    TESTS_PASSED=$((TESTS_PASSED + passed))
    TESTS_FAILED=$((TESTS_FAILED + failed))

    # Copy coverage
    if [ -f "coverage/lcov.info" ]; then
      cp coverage/lcov.info "$REPORT_DIR/coverage/"
    fi

    echo "- **Flutter Unit Tests**: ✅ PASSED ($passed passed, $failed failed)" >> "$REPORT_DIR/test-summary.md"
    return 0
  else
    error "Flutter unit tests failed"
    echo "- **Flutter Unit Tests**: ❌ FAILED" >> "$REPORT_DIR/test-summary.md"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

run_flutter_integration_tests() {
  info "Running Flutter integration tests..."

  if [ ! -d "$REPO_DIR/integration_test" ]; then
    warning "No integration tests found, skipping"
    echo "- **Flutter Integration Tests**: Skipped (no tests found)" >> "$REPORT_DIR/test-summary.md"
    return 0
  fi

  cd "$REPO_DIR"

  # Run integration tests
  if flutter test integration_test/ --reporter json > "$REPORT_DIR/flutter/integration-results.json" 2>&1; then
    success "Flutter integration tests passed"

    local passed=$(grep -c '"result":"success"' "$REPORT_DIR/flutter/integration-results.json" || echo "0")
    local failed=$(grep -c '"result":"error"' "$REPORT_DIR/flutter/integration-results.json" || echo "0")

    TESTS_RUN=$((TESTS_RUN + passed + failed))
    TESTS_PASSED=$((TESTS_PASSED + passed))
    TESTS_FAILED=$((TESTS_FAILED + failed))

    echo "- **Flutter Integration Tests**: ✅ PASSED ($passed passed, $failed failed)" >> "$REPORT_DIR/test-summary.md"
    return 0
  else
    error "Flutter integration tests failed"
    echo "- **Flutter Integration Tests**: ❌ FAILED" >> "$REPORT_DIR/test-summary.md"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# ============================================================
# Playwright Tests
# ============================================================

run_playwright_tests() {
  info "Running Playwright E2E tests..."

  if [ ! -d "$REPO_DIR/tests" ] && [ ! -d "$REPO_DIR/e2e" ]; then
    warning "No Playwright tests found, skipping"
    echo "- **Playwright E2E Tests**: Skipped (no tests found)" >> "$REPORT_DIR/test-summary.md"
    return 0
  fi

  cd "$REPO_DIR"

  # Run Playwright tests
  if npx playwright test --reporter=json,html > "$REPORT_DIR/playwright/results.json" 2>&1; then
    success "Playwright E2E tests passed"

    # Copy HTML report
    if [ -d "playwright-report" ]; then
      cp -r playwright-report "$REPORT_DIR/playwright/"
    fi

    # Parse results from JSON
    local passed=$(grep -o '"status":"passed"' "$REPORT_DIR/playwright/results.json" | wc -l || echo "0")
    local failed=$(grep -o '"status":"failed"' "$REPORT_DIR/playwright/results.json" | wc -l || echo "0")
    local skipped=$(grep -o '"status":"skipped"' "$REPORT_DIR/playwright/results.json" | wc -l || echo "0")

    TESTS_RUN=$((TESTS_RUN + passed + failed))
    TESTS_PASSED=$((TESTS_PASSED + passed))
    TESTS_FAILED=$((TESTS_FAILED + failed))
    TESTS_SKIPPED=$((TESTS_SKIPPED + skipped))

    echo "- **Playwright E2E Tests**: ✅ PASSED ($passed passed, $failed failed, $skipped skipped)" >> "$REPORT_DIR/test-summary.md"
    return 0
  else
    error "Playwright E2E tests failed"
    echo "- **Playwright E2E Tests**: ❌ FAILED" >> "$REPORT_DIR/test-summary.md"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# ============================================================
# Report Generation
# ============================================================

generate_coverage_report() {
  info "Generating coverage report..."

  if [ -f "$REPORT_DIR/coverage/lcov.info" ]; then
    # Generate HTML coverage report (requires genhtml from lcov package)
    if command -v genhtml &> /dev/null; then
      genhtml "$REPORT_DIR/coverage/lcov.info" \
        -o "$REPORT_DIR/coverage/html" \
        --title "Clinical Diary Coverage Report" \
        --quiet 2>&1 | grep -v "Writing"

      # Extract coverage percentage
      local coverage=$(grep -oP 'lines......: \K[0-9.]+' "$REPORT_DIR/coverage/html/index.html" || echo "N/A")

      echo "" >> "$REPORT_DIR/test-summary.md"
      echo "### Coverage" >> "$REPORT_DIR/test-summary.md"
      echo "- **Line Coverage**: $coverage%" >> "$REPORT_DIR/test-summary.md"

      success "Coverage report generated: $coverage%"
    else
      warning "genhtml not found, skipping HTML coverage report"
    fi
  else
    warning "No coverage data found"
  fi
}

generate_pdf_reports() {
  info "Generating PDF reports..."

  # Generate PDF from HTML reports using Playwright
  if [ -d "$REPORT_DIR/playwright/playwright-report" ]; then
    cd "$REPO_DIR"

    # Create a simple Node script to generate PDF
    cat > /tmp/generate-pdf.js <<'EOF'
const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();

  const reportPath = process.env.REPORT_DIR + '/playwright/playwright-report/index.html';
  await page.goto('file://' + reportPath);

  await page.pdf({
    path: process.env.REPORT_DIR + '/pdfs/playwright-report.pdf',
    format: 'A4',
    printBackground: true,
    margin: { top: '20px', right: '20px', bottom: '20px', left: '20px' }
  });

  await browser.close();
  console.log('PDF generated successfully');
})();
EOF

    if REPORT_DIR="$REPORT_DIR" node /tmp/generate-pdf.js 2>&1; then
      success "PDF report generated"
    else
      warning "Failed to generate PDF report"
    fi

    rm /tmp/generate-pdf.js
  fi
}

finalize_summary() {
  info "Finalizing test summary..."

  # Add overall statistics
  cat >> "$REPORT_DIR/test-summary.md" <<EOF

---

## Summary

- **Total Tests Run**: $TESTS_RUN
- **Passed**: $TESTS_PASSED ✅
- **Failed**: $TESTS_FAILED ❌
- **Skipped**: $TESTS_SKIPPED ⚠️

EOF

  # Add overall result
  if [ $TESTS_FAILED -eq 0 ]; then
    echo "**Overall Result**: ✅ **ALL TESTS PASSED**" >> "$REPORT_DIR/test-summary.md"
    success "All tests passed!"
  else
    echo "**Overall Result**: ❌ **TESTS FAILED**" >> "$REPORT_DIR/test-summary.md"
    error "Some tests failed"
  fi

  # Add artifacts section
  cat >> "$REPORT_DIR/test-summary.md" <<EOF

### Artifacts

- Flutter test results: \`$REPORT_DIR/flutter/\`
- Playwright test results: \`$REPORT_DIR/playwright/\`
- Coverage reports: \`$REPORT_DIR/coverage/\`
- PDF reports: \`$REPORT_DIR/pdfs/\`

---

*Generated by Clinical Diary QA Runner*
EOF

  success "Test summary generated at $REPORT_DIR/test-summary.md"
}

# ============================================================
# Main Execution
# ============================================================

main() {
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  Clinical Diary QA Test Runner"
  echo "════════════════════════════════════════════════════════════"
  echo ""
  info "Test Suite: $TEST_SUITE"
  echo ""

  setup_environment

  # Check if repository exists
  if [ ! -d "$REPO_DIR" ]; then
    error "Repository not found at $REPO_DIR"
    echo "Please clone the repository first:"
    echo "  gh repo clone yourorg/clinical-diary $REPO_DIR"
    exit 1
  fi

  # Run tests based on suite selection
  case "$TEST_SUITE" in
    all)
      info "Running all test suites..."
      echo ""
      run_flutter_unit_tests || true
      echo ""
      run_flutter_integration_tests || true
      echo ""
      run_playwright_tests || true
      ;;
    unit)
      info "Running unit tests only..."
      echo ""
      run_flutter_unit_tests || true
      ;;
    integration)
      info "Running integration tests only..."
      echo ""
      run_flutter_integration_tests || true
      ;;
    e2e)
      info "Running E2E tests only..."
      echo ""
      run_playwright_tests || true
      ;;
    *)
      error "Unknown test suite: $TEST_SUITE"
      echo "Valid options: all, unit, integration, e2e"
      exit 1
      ;;
  esac

  echo ""
  generate_coverage_report
  echo ""
  generate_pdf_reports
  echo ""
  finalize_summary

  echo ""
  echo "════════════════════════════════════════════════════════════"

  # Exit with appropriate code
  if [ $TESTS_FAILED -eq 0 ]; then
    success "QA test suite completed successfully!"
    echo ""
    exit 0
  else
    error "QA test suite completed with failures"
    echo ""
    exit 1
  fi
}

main "$@"
