#!/bin/bash
# =====================================================
# start-phase.sh
# =====================================================
#
# Activates project phase protections (production, etc.)
#
# Usage:
#   ./start-phase.sh <PHASE>
#
# Arguments:
#   PHASE   Project phase: production
#
# Examples:
#   ./start-phase.sh production
#
# Exit codes:
#   0  Success
#   1  Invalid arguments or phase not supported
#   2  GitHub API error
#   3  Git operation failed
#
# =====================================================

set -e

PHASE="$1"

if [ -z "$PHASE" ]; then
    echo "❌ ERROR: Phase argument required"
    echo ""
    echo "Usage: $0 <PHASE>"
    echo ""
    echo "Supported phases:"
    echo "  production    Activate full workflow protection"
    echo ""
    exit 1
fi

# Validate phase
if [ "$PHASE" != "production" ]; then
    echo "❌ ERROR: Unsupported phase: $PHASE"
    echo ""
    echo "Supported phases:"
    echo "  production    Activate full workflow protection"
    echo ""
    exit 1
fi

# =====================================================
# Production Phase Activation
# =====================================================

echo "🚀 Activating PRODUCTION phase protections..."
echo ""

# Get repository info
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

REPO_OWNER=$(gh repo view --json owner -q .owner.login)
REPO_NAME=$(gh repo view --json name -q .name)

echo "Repository: $REPO_OWNER/$REPO_NAME"
echo ""

# =====================================================
# Step 1: Set Repository Variable
# =====================================================

echo "📋 Step 1: Setting WORKFLOW_PROTECTION_ENABLED=true"
echo ""

# Check if variable exists
if gh api "repos/$REPO_OWNER/$REPO_NAME/actions/variables/WORKFLOW_PROTECTION_ENABLED" &>/dev/null; then
    echo "   Variable exists, updating..."
    if gh api --method PATCH "repos/$REPO_OWNER/$REPO_NAME/actions/variables/WORKFLOW_PROTECTION_ENABLED" \
        -f value="true" &>/dev/null; then
        echo "   ✅ Variable updated: WORKFLOW_PROTECTION_ENABLED=true"
    else
        echo "   ❌ Failed to update variable"
        echo ""
        echo "Manual steps:"
        echo "1. Go to: https://github.com/$REPO_OWNER/$REPO_NAME/settings/variables/actions"
        echo "2. Find WORKFLOW_PROTECTION_ENABLED"
        echo "3. Click 'Update'"
        echo "4. Set value to: true"
        exit 2
    fi
else
    echo "   Variable doesn't exist, creating..."
    if gh api --method POST "repos/$REPO_OWNER/$REPO_NAME/actions/variables" \
        -f name="WORKFLOW_PROTECTION_ENABLED" \
        -f value="true" &>/dev/null; then
        echo "   ✅ Variable created: WORKFLOW_PROTECTION_ENABLED=true"
    else
        echo "   ❌ Failed to create variable"
        echo ""
        echo "Manual steps:"
        echo "1. Go to: https://github.com/$REPO_OWNER/$REPO_NAME/settings/variables/actions"
        echo "2. Click 'New repository variable'"
        echo "3. Name: WORKFLOW_PROTECTION_ENABLED"
        echo "4. Value: true"
        exit 2
    fi
fi

echo ""

# =====================================================
# Step 2: Activate CODEOWNERS
# =====================================================

echo "📋 Step 2: Activating CODEOWNERS enforcement"
echo ""

# Check if CODEOWNERS-PRE-PRODUCTION exists
if [ ! -f ".github/CODEOWNERS-PRE-PRODUCTION" ]; then
    echo "   ❌ ERROR: .github/CODEOWNERS-PRE-PRODUCTION not found"
    echo ""
    echo "   The file may have been already activated or doesn't exist."
    echo "   Check .github/ directory for CODEOWNERS file."
    exit 3
fi

# Check if CODEOWNERS already exists
if [ -f ".github/CODEOWNERS" ]; then
    echo "   ⚠️  WARNING: .github/CODEOWNERS already exists"
    echo ""
    echo "   CODEOWNERS enforcement may already be active."
    echo "   Review the file and delete CODEOWNERS-PRE-PRODUCTION if needed."
    exit 3
fi

# Create activation branch
BRANCH_NAME="activate-production-phase-$(date +%Y%m%d-%H%M%S)"
echo "   Creating branch: $BRANCH_NAME"

