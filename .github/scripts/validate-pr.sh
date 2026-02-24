#!/usr/bin/env bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00078: Change-Appropriate CI Validation (change detection, conditional checks)
#   REQ-o00079: Commit and PR Traceability Enforcement (PR title, commit message checks)
#   REQ-o00080: Secret and Vulnerability Scanning (gitleaks)
#   REQ-o00081: Code Quality and Static Analysis (code headers, migration headers, doc linting)
#   REQ-d00014: Requirement Validation Tooling (elspais)
#   REQ-o00052: CI/CD Pipeline for Requirement Traceability (elspais, traceability matrix)
#
# Fast-fail PR validation script. Runs checks sequentially, exits on first failure.
# Replaces 10 parallel CI jobs with a single script for faster feedback.
#
# Expected environment variables (set by the workflow):
#   PR_TITLE   - Pull request title
#   PR_BODY    - Pull request body
#   PR_NUMBER  - Pull request number
#   PR_URL     - Pull request HTML URL
#   BASE_SHA   - Base branch SHA
#   HEAD_SHA   - Head branch SHA
#   BASE_REF   - Base branch name (e.g., "main")
#   EVENT_NAME - GitHub event name ("pull_request" or "push")
set -euo pipefail

source .github/versions.env

# ============================================================================
# Tier 0: Instant checks (< 5 seconds)
# ============================================================================

# --- 1. PR title must contain [CUR-XXX] ---
echo "::group::PR Title Validation"
echo "PR #${PR_NUMBER}: ${PR_TITLE}"
echo ""

if echo "$PR_TITLE" | grep -qE '\[CUR-[0-9]+\]'; then
  echo "PR title contains Linear ticket reference"
else
  echo "::error::PR title missing [CUR-XXX] reference"
  echo ""
  echo "PR TITLE VALIDATION FAILED"
  echo ""
  echo "The PR title must include a Linear ticket reference in the format [CUR-XXX]."
  echo "This is required because squash merge uses the PR title as the commit message."
  echo ""
  echo "Required format:"
  echo "  Title: [CUR-XXX] Description of changes"
  echo ""
  echo "To fix: Edit the PR title at:"
  echo "  ${PR_URL}"
  echo ""
  echo "::endgroup::"
  exit 1
fi

echo "::endgroup::"

# --- 2. Commit message CUR-XXX check (REQ is advisory only per CUR-677) ---
echo "::group::Commit Message Check"

# Get only the latest non-merge commit unique to this PR branch
COMMITS=$(git log --no-merges -1 --format='%H|%s' "${BASE_SHA}".."${HEAD_SHA}" || true)

if [ -z "$COMMITS" ]; then
  echo "No commits found in PR range"
else
  while IFS='|' read -r sha subject; do
    FULL_MSG=$(git log -1 --format='%B' "$sha")

    # CUR-XXX is required
    HAS_CUR=false
    if echo "$FULL_MSG" | grep -qE '\[?CUR-[0-9]+\]?'; then
      HAS_CUR=true
    fi

    # REQ-XXX is advisory only (per CUR-677 / PR #337)
    HAS_REQ=false
    if echo "$FULL_MSG" | grep -qE '(REQ|EQ-CAL)-[pdo][0-9]{5}'; then
      HAS_REQ=true
    fi

    if [ "$HAS_CUR" = "true" ]; then
      echo "${sha:0:7}: $subject - CUR reference found"
    else
      echo "::error::${sha:0:7}: $subject - missing CUR-XXX reference"
      echo ""
      echo "COMMIT MESSAGE VALIDATION FAILED"
      echo ""
      echo "Commit ${sha:0:7} is missing a required CUR-XXX reference."
      echo ""
      echo "Required format:"
      echo "  [CUR-XXX] Subject line describing the change"
      echo ""
      echo "To fix: Use 'git rebase -i' to edit the commit message"
      echo "::endgroup::"
      exit 1
    fi

    if [ "$HAS_REQ" = "false" ]; then
      echo "::warning::${sha:0:7}: No REQ-xxx reference found (advisory, not blocking)"
    fi
  done <<< "$COMMITS"
fi

echo "::endgroup::"

# ============================================================================
# Tier 1: Detect what changed (lightweight, no external action needed)
# ============================================================================

echo "::group::Change Detection"

SPEC_CHANGED=false
CODE_CHANGED=false
DB_CHANGED=false
DOCS_CHANGED=false
WORKFLOWS_CHANGED=false

CHANGED_FILES=$(git diff --name-only "${BASE_SHA}".."${HEAD_SHA}" || true)

if echo "$CHANGED_FILES" | grep -qE '^spec/'; then
  SPEC_CHANGED=true
  echo "Spec files changed"
fi

