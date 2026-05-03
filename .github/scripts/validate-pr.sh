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
#   PR_NUMBER  - Pull request number
#   PR_URL     - Pull request HTML URL
#   BASE_SHA   - Base branch SHA
#   HEAD_SHA   - Head branch SHA
#   BASE_REF   - Base branch name (e.g., "main")
#   EVENT_NAME - GitHub event name ("pull_request" or "push")
set -euo pipefail

# Summary file for surfacing errors outside collapsed log groups
FAILURE_SUMMARY="${FAILURE_SUMMARY_FILE:-/dev/null}"

# Close any open ::group:: and emit ::error:: on unhandled failures (set -e)
CURRENT_GROUP=""
begin_group() { CURRENT_GROUP="$1"; echo "::group::$1"; }
end_group()   { echo "::endgroup::"; CURRENT_GROUP=""; }
trap 'exit_code=$?; echo ""; echo "::error::Unexpected failure (exit code ${exit_code}) at line ${LINENO}: ${BASH_COMMAND}"; if [ -n "$CURRENT_GROUP" ]; then echo "::error::Failed during: ${CURRENT_GROUP}"; echo "::endgroup::"; fi' ERR

# Write an error to both ::error:: annotation and the failure summary file
report_error() {
  echo "::error::$1"
  echo "- $1" >> "$FAILURE_SUMMARY"
}

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

# --- 1. PR title must contain [CUR-XXX] (or [Dependabot] for bot PRs, CUR-1149) ---
begin_group "PR Title Validation"
echo "PR #${PR_NUMBER}: ${PR_TITLE}"
echo ""

if echo "$PR_TITLE" | grep -qE '\[CUR-[0-9]+\]|\[Dependabot\]'; then
  echo "PR title contains accepted prefix ([CUR-XXX] or [Dependabot])"
else
  report_error "PR title missing [CUR-XXX] reference"
  echo ""
  echo "PR TITLE VALIDATION FAILED"
  echo ""
  echo "The PR title must include a Linear ticket reference in the format [CUR-XXX]."
  echo "Dependabot-authored PRs may use the [Dependabot] prefix instead."
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
TOOLS_CHANGED=false
SRC_CHANGED=false

CHANGED_FILES=$(git diff --name-only "${BASE_SHA}".."${HEAD_SHA}" || true)

# Each path category is detected exactly once below; downstream gates
# (including ELSPAIS_RELEVANT_CHANGED) compose these flags rather than
# repeating regexes. If you add a new scanning directory in .elspais.toml,
# add a per-category flag here and OR it into the derivation block at the
# end of this section.

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

if echo "$CHANGED_FILES" | grep -qE '^tools/'; then
  TOOLS_CHANGED=true
  echo "Tools files changed"
fi

if echo "$CHANGED_FILES" | grep -qE '^src/'; then
  SRC_CHANGED=true
  echo "Src files changed"
fi

# Elspais behavior can change without any scanned source file changing:
# a config edit in .elspais.toml (different scan paths, severity rules,
# id patterns) or a pinned-version bump in versions.env (different
# parser, hashing, or coverage logic) reshapes the matrix output.
# Treat both as elspais-relevant so the gate fires and the matrix
# re-renders.
ELSPAIS_CONFIG_CHANGED=false
if echo "$CHANGED_FILES" | grep -qE '^(\.elspais\.toml|\.github/versions\.env)$'; then
  ELSPAIS_CONFIG_CHANGED=true
  echo "Elspais config or pinned version changed"
fi

# Derive elspais trigger from the per-category flags above. Mirrors
# [scanning.*].directories in .elspais.toml without restating the regex:
# spec, apps/packages (CODE), database, docs (or any .md), tools, src.
# Plus ELSPAIS_CONFIG_CHANGED for config/version-only PRs that still
# alter elspais output. Such files can introduce or remove REQ-
# references (in IMPLEMENTS / Verifies headers, prose, or test
# annotations), so elspais must validate them on every PR — not just
# spec-file edits. PR #539 (CUR-1164) added REQ-p05004 references in
# app code with no spec/ change, so elspais was silently skipped and
# the broken reference landed on main (CUR-1246). DOCS_CHANGED is
# broader than elspais's strict docs/ scan (it also matches bare .md
# anywhere); the extra coverage is harmless — at most one extra
# elspais run on a docs-only PR.
ELSPAIS_RELEVANT_CHANGED=false
if [ "$SPEC_CHANGED" = "true" ] || [ "$CODE_CHANGED" = "true" ] || \
   [ "$DB_CHANGED" = "true" ] || [ "$DOCS_CHANGED" = "true" ] || \
   [ "$TOOLS_CHANGED" = "true" ] || [ "$SRC_CHANGED" = "true" ] || \
   [ "$ELSPAIS_CONFIG_CHANGED" = "true" ]; then
  ELSPAIS_RELEVANT_CHANGED=true
  echo "Files in elspais scan paths changed - requirement validation will run"
