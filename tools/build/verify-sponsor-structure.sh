#!/bin/bash
# Sponsor Structure Verification Script
#
# Verifies sponsor directory structure matches template requirements.
# Can be run locally or in CI to validate sponsor configuration.
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00070: Sponsor integration automation
#
# USAGE:
#   ./tools/build/verify-sponsor-structure.sh <sponsor-name>

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validate argument
if [[ $# -ne 1 ]]; then
  echo -e "${RED}Error: Sponsor name required${NC}" >&2
  echo "Usage: $0 <sponsor-name>" >&2
  exit 1
fi

SPONSOR_NAME="$1"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPONSOR_DIR="$REPO_ROOT/sponsor/$SPONSOR_NAME"

echo -e "${BLUE}=== Verifying Sponsor Structure: $SPONSOR_NAME ===${NC}"
echo ""

# Track verification results
ERRORS=0
WARNINGS=0

# Check sponsor directory exists
if [[ ! -d "$SPONSOR_DIR" ]]; then
  echo -e "${RED}❌ Sponsor directory not found: $SPONSOR_DIR${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Sponsor directory exists${NC}"

# Check sponsor-config.yml
if [[ ! -f "$SPONSOR_DIR/sponsor-config.yml" ]]; then
  echo -e "${RED}❌ sponsor-config.yml not found${NC}"
  ERRORS=$((ERRORS + 1))
else
  echo -e "${GREEN}✅ sponsor-config.yml exists${NC}"

  # Validate yq is installed
  if ! command -v yq &> /dev/null; then
    echo -e "${YELLOW}⚠️  yq not installed, skipping config validation${NC}"
    WARNINGS=$((WARNINGS + 1))
  else
    # Validate required fields
    CONFIG_NAME=$(yq '.sponsor.name' "$SPONSOR_DIR/sponsor-config.yml")
    CONFIG_CODE=$(yq '.sponsor.code' "$SPONSOR_DIR/sponsor-config.yml")
    CONFIG_NAMESPACE=$(yq '.requirements.namespace' "$SPONSOR_DIR/sponsor-config.yml")

    if [[ "$CONFIG_NAME" != "$SPONSOR_NAME" ]]; then
      echo -e "${RED}  ❌ Config name mismatch (expected: $SPONSOR_NAME, got: $CONFIG_NAME)${NC}"
      ERRORS=$((ERRORS + 1))
    else
      echo -e "${GREEN}  ✅ Config name matches${NC}"
    fi

    if [[ "$CONFIG_NAMESPACE" != "$CONFIG_CODE" ]]; then
      echo -e "${RED}  ❌ Namespace doesn't match code (code: $CONFIG_CODE, namespace: $CONFIG_NAMESPACE)${NC}"
      ERRORS=$((ERRORS + 1))
    else
      echo -e "${GREEN}  ✅ Namespace matches code: $CONFIG_CODE${NC}"
    fi

    # Check if code is 3 uppercase letters
    if [[ ! "$CONFIG_CODE" =~ ^[A-Z]{3}$ ]]; then
      echo -e "${RED}  ❌ Code must be 3 uppercase letters (got: $CONFIG_CODE)${NC}"
      ERRORS=$((ERRORS + 1))
    else
      echo -e "${GREEN}  ✅ Code format valid: $CONFIG_CODE${NC}"
    fi
  fi
fi

# Check README.md
if [[ ! -f "$SPONSOR_DIR/README.md" ]]; then
  echo -e "${YELLOW}⚠️  README.md not found${NC}"
  WARNINGS=$((WARNINGS + 1))
else
  echo -e "${GREEN}✅ README.md exists${NC}"
fi

# Check mobile-module structure
MOBILE_MODULE_ENABLED=$(yq '.mobile_module.enabled' "$SPONSOR_DIR/sponsor-config.yml" 2>/dev/null || echo "false")
if [[ "$MOBILE_MODULE_ENABLED" == "true" ]]; then
  echo -e "${BLUE}Checking mobile module...${NC}"

  if [[ ! -d "$SPONSOR_DIR/mobile-module" ]]; then
    echo -e "${RED}  ❌ mobile-module directory not found${NC}"
    ERRORS=$((ERRORS + 1))
  else
    echo -e "${GREEN}  ✅ mobile-module directory exists${NC}"

    # Check for lib/
    if [[ ! -d "$SPONSOR_DIR/mobile-module/lib" ]]; then
      echo -e "${YELLOW}  ⚠️  lib directory not found${NC}"
      WARNINGS=$((WARNINGS + 1))
    else
      echo -e "${GREEN}  ✅ lib directory exists${NC}"
    fi

    # Check for config file
    if [[ ! -f "$SPONSOR_DIR/mobile-module/lib/${SPONSOR_NAME}_config.dart" ]]; then
      echo -e "${YELLOW}  ⚠️  ${SPONSOR_NAME}_config.dart not found${NC}"
      WARNINGS=$((WARNINGS + 1))
    else
      echo -e "${GREEN}  ✅ ${SPONSOR_NAME}_config.dart exists${NC}"
    fi
  fi
fi

# Check portal structure
PORTAL_ENABLED=$(yq '.portal.enabled' "$SPONSOR_DIR/sponsor-config.yml" 2>/dev/null || echo "false")
if [[ "$PORTAL_ENABLED" == "true" ]]; then
  echo -e "${BLUE}Checking portal...${NC}"

  if [[ ! -d "$SPONSOR_DIR/portal" ]]; then
    echo -e "${RED}  ❌ portal directory not found${NC}"
    ERRORS=$((ERRORS + 1))
  else
    echo -e "${GREEN}  ✅ portal directory exists${NC}"

    # Check for app/
    if [[ ! -d "$SPONSOR_DIR/portal/app" ]] && [[ ! -d "$SPONSOR_DIR/portal/lib" ]]; then
      echo -e "${YELLOW}  ⚠️  Neither app/ nor lib/ directory found${NC}"
      WARNINGS=$((WARNINGS + 1))
    else
      echo -e "${GREEN}  ✅ Portal app structure exists${NC}"
    fi

    # Check for database schema
    SCHEMA_FILE=$(yq '.portal.database.schema_file' "$SPONSOR_DIR/sponsor-config.yml" 2>/dev/null || echo "")
    if [[ -n "$SCHEMA_FILE" ]]; then
      SCHEMA_PATH="$SPONSOR_DIR/$SCHEMA_FILE"
      if [[ ! -f "$SCHEMA_PATH" ]]; then
        echo -e "${RED}  ❌ Schema file not found: $SCHEMA_FILE${NC}"
        ERRORS=$((ERRORS + 1))
      else
        echo -e "${GREEN}  ✅ Schema file exists: $SCHEMA_FILE${NC}"

        # Check for standalone schema header
        if grep -q "STANDALONE SCHEMA" "$SCHEMA_PATH"; then
          echo -e "${GREEN}  ✅ Schema marked as standalone${NC}"
        else
          echo -e "${YELLOW}  ⚠️  Schema not marked as standalone (should include header)${NC}"
          WARNINGS=$((WARNINGS + 1))
        fi
      fi
    fi
  fi
fi

# Check infrastructure structure
if [[ -d "$SPONSOR_DIR/infrastructure" ]]; then
  echo -e "${GREEN}✅ infrastructure directory exists${NC}"

  # Check AWS config
  AWS_REGION=$(yq '.infrastructure.aws.region' "$SPONSOR_DIR/sponsor-config.yml" 2>/dev/null || echo "")
  if [[ -n "$AWS_REGION" ]]; then
    echo -e "${GREEN}  ✅ AWS region configured: $AWS_REGION${NC}"

    # Verify S3 bucket naming
    ARTIFACTS_BUCKET=$(yq '.infrastructure.aws.s3_buckets.artifacts' "$SPONSOR_DIR/sponsor-config.yml" 2>/dev/null || echo "")
    if [[ -n "$ARTIFACTS_BUCKET" ]]; then
      EXPECTED_BUCKET="hht-diary-artifacts-${SPONSOR_NAME}-${AWS_REGION}"
      if [[ "$ARTIFACTS_BUCKET" == "$EXPECTED_BUCKET" ]]; then
        echo -e "${GREEN}  ✅ Artifacts bucket naming correct${NC}"
      else
        echo -e "${YELLOW}  ⚠️  Artifacts bucket naming non-standard (expected: $EXPECTED_BUCKET, got: $ARTIFACTS_BUCKET)${NC}"
        WARNINGS=$((WARNINGS + 1))
      fi
    fi
  fi
else
  echo -e "${YELLOW}⚠️  infrastructure directory not found${NC}"
  WARNINGS=$((WARNINGS + 1))
fi

# Check .github/workflows
if [[ -d "$SPONSOR_DIR/.github/workflows" ]]; then
  echo -e "${GREEN}✅ .github/workflows directory exists${NC}"
else
  echo -e "${YELLOW}⚠️  .github/workflows directory not found (OK for mono-repo)${NC}"
  WARNINGS=$((WARNINGS + 1))
fi

# Summary
echo ""
echo -e "${BLUE}=== Verification Summary ===${NC}"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [[ $ERRORS -gt 0 ]]; then
  echo -e "${RED}❌ Verification failed with $ERRORS error(s)${NC}"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo -e "${YELLOW}⚠️  Verification passed with $WARNINGS warning(s)${NC}"
  exit 0
else
  echo -e "${GREEN}✅ Verification passed${NC}"
  exit 0
fi