if ! git checkout -b "$BRANCH_NAME" &>/dev/null; then
    echo "   ❌ Failed to create branch"
    exit 3
fi

# Rename CODEOWNERS file
echo "   Renaming CODEOWNERS-PRE-PRODUCTION → CODEOWNERS"
if ! git mv .github/CODEOWNERS-PRE-PRODUCTION .github/CODEOWNERS; then
    echo "   ❌ Failed to rename CODEOWNERS file"
    git checkout -
    git branch -D "$BRANCH_NAME"
    exit 3
fi

# Commit changes
echo "   Committing changes"
if ! git commit -m "[OPS] Activate production phase workflow protection

Enable CODEOWNERS enforcement by renaming to active filename.

This activates admin-required reviews for:
- .github/workflows/ (all workflow files)
- .github/BOT_SECURITY.md (security policies)
- .github/rulesets/ (branch protection rules)
- .github/WORKFLOW_PROTECTION.md (protection docs)

Combined with WORKFLOW_PROTECTION_ENABLED=true, this provides
full workflow protection for production environment.

Implements: REQ-o00053

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"; then
    echo "   ❌ Commit failed"
    git checkout -
    git branch -D "$BRANCH_NAME"
    exit 3
fi

# Push branch
echo "   Pushing branch to remote"
if ! git push -u origin "$BRANCH_NAME"; then
    echo "   ❌ Failed to push branch"
    git checkout -
    git branch -D "$BRANCH_NAME"
    exit 3
fi

echo "   ✅ Branch pushed: $BRANCH_NAME"
echo ""

# Create pull request
echo "📋 Step 3: Creating pull request"
echo ""

PR_URL=$(gh pr create \
    --title "[OPS] Activate production phase workflow protection" \
    --body "## Production Phase Activation

This PR activates production-level workflow protections by enabling CODEOWNERS enforcement.

## Changes

- ✅ Renamed \`.github/CODEOWNERS-PRE-PRODUCTION\` → \`.github/CODEOWNERS\`
- ✅ Set \`WORKFLOW_PROTECTION_ENABLED=true\` (repository variable)

## Impact

Once merged, all changes to the following files will **require @Cure-HHT/admins approval**:
- \`.github/workflows/\` (all workflow files)
- \`.github/BOT_SECURITY.md\` (security policies)
- \`.github/rulesets/\` (branch protection)
- \`.github/WORKFLOW_PROTECTION.md\` (protection docs)

## Security Model

With both protections active:
1. **Automated alerts** detect workflow changes (WORKFLOW_PROTECTION_ENABLED)
2. **Required reviews** enforce admin approval (CODEOWNERS)
3. **Multi-layer defense** prevents unauthorized automation changes

## Review Checklist

- [ ] Verify repository variable \`WORKFLOW_PROTECTION_ENABLED=true\` is set
- [ ] Confirm team is ready for admin-gated workflow changes
- [ ] Review CODEOWNERS rules are appropriate

## References

- See \`.github/WORKFLOW_PROTECTION.md\` for complete documentation
- Implements: REQ-o00053

🤖 Generated with [Claude Code](https://claude.com/claude-code)" \
    2>&1)

if [ $? -eq 0 ]; then
    echo "   ✅ Pull request created: $PR_URL"
else
    echo "   ⚠️  PR creation may have failed, but changes are pushed"
    echo "   Create PR manually at:"
    echo "   https://github.com/$REPO_OWNER/$REPO_NAME/pull/new/$BRANCH_NAME"
fi

echo ""

# =====================================================
# Summary
# =====================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ PRODUCTION PHASE ACTIVATION COMPLETE"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Status:"
echo "  ✅ WORKFLOW_PROTECTION_ENABLED=true (active now)"
echo "  ⏳ CODEOWNERS enforcement (pending PR merge)"
echo ""
echo "Next steps:"
echo "  1. Review and merge PR: $PR_URL"
echo "  2. Test workflow protection:"
echo "     - Make a test change to .github/workflows/"
echo "     - Verify PR requires @Cure-HHT/admins approval"
echo "     - Verify security alert appears if bypass token used"
echo ""
echo "Documentation:"
echo "  .github/WORKFLOW_PROTECTION.md"
echo ""
echo "To deactivate protection:"
echo "  See deactivation section in WORKFLOW_PROTECTION.md"
echo ""

exit 0