fi

if [ "$SPEC_CHANGED" = "false" ] && [ "$CODE_CHANGED" = "false" ] && \
   [ "$DB_CHANGED" = "false" ] && [ "$DOCS_CHANGED" = "false" ] && \
   [ "$WORKFLOWS_CHANGED" = "false" ] && [ "$TOOLS_CHANGED" = "false" ] && \
   [ "$SRC_CHANGED" = "false" ] && [ "$ELSPAIS_CONFIG_CHANGED" = "false" ]; then
  echo "No categorized changes detected"
fi

# Export for workflow steps that follow the script
echo "SPEC_CHANGED=${SPEC_CHANGED}" >> "$GITHUB_ENV"
# Used by the post-validation step to decide whether to (re)post the
# traceability-matrix PR comment. Gated on the broader elspais trigger
# rather than SPEC_CHANGED so the matrix re-renders for any change that
# could shift its contents — code coverage rollups, retired-reference
# counts, code→REQ link counts, etc. — not just spec/*.md edits.
echo "ELSPAIS_RELEVANT_CHANGED=${ELSPAIS_RELEVANT_CHANGED}" >> "$GITHUB_ENV"

end_group

# ============================================================================
# Tier 2: Security (always runs)
# ============================================================================

# --- 2. Gitleaks - secret scanning ---
begin_group "Secret Scanning (gitleaks v${GITLEAKS_VERSION})"

gitleaks version

if gitleaks detect --verbose --no-banner --redact --log-level info; then
  echo "No secrets detected by gitleaks"
else
  report_error "Gitleaks detected secrets in the repository"
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
# Tier 2.5: Version bump enforcement (always runs when trigger paths change)
# ============================================================================

# IMPLEMENTS REQUIREMENTS:
#   REQ-o00052-A: CI/CD validation on every PR to protected branches
#   REQ-d00057-E: Build commands reproducible across local and CI environments
#
# --- 3. Verify version bumps match changed trigger paths ---
begin_group "Version Bump Verification"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$REPO_ROOT/.githooks/project-defs.sh"
source "$REPO_ROOT/.githooks/version-utils.sh"

VERSION_FAILED=false

for project_def in "${PROJECT_DEFS[@]}"; do
  IFS='|' read -r name pubspec code_dirs triggers version_mode <<< "$project_def"

  code_changed=false
  any_trigger=false
  if has_code_changes "$code_dirs" "$CHANGED_FILES"; then
    code_changed=true
    any_trigger=true
  elif has_any_trigger "$triggers" "$CHANGED_FILES"; then
    any_trigger=true
  fi

  if [ "$any_trigger" = true ]; then
    main_ver=$(git show "${BASE_SHA}:${pubspec}" 2>/dev/null | grep '^version:' | sed 's/version: //' || true)
    pr_ver=$(git show "${HEAD_SHA}:${pubspec}" 2>/dev/null | grep '^version:' | sed 's/version: //' || true)

    if [ -z "$main_ver" ] || [ -z "$pr_ver" ]; then
      echo "Skipping ${name} — pubspec not found in base or head"
      continue
    fi

    if ! verify_version_bumped_for "$version_mode" "$pr_ver" "$main_ver" "$code_changed"; then
      expected=$(compute_new_version_for "$version_mode" "$pr_ver" "$main_ver" "$code_changed")
      if [ "$code_changed" = true ]; then
        report_error "${name} version not bumped (code change). main: ${main_ver}, PR: ${pr_ver}, expected at least: ${expected}"
      else
        report_error "${name} build number not bumped (trigger change). main: ${main_ver}, PR: ${pr_ver}, expected at least: ${expected}"
      fi
      VERSION_FAILED=true
    else
      echo "${name}: version OK (main: ${main_ver} -> PR: ${pr_ver})"
    fi
  fi
done