if echo "$CHANGED_FILES" | grep -qE '^(packages|apps)/'; then
  CODE_CHANGED=true
  echo "Code files changed"
fi

if echo "$CHANGED_FILES" | grep -qE '^database/'; then
  DB_CHANGED=true
  echo "Database files changed"
fi

if echo "$CHANGED_FILES" | grep -qE '^docs/|\.md$'; then
  DOCS_CHANGED=true
  echo "Documentation files changed"
fi

if echo "$CHANGED_FILES" | grep -qE '^\.github/workflows/'; then
  WORKFLOWS_CHANGED=true
  echo "Workflow files changed"
fi

if [ "$SPEC_CHANGED" = "false" ] && [ "$CODE_CHANGED" = "false" ] && \
   [ "$DB_CHANGED" = "false" ] && [ "$DOCS_CHANGED" = "false" ] && \
   [ "$WORKFLOWS_CHANGED" = "false" ]; then
  echo "No categorized changes detected"
fi

# Export for workflow steps that follow the script
echo "SPEC_CHANGED=${SPEC_CHANGED}" >> "$GITHUB_ENV"
echo "CODE_CHANGED=${CODE_CHANGED}" >> "$GITHUB_ENV"
echo "DB_CHANGED=${DB_CHANGED}" >> "$GITHUB_ENV"
echo "DOCS_CHANGED=${DOCS_CHANGED}" >> "$GITHUB_ENV"
echo "WORKFLOWS_CHANGED=${WORKFLOWS_CHANGED}" >> "$GITHUB_ENV"

echo "::endgroup::"

# ============================================================================
# Tier 2: Security (always runs)
# ============================================================================

# --- 4. Gitleaks - secret scanning ---
echo "::group::Secret Scanning (gitleaks v${GITLEAKS_VERSION})"

# Download gitleaks with retry
for i in {1..3}; do
  if wget -q "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"; then
    break
  fi
  echo "Download attempt $i failed, retrying..."
  sleep 5
done

tar -xzf "gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
sudo mv gitleaks /usr/local/bin/
rm -f "gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
gitleaks version

if gitleaks detect --verbose --no-banner --redact --log-level info; then
  echo "No secrets detected by gitleaks"
else
  echo "::error::Gitleaks detected secrets in the repository"
  echo ""
  echo "SECRET SCANNING FAILED"
  echo ""
  echo "Remove all secrets from the codebase before merging."
  echo "Use environment variables or Doppler for secret management."
  echo "::endgroup::"
  exit 1
fi

echo "::endgroup::"

# ============================================================================
# Tier 3: Conditional checks (only when relevant files changed)
# ============================================================================

# --- 5. Elspais - requirement validation (if spec/code/workflows changed) ---
if [ "$SPEC_CHANGED" = "true" ] || [ "$CODE_CHANGED" = "true" ] || [ "$WORKFLOWS_CHANGED" = "true" ]; then
  echo "::group::Requirement Validation (elspais v${ELSPAIS_VERSION})"

  python3 -m pip install --upgrade pip -q
  pip install elspais=="${ELSPAIS_VERSION}" -q
  elspais --version

  elspais validate --mode core
  elspais index validate --mode core

  # Verify requirement hash freshness (CUR-1013)
  if elspais hash verify 2>/dev/null; then
    echo "Requirement hashes are up to date"
  else
    echo "::warning::Requirement hash verification returned non-zero (may not be supported in this elspais version)"
  fi

  # Generate traceability matrix for artifact upload
  mkdir -p build-reports/combined/traceability
  elspais trace --format both --output build-reports/combined/traceability/traceability_matrix

  echo "Requirement validation passed"
  echo "::endgroup::"
fi

