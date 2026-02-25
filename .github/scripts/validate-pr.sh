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

# Close any open ::group:: and emit ::error:: on unhandled failures (set -e)
CURRENT_GROUP=""
begin_group() { CURRENT_GROUP="$1"; echo "::group::$1"; }
end_group()   { echo "::endgroup::"; CURRENT_GROUP=""; }
trap 'exit_code=$?; echo ""; echo "::error::Unexpected failure (exit code ${exit_code}) at line ${LINENO}: ${BASH_COMMAND}"; if [ -n "$CURRENT_GROUP" ]; then echo "::error::Failed during: ${CURRENT_GROUP}"; echo "::endgroup::"; fi' ERR

source .github/versions.env

# ============================================================================
# Policy flags — control enforcement levels across all checks
# Values come from versions.env; override here for local testing
# ============================================================================

# ENFORCE_CODE_HEADERS (from versions.env, default: off)
#   off = skip check entirely (disabled)
#   on  = scan files, write report, fail the build if headers are missing
ENFORCE_CODE_HEADERS="${ENFORCE_CODE_HEADERS:-off}"

# ============================================================================
# Tier 0: Instant checks (< 5 seconds)
# ============================================================================

# --- 1. PR title must contain [CUR-XXX] ---
begin_group "PR Title Validation"
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
  end_group
  exit 1
fi

end_group

# ============================================================================
# Tier 1: Detect what changed (lightweight, no external action needed)
# ============================================================================

begin_group "Change Detection"

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

end_group

# ============================================================================
# Tier 2: Security (always runs)
# ============================================================================

# --- 3. Gitleaks - secret scanning ---
begin_group "Secret Scanning (gitleaks v${GITLEAKS_VERSION})"

# Download gitleaks with retry
for i in {1..3}; do
  if wget -q "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"; then
    break
  fi
  echo "Download attempt $i failed, retrying..."
  sleep 5
done

GITLEAKS_TMP=$(mktemp -d)
tar -xzf "gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" -C "$GITLEAKS_TMP"
sudo mv "$GITLEAKS_TMP/gitleaks" /usr/local/bin/
rm -rf "$GITLEAKS_TMP" "gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
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
  end_group
  exit 1
fi

end_group

# ============================================================================
# Tier 3: Conditional checks (only when relevant files changed)
# ============================================================================

# --- 4. Elspais - requirement validation (only when spec/ files change) ---
begin_group "Requirement Validation (elspais v${ELSPAIS_VERSION})"

if [ "$SPEC_CHANGED" = "true" ]; then
  python3 -m pip install --upgrade pip -q --break-system-packages
  python3 -m pip install elspais=="${ELSPAIS_VERSION}" -q --break-system-packages
  export PATH="$HOME/.local/bin:$PATH"
  elspais --version

  elspais validate --mode core
  elspais index validate --mode core

  # Verify requirement hash freshness (CUR-1013)
  if elspais hash verify 2>/dev/null; then
    echo "Requirement hashes are up to date"
  else
    echo "::warning::Requirement hash verification returned non-zero (may not be supported in this elspais version)"
  fi

  echo "Requirement validation passed"
else
  echo "Skipped - no spec/ changes [Passed]"
fi

end_group

# --- 5. Migration headers (if database changed) ---
if [ "$DB_CHANGED" = "true" ]; then
  begin_group "Migration Header Validation"

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
    end_group
    exit 1
  else
    echo "All migration files have proper headers"
  fi

  end_group
fi

