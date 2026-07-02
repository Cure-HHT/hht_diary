#!/usr/bin/env bash
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
# Tier 0: Instant checks (< 5 seconds)
# ============================================================================

# --- 1. PR title must contain [CUR-XXX] (or [Dependabot] for bot PRs, CUR-1149) ---
# Verifies: DIARY-OPS-pr-compliance-checks/A
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

# Implements: DIARY-OPS-change-appropriate-ci/A+B
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
# spec-file edits. PR #539 (CUR-1164) added requirement references in
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

# Note: secret scanning (gitleaks) is intentionally NOT run from this script.
# It runs in the dedicated `Security - Check for Secrets` job in pr-health.yml
# (org ruleset-required, native runner) and locally via .githooks/pre-push.
# Running it here would duplicate either the CI job or the pre-push hook with
# no added coverage. (CUR-1261)

# ============================================================================
# Tier 2: Version bump enforcement (always runs when trigger paths change)
# ============================================================================

# --- 3. Verify version bumps match changed trigger paths ---
# Verifies: DIARY-OPS-single-promotable-artifact/C
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

# --- 4. Elspais - requirement validation (readiness phase) ---
# Triggered whenever any file under an elspais scan path changes (see
# Change Detection above). Catches broken REQ references introduced
# from code, tests, journeys, or docs — not just spec edits (CUR-1246).
#
# This is the *readiness* phase: spec/code/terms validation only. We
# skip the TESTS and UAT categories with --spec --code --terms because
# no test workflow has emitted JUnit/pytest result files yet at this
# point in the pipeline, so the tests.results check would always fail.
# A separate report-phase invocation (full `elspais checks`) runs
# after the CI test workflows write results into build-reports/.
# Verifies: DIARY-OPS-traceability-validation/A
# Implements: DIARY-OPS-traceability-validation/B
begin_group "Requirement Validation - readiness (elspais v${ELSPAIS_VERSION})"

if [ "$ELSPAIS_RELEVANT_CHANGED" = "true" ]; then
  elspais --version

  # Capture stdout+stderr so we can both forward it to the log and scan
  # it for "info"-downgraded findings to surface as GitHub Actions
  # warning annotations (see lib/elspais-annotations.sh). The `if`-form
  # deactivates `set -e` for the elspais call so we can run the
  # annotation pass before re-asserting the exit code.
  elspais_exit=0
  # --lenient: warning-severity checks (e.g. code.no_traceability, configured
  # as "warning" in .elspais.toml) inform but do not fail the exit code. As of
  # elspais 0.118.16 warnings affect the exit code by default, so the flag is
  # required to preserve the repo's intended non-blocking severity policy.
  if elspais_output=$(elspais checks --spec --code --terms --lenient 2>&1); then
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

  echo "Requirement validation (readiness) passed"
else
  echo "Skipped - no changes under elspais scan paths [Passed]"
fi

end_group

# --- 4b. Elspais - requirement validation (report phase) [TODO: CUR-1329 follow-up] ---
# The report phase runs the full `elspais checks` (no category filter)
# so the TESTS and UAT categories are evaluated against JUnit/pytest
# result files written by the CI test workflows into build-reports/.
# This gate enforces tests.results, tests.results_stale, and the
# coverage-based tested/verified/uat checks.
#
# Not enabled yet: needs (1) each test-running workflow
# (sponsor-portal-ci.yml, clinical_diary-ci.yml,
# trial_data_types-ci.yml, qa-automation.yml, ios-build.yml,
# android-build.yml) to emit JUnit XML into build-reports/, and
# (2) those workflows to upload build-reports/ as an artifact that this
# job downloads before the report-phase call. Tracked under CUR-1329.
#
# When enabled, the block looks like:
#
#   begin_group "Requirement Validation - report (elspais v${ELSPAIS_VERSION})"
#   if [ "$ELSPAIS_RELEVANT_CHANGED" = "true" ]; then
#     elspais_exit=0
#     if elspais_output=$(elspais checks 2>&1); then
#       elspais_exit=0
#     else
#       elspais_exit=$?
#     fi
#     printf '%s\n' "$elspais_output"
#     source "$REPO_ROOT/.github/scripts/lib/elspais-annotations.sh"
#     emit_suppressed_warnings "$elspais_output"
#     if [ "$elspais_exit" -ne 0 ]; then
#       exit "$elspais_exit"
#     fi
#     echo "Requirement validation (report) passed"
#   else
#     echo "Skipped - no changes under elspais scan paths [Passed]"
#   fi
#   end_group

# --- 5. Migration headers — REMOVED ---
# The relational database/ schema and its SQL migrations were retired with the
# EVS cutover; the event store owns its own schema via the event_sourcing
# library (created at runtime, not via repo migrations). There are no SQL
# migration files in this repo to header-validate.

# --- 6. Code requirement traceability ---
# Per-unit `Implements:`/`Verifies:` annotations are validated by elspais
# (the readiness phase above) against the requirements graph. File-header
# requirement blocks were retired in the URS-v1 migration (CUR-1451); the
# unit of traceability is the assertion on each code unit, not a file header.

# --- 7. Documentation linting (if docs/spec changed) ---
if [ "$DOCS_CHANGED" = "true" ] || [ "$SPEC_CHANGED" = "true" ]; then
  begin_group "Documentation Linting (markdownlint-cli v${MARKDOWNLINT_CLI_VERSION})"

  markdownlint --config .markdownlint.json '**/*.md'

  echo "Documentation linting passed"
  end_group
fi

echo ""
echo "All validation checks passed"
