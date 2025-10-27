#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00027: Containerized Development Environments
#   REQ-d00028: Role-Based Environment Separation
#   REQ-d00033: FDA Validation Documentation
#
# Clinical Diary Development Environment Validation
# Automated validation script combining IQ, OQ, and PQ tests
#
# Usage:
#   ./validate-environment.sh              # Run all validations
#   ./validate-environment.sh --quick      # Run quick validation only
#   ./validate-environment.sh --full       # Run full validation suite

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
VALIDATION_MODE="${1:-full}"
REPORT_DIR="validation-reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/validation-$TIMESTAMP.md"

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# ============================================================
# Helper Functions
# ============================================================

info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

success() {
  echo -e "${GREEN}✓${NC} $1"
  PASSED_TESTS=$((PASSED_TESTS + 1))
}

warning() {
  echo -e "${YELLOW}⚠${NC} $1"
  SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
}

error() {
  echo -e "${RED}✗${NC} $1"
  FAILED_TESTS=$((FAILED_TESTS + 1))
}

section() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}$1${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

test_result() {
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [ $1 -eq 0 ]; then
    success "$2"
    echo "- ✅ PASS: $2" >> "$REPORT_FILE"
    return 0
  else
    error "$2"
    echo "- ❌ FAIL: $2" >> "$REPORT_FILE"
    return 1
  fi
}

# ============================================================
# Setup
# ============================================================

setup_validation() {
  info "Setting up validation environment..."

  # Create report directory
  mkdir -p "$REPORT_DIR"

  # Initialize report
  cat > "$REPORT_FILE" <<EOF
# Clinical Diary Development Environment Validation Report

**Validation Mode**: $VALIDATION_MODE
**Date**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Platform**: $(uname -s) $(uname -m)
**Docker Version**: $(docker --version)

---

## Test Results

EOF

  success "Validation environment ready"
}

# ============================================================
# IQ Tests: Installation Qualification
# ============================================================

validate_iq() {
  section "IQ: Installation Qualification"

  echo "" >> "$REPORT_FILE"
  echo "### Installation Qualification (IQ)" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"

  # IQ-1: Docker Engine
  info "Testing Docker Engine..."
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if docker --version >/dev/null 2>&1; then
    test_result 0 "Docker Engine installed"
  else
    test_result 1 "Docker Engine installed"
    return 1
  fi

  # IQ-2: Docker Daemon
  info "Testing Docker Daemon..."
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if docker info >/dev/null 2>&1; then
    test_result 0 "Docker daemon running"
  else
    test_result 1 "Docker daemon running"
    return 1
  fi

  # IQ-3: Docker Compose
  info "Testing Docker Compose..."
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if docker compose version >/dev/null 2>&1; then
    test_result 0 "Docker Compose v2+ installed"
  else
    test_result 1 "Docker Compose v2+ installed"
    return 1
  fi

  # IQ-4: Docker Images
  info "Checking Docker images..."
  for image in clinical-diary-base clinical-diary-dev clinical-diary-qa clinical-diary-ops clinical-diary-mgmt; do
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if docker images "$image:latest" --format "{{.Repository}}" | grep -q "$image"; then
      test_result 0 "Image exists: $image:latest"
    else
      test_result 1 "Image exists: $image:latest"
      echo "  → Run: ./setup.sh to build images"
    fi
  done

  # IQ-5: Documentation
  info "Checking documentation..."
  for doc in tools/dev-env/README.md tools/dev-env/doppler-setup.md docs/dev-environment-architecture.md docs/adr/ADR-006-docker-dev-environments.md spec/dev-environment.md; do
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ -f "$doc" ]; then
      test_result 0 "Documentation exists: $doc"
    else
      test_result 1 "Documentation exists: $doc"
    fi
  done
}

# ============================================================
# OQ Tests: Operational Qualification
# ============================================================