if [ "$VERSION_FAILED" = true ]; then
  echo ""
  echo "VERSION BUMP VERIFICATION FAILED"
  echo ""
  echo "The pre-commit hook should auto-bump versions. If you see this error:"
  echo "  1. Ensure git hooks are installed: git config core.hooksPath .githooks"
  echo "  2. Re-commit to trigger the version bump hook"
  echo "  3. Or manually update the version in pubspec.yaml"
  end_group
  exit 1
fi

echo "Version bump verification passed"
end_group

# ============================================================================
# Tier 3: Conditional checks (only when relevant files changed)
# ============================================================================

# --- 4. Elspais - requirement validation ---
# Triggered whenever any file under an elspais scan path changes (see
# Change Detection above). Catches broken REQ references introduced
# from code, tests, journeys, or docs — not just spec edits (CUR-1246).
begin_group "Requirement Validation (elspais v${ELSPAIS_VERSION})"

if [ "$ELSPAIS_RELEVANT_CHANGED" = "true" ]; then
  elspais --version

  # Capture stdout+stderr so we can both forward it to the log and scan
  # it for "info"-downgraded findings to surface as GitHub Actions
  # warning annotations (see lib/elspais-annotations.sh). The `if`-form
  # deactivates `set -e` for the elspais call so we can run the
  # annotation pass before re-asserting the exit code.
  elspais_exit=0
  if elspais_output=$(elspais checks 2>&1); then
    elspais_exit=0
  else
    elspais_exit=$?
  fi
  printf '%s\n' "$elspais_output"

  # shellcheck source=lib/elspais-annotations.sh
  source "$REPO_ROOT/.github/scripts/lib/elspais-annotations.sh"
  emit_suppressed_warnings "$elspais_output"

  if [ "$elspais_exit" -ne 0 ]; then
    exit "$elspais_exit"
  fi

  # Generate traceability matrix for PR comment and artifact upload
  mkdir -p build-reports/combined/traceability
  elspais summary trace --format markdown \
    -o build-reports/combined/traceability/traceability_matrix.md

  echo "Requirement validation passed"
else
  echo "Skipped - no changes under elspais scan paths [Passed]"
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
    report_error "Migration files have invalid headers:"
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

  # Recursive SQL/Dart scans use `find -print0 | while read -d ''` rather
  # than bash 4's `globstar`. Devs run validate-pr.sh on macOS where the
  # default /bin/bash is 3.2 and `shopt -s globstar` is unavailable; under
  # that shell, `database/**/*.sql` silently degrades to depth-2 matching
  # and deeper files escape header validation without any error. The
  # process-substitution form keeps the loop body in the same shell so
  # MISSING_HEADERS+= and TOTAL_SCANNED= propagate.

  # Check SQL files in database directory
  if [ -d "database" ]; then
    while IFS= read -r -d '' file; do
      if [[ "$file" =~ /tests/ ]] || [[ "$file" =~ /migrations/ ]]; then
        continue
      fi
      TOTAL_SCANNED=$((TOTAL_SCANNED + 1))
      if ! grep -q "IMPLEMENTS REQUIREMENTS:" "$file"; then
        MISSING_HEADERS+=("$file|sql")
      fi
    done < <(find database -type f -name '*.sql' -print0 2>/dev/null)
  fi

  # Check Dart files in packages directory
  if [ -d "packages" ]; then
    while IFS= read -r -d '' file; do
      if [ "$(basename "$file")" = "main.dart" ]; then
        continue
      fi
      TOTAL_SCANNED=$((TOTAL_SCANNED + 1))
      if ! grep -q "IMPLEMENTS REQUIREMENTS:" "$file"; then
        MISSING_HEADERS+=("$file|dart")
      fi
    done < <(find packages -type f -name '*.dart' -print0 2>/dev/null)
  fi

  # Check Dart files in apps directory
  if [ -d "apps" ]; then
    while IFS= read -r -d '' file; do
      if [ "$(basename "$file")" = "main.dart" ]; then
        continue
      fi
      TOTAL_SCANNED=$((TOTAL_SCANNED + 1))
      if ! grep -q "IMPLEMENTS REQUIREMENTS:" "$file"; then
        MISSING_HEADERS+=("$file|dart")
      fi
    done < <(find apps -type f -name '*.dart' -print0 2>/dev/null)
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

  markdownlint --config .markdownlint.json '**/*.md'

  echo "Documentation linting passed"
  end_group
fi

echo ""
echo "All validation checks passed"