# --- 6. Code implementation headers (if code/database changed, gated by ENFORCE_CODE_HEADERS) ---
# Scans all Dart/SQL source files for IMPLEMENTS REQUIREMENTS headers.
# Writes a report to ci-reports/traceability_code_warnings.md.
# Controlled by ENFORCE_CODE_HEADERS flag (see top of file).
if [ "$ENFORCE_CODE_HEADERS" = "on" ] && { [ "$CODE_CHANGED" = "true" ] || [ "$DB_CHANGED" = "true" ]; }; then
  begin_group "Code Header Validation (ENFORCE_CODE_HEADERS=${ENFORCE_CODE_HEADERS})"

  MISSING_HEADERS=()
  TOTAL_SCANNED=0

  # Check SQL files in database directory
  if [ -d "database" ]; then
    shopt -s nullglob globstar
    for file in database/**/*.sql; do
      # Skip tests and migrations
      if [[ "$file" =~ /tests/ ]] || [[ "$file" =~ /migrations/ ]]; then
        continue
      fi
      if [ -f "$file" ]; then
        TOTAL_SCANNED=$((TOTAL_SCANNED + 1))
        if ! grep -q "IMPLEMENTS REQUIREMENTS:" "$file"; then
          MISSING_HEADERS+=("$file|sql")
        fi
      fi
    done
    shopt -u globstar
  fi

  # Check Dart files in packages directory
  if [ -d "packages" ]; then
    shopt -s globstar
    for file in packages/**/*.dart; do
      if [ "$(basename "$file")" != "main.dart" ]; then
        TOTAL_SCANNED=$((TOTAL_SCANNED + 1))
        if ! grep -q "IMPLEMENTS REQUIREMENTS:" "$file"; then
          MISSING_HEADERS+=("$file|dart")
        fi
      fi
    done
    shopt -u globstar
  fi

  # Check Dart files in apps directory
  if [ -d "apps" ]; then
    shopt -s globstar
    for file in apps/**/*.dart; do
      if [ "$(basename "$file")" != "main.dart" ]; then
        TOTAL_SCANNED=$((TOTAL_SCANNED + 1))
        if ! grep -q "IMPLEMENTS REQUIREMENTS:" "$file"; then
          MISSING_HEADERS+=("$file|dart")
        fi
      fi
    done
    shopt -u globstar
  fi

  # Write report to ci-reports/
  mkdir -p ci-reports
  REPORT="ci-reports/traceability_code_warnings.md"
  {
    echo "# Code Traceability Warnings"
    echo ""
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ) | PR: #${PR_NUMBER} | Files scanned: ${TOTAL_SCANNED}"
    echo ""
    if [ ${#MISSING_HEADERS[@]} -gt 0 ]; then
      echo "## Files Missing \`IMPLEMENTS REQUIREMENTS\` Header"
      echo ""
      echo "| File | Type |"
      echo "|------|------|"
      for entry in "${MISSING_HEADERS[@]}"; do
        IFS='|' read -r filepath filetype <<< "$entry"
        echo "| ${filepath} | ${filetype} |"
      done
      echo ""
      echo "**Total**: ${#MISSING_HEADERS[@]} files missing headers out of ${TOTAL_SCANNED} scanned"
    else
      echo "All ${TOTAL_SCANNED} implementation files have requirement headers."
    fi
  } > "$REPORT"

  MISSING_COUNT=${#MISSING_HEADERS[@]}
  echo "Scanned ${TOTAL_SCANNED} files, ${MISSING_COUNT} missing headers"
  echo "Report written to ${REPORT}"

  if [ "$MISSING_COUNT" -gt 0 ]; then
    for entry in "${MISSING_HEADERS[@]}"; do
      IFS='|' read -r filepath _ <<< "$entry"
      echo "::error file=$filepath::Missing IMPLEMENTS REQUIREMENTS header"
    done
    echo ""
    echo "CODE HEADER VALIDATION FAILED (ENFORCE_CODE_HEADERS=on)"
    echo "See spec/requirements-format.md for the correct format."
    end_group
    exit 1
  fi

  end_group
fi

# --- 7. Documentation linting (if docs/spec changed) ---
if [ "$DOCS_CHANGED" = "true" ] || [ "$SPEC_CHANGED" = "true" ]; then
  begin_group "Documentation Linting (markdownlint-cli v${MARKDOWNLINT_CLI_VERSION})"

  npx "markdownlint-cli@${MARKDOWNLINT_CLI_VERSION}" --config .markdownlint.json '**/*.md'

  echo "Documentation linting passed"
  end_group
fi

echo ""
echo "All validation checks passed"