validate_oq() {
  section "OQ: Operational Qualification"

  echo "" >> "$REPORT_FILE"
  echo "### Operational Qualification (OQ)" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"

  # OQ-1: Container Startup
  info "Testing container startup..."
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if docker compose up -d >/dev/null 2>&1; then
    test_result 0 "All containers start successfully"
  else
    test_result 1 "All containers start successfully"
    docker compose logs
    return 1
  fi

  # Wait for containers to be ready
  info "Waiting for containers to be healthy..."
  sleep 5

  # OQ-2: Container Health
  info "Testing container health..."
  for service in dev qa ops mgmt; do
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if docker compose exec -T $service /usr/local/bin/health-check.sh >/dev/null 2>&1; then
      test_result 0 "Health check passed: $service"
    else
      test_result 1 "Health check passed: $service"
      docker compose logs $service
    fi
  done

  # OQ-3: Git Configuration
  info "Testing Git configuration per role..."
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  dev_user=$(docker compose exec -T dev git config user.name)
  if echo "$dev_user" | grep -q "Developer"; then
    test_result 0 "Dev Git identity: Developer"
  else
    test_result 1 "Dev Git identity: Developer (got: $dev_user)"
  fi

  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  qa_user=$(docker compose exec -T qa git config user.name)
  if echo "$qa_user" | grep -q "QA"; then
    test_result 0 "QA Git identity: QA Automation Bot"
  else
    test_result 1 "QA Git identity: QA Automation Bot (got: $qa_user)"
  fi

  # OQ-4: Tool Availability
  info "Testing tool availability..."

  # Dev tools
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if docker compose exec -T dev flutter --version >/dev/null 2>&1; then
    test_result 0 "Flutter available in dev container"
  else
    test_result 1 "Flutter available in dev container"
  fi

  # QA tools
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if docker compose exec -T qa npx playwright --version >/dev/null 2>&1; then
    test_result 0 "Playwright available in qa container"
  else
    test_result 1 "Playwright available in qa container"
  fi

  # Ops tools
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if docker compose exec -T ops terraform --version >/dev/null 2>&1; then
    test_result 0 "Terraform available in ops container"
  else
    test_result 1 "Terraform available in ops container"
  fi

  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if docker compose exec -T ops cosign version >/dev/null 2>&1; then
    test_result 0 "Cosign available in ops container"
  else
    test_result 1 "Cosign available in ops container"
  fi

  # OQ-5: Volume Persistence
  info "Testing volume persistence..."
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  docker compose exec -T dev bash -c "echo 'test' > /workspace/repos/validation-test.txt" >/dev/null 2>&1
  if docker compose exec -T dev cat /workspace/repos/validation-test.txt | grep -q "test"; then
    test_result 0 "Volume persistence (write/read)"
    docker compose exec -T dev rm /workspace/repos/validation-test.txt >/dev/null 2>&1
  else
    test_result 1 "Volume persistence (write/read)"
  fi

  # OQ-6: Shared Exchange Volume
  info "Testing shared exchange volume..."
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  docker compose exec -T dev bash -c "echo 'shared from dev' > /workspace/exchange/validation-shared.txt" >/dev/null 2>&1
  if docker compose exec -T qa cat /workspace/exchange/validation-shared.txt | grep -q "shared from dev"; then
    test_result 0 "Shared exchange volume (dev→qa)"
    docker compose exec -T dev rm /workspace/exchange/validation-shared.txt >/dev/null 2>&1
  else
    test_result 1 "Shared exchange volume (dev→qa)"
  fi
}

# ============================================================
# PQ Tests: Performance Qualification (Quick)
# ============================================================