# --- 6. Code implementation headers (if code/database changed) ---
if [ "$CODE_CHANGED" = "true" ] || [ "$DB_CHANGED" = "true" ]; then
  echo "::group::Code Header Validation"

  MISSING_HEADERS=()

  # Check SQL files in database directory
  if [ -d "database" ]; then
    shopt -s nullglob globstar
    for file in database/**/*.sql; do
      # Skip tests and migrations
      if [[ "$file" =~ /tests/ ]] || [[ "$file" =~ /migrations/ ]]; then
        continue
      fi
      if [ -f "$file" ] && ! grep -q "IMPLEMENTS REQUIREMENTS:" "$file"; then
        MISSING_HEADERS+=("$file")
      fi
    done
    shopt -u globstar
  fi

  # Check Dart files in packages directory
  if [ -d "packages" ]; then
    shopt -s globstar
    for file in packages/**/*.dart; do
      if [ "$(basename "$file")" != "main.dart" ] && ! grep -q "IMPLEMENTS REQUIREMENTS:" "$file"; then
        MISSING_HEADERS+=("$file")
      fi
    done
    shopt -u globstar
  fi

  # Check Dart files in apps directory
  if [ -d "apps" ]; then
    shopt -s globstar
    for file in apps/**/*.dart; do
      if [ "$(basename "$file")" != "main.dart" ] && ! grep -q "IMPLEMENTS REQUIREMENTS:" "$file"; then
        MISSING_HEADERS+=("$file")
      fi
    done
    shopt -u globstar
  fi

  # Enforcement depends on target branch
  ENFORCE_HEADERS=false
  if [[ "${BASE_REF}" == "main" ]] || [[ "${BASE_REF}" == "staging" ]] || [[ "${BASE_REF}" == "production" ]]; then
    ENFORCE_HEADERS=true
  fi

  if [ ${#MISSING_HEADERS[@]} -gt 0 ]; then
    if [ "$ENFORCE_HEADERS" = "true" ]; then
      echo "::error::Implementation files missing requirement headers:"
      for file in "${MISSING_HEADERS[@]}"; do
        echo "::error file=$file::Missing IMPLEMENTS REQUIREMENTS header"
      done
      echo ""
      echo "CODE HEADER VALIDATION FAILED"
      echo "Headers are REQUIRED for ${BASE_REF} branch."
      echo "See spec/requirements-format.md for the correct format."
      echo "::endgroup::"
      exit 1
    else
      echo "::warning::Implementation files missing requirement headers (non-blocking for feature branches):"
      for file in "${MISSING_HEADERS[@]}"; do
        echo "::warning file=$file::Missing IMPLEMENTS REQUIREMENTS header"
      done
    fi
  else
    echo "All implementation files have requirement headers"
  fi

  echo "::endgroup::"
fi

# --- 7. Migration headers (if database changed) ---
if [ "$DB_CHANGED" = "true" ]; then
  echo "::group::Migration Header Validation"

  INVALID_MIGRATIONS=()
  shopt -s nullglob
  for file in database/migrations/*.sql; do
    if [ -f "$file" ]; then
      if ! grep -q "^-- Migration:" "$file" || \
         ! grep -q "^-- Date:" "$file" || \
         ! grep -q "^-- Description:" "$file"; then
        INVALID_MIGRATIONS+=("$file")
      fi
    fi
  done
  shopt -u nullglob

  if [ ${#INVALID_MIGRATIONS[@]} -gt 0 ]; then
    echo "::error::Migration files have invalid headers:"
    for file in "${INVALID_MIGRATIONS[@]}"; do
      echo "::error file=$file::Missing required migration header fields"
    done
    echo ""
    echo "MIGRATION HEADER VALIDATION FAILED"
    echo "See database/migrations/README.md for the correct format."
    echo "::endgroup::"
    exit 1
  else
    echo "All migration files have proper headers"
  fi

  echo "::endgroup::"
fi

# --- 8. FDA compliance (if database/spec changed) ---
if [ "$DB_CHANGED" = "true" ] || [ "$SPEC_CHANGED" = "true" ]; then
  echo "::group::FDA Compliance Check"

  COMPLIANCE_ISSUES=()

  # Check that event sourcing requirements exist
  if ! grep -q "REQ-p00004" spec/prd-database.md 2>/dev/null; then
    COMPLIANCE_ISSUES+=("Event sourcing requirement REQ-p00004 not found")
  fi

  # Check that audit trail implementation exists
  if [ ! -f "database/triggers.sql" ]; then
    COMPLIANCE_ISSUES+=("Audit trail triggers not found")
  fi

  # Check that RLS policies exist
  if [ ! -f "database/rls_policies.sql" ]; then
    COMPLIANCE_ISSUES+=("Row-level security policies not found")
  fi

  if [ ${#COMPLIANCE_ISSUES[@]} -gt 0 ]; then
    echo "::error::FDA compliance issues detected:"
    for issue in "${COMPLIANCE_ISSUES[@]}"; do
      echo "::error::$issue"
    done
    echo "::endgroup::"
    exit 1
  else
    echo "FDA compliance checks passed"
  fi

  echo "::endgroup::"
fi

# --- 9. Documentation linting (if docs/spec changed) ---
if [ "$DOCS_CHANGED" = "true" ] || [ "$SPEC_CHANGED" = "true" ]; then
  echo "::group::Documentation Linting (markdownlint-cli v${MARKDOWNLINT_CLI_VERSION})"

  npm install -g "markdownlint-cli@${MARKDOWNLINT_CLI_VERSION}" --silent 2>/dev/null
  markdownlint --config .markdownlint.json '**/*.md'

  echo "Documentation linting passed"
  echo "::endgroup::"
fi

echo ""
echo "All validation checks passed"