validate_pq_quick() {
  section "PQ: Performance Qualification (Quick)"

  echo "" >> "$REPORT_FILE"
  echo "### Performance Qualification (PQ) - Quick Tests" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"

  # PQ-1: Container Startup Time
  info "Measuring container startup time..."
  docker compose stop >/dev/null 2>&1
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  start_time=$(date +%s)
  docker compose up -d >/dev/null 2>&1
  end_time=$(date +%s)
  startup_time=$((end_time - start_time))

  echo "  → Startup time: ${startup_time}s"
  if [ $startup_time -lt 30 ]; then
    test_result 0 "Container startup time < 30s (${startup_time}s)"
  else
    test_result 1 "Container startup time < 30s (${startup_time}s)"
  fi

  # Wait for containers to be ready
  sleep 5

  # PQ-2: Resource Usage
  info "Checking resource usage..."
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  resource_output=$(docker stats --no-stream --format "{{.Name}}: CPU={{.CPUPerc}} MEM={{.MemUsage}}")
  echo "$resource_output"
  test_result 0 "Resource usage measured (see logs)"

  # PQ-3: Flutter Project Creation
  info "Testing Flutter project creation..."
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  docker compose exec -T dev bash -c "
    cd /workspace/repos
    flutter create validation_test_app >/dev/null 2>&1
    cd validation_test_app
    flutter pub get >/dev/null 2>&1
    flutter test >/dev/null 2>&1
    cd ..
    rm -rf validation_test_app
  " >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    test_result 0 "Flutter workflow (create/test/cleanup)"
  else
    test_result 1 "Flutter workflow (create/test/cleanup)"
  fi
}

# ============================================================
# Validation Summary
# ============================================================

generate_summary() {
  section "Validation Summary"

  # Calculate pass rate
  if [ $TOTAL_TESTS -gt 0 ]; then
    pass_rate=$(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS / $TOTAL_TESTS) * 100}")
  else
    pass_rate="0.0"
  fi

  echo ""
  echo "Total Tests:  $TOTAL_TESTS"
  echo -e "${GREEN}Passed:${NC}       $PASSED_TESTS"
  echo -e "${RED}Failed:${NC}       $FAILED_TESTS"
  echo -e "${YELLOW}Skipped:${NC}      $SKIPPED_TESTS"
  echo "Pass Rate:    $pass_rate%"
  echo ""

  # Add to report
  cat >> "$REPORT_FILE" <<EOF

---

## Summary

| Metric | Value |
|--------|-------|
| **Total Tests** | $TOTAL_TESTS |
| **Passed** | ✅ $PASSED_TESTS |
| **Failed** | ❌ $FAILED_TESTS |
| **Skipped** | ⚠️ $SKIPPED_TESTS |
| **Pass Rate** | $pass_rate% |

EOF

  # Determine overall result
  if [ $FAILED_TESTS -eq 0 ] && [ $PASSED_TESTS -gt 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ VALIDATION PASSED${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "**Overall Result**: ✅ **VALIDATION PASSED**" >> "$REPORT_FILE"
    echo ""
    echo "Report saved to: $REPORT_FILE"
    return 0
  else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ VALIDATION FAILED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "**Overall Result**: ❌ **VALIDATION FAILED**" >> "$REPORT_FILE"
    echo ""
    echo "Report saved to: $REPORT_FILE"
    echo ""
    echo "Review failed tests above and check:"
    echo "  - Docker images built: ./setup.sh"
    echo "  - Docker daemon running: docker info"
    echo "  - Container logs: docker compose logs"
    return 1
  fi
}

# ============================================================
# Cleanup
# ============================================================

cleanup() {
  info "Cleaning up validation environment..."
  # Leave containers running for review
  # docker compose down >/dev/null 2>&1 || true
  success "Validation complete"
}

# ============================================================
# Main Execution
# ============================================================

main() {
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo "  Clinical Diary Development Environment Validation"
  echo "════════════════════════════════════════════════════════════"
  echo ""

  info "Validation mode: $VALIDATION_MODE"
  echo ""

  setup_validation

  case "$VALIDATION_MODE" in
    --quick)
      validate_iq
      generate_summary
      ;;
    --full|*)
      validate_iq
      validate_oq
      validate_pq_quick
      generate_summary
      ;;
  esac

  cleanup

  echo ""

  # Return appropriate exit code
  if [ $FAILED_TESTS -eq 0 ] && [ $PASSED_TESTS -gt 0 ]; then
    exit 0
  else
    exit 1
  fi
}

# Handle script interruption
trap cleanup EXIT INT TERM

main "$@"
