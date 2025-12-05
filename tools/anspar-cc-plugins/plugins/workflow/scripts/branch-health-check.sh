#!/bin/bash
# =====================================================
# branch-health-check.sh
# =====================================================
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00018: Git Hook Implementation
#   REQ-o00053: Branch Protection Enforcement
#   REQ-d00068: Enhanced Workflow New Work Detection
#
# Checks branch health status for workflow management.
# Detects merged, stale, and diverged branches.
#
# Usage:
#   ./branch-health-check.sh [--format=<FORMAT>] [--branch=<BRANCH>]
#
# Arguments:
#   --format=json     Output as JSON (default)
#   --format=human    Output human-readable summary
#   --format=status   Output only status code word
#   --branch=<name>   Check specific branch (default: current)
#   --stale-days=N    Days without commits to consider stale (default: 14)
#
# Exit codes:
#   0  Branch is healthy (can continue work)
#   1  Branch is merged (should not continue work)
#   2  Branch is squash-merged (should not continue work)
#   3  Branch is stale (warning, can continue)
#   4  Branch is diverged from remote (warning)
#   5  Error (not in git repo, etc.)
#
# Status codes:
#   healthy         Branch is ready for work
#   merged          Branch was merged (merge commit exists)
#   squash-merged   Branch content is in main (squash merge)
#   stale           No commits for >N days
#   diverged        Local and remote have diverged
#   detached        HEAD is detached (no branch)
#   protected       On main/master branch
#
# =====================================================

set -e

# =====================================================
# Arguments
# =====================================================

FORMAT="json"
BRANCH=""
STALE_DAYS=14

for arg in "$@"; do
    case $arg in
        --format=*)
            FORMAT="${arg#*=}"
            ;;
        --branch=*)
            BRANCH="${arg#*=}"
            ;;
        --stale-days=*)
            STALE_DAYS="${arg#*=}"
            ;;
    esac
done

# Validate format
if [[ "$FORMAT" != "json" && "$FORMAT" != "human" && "$FORMAT" != "status" ]]; then
    echo "❌ ERROR: Invalid format: $FORMAT" >&2
    echo "   Expected: json, human, or status" >&2
    exit 5
fi

# =====================================================
# Git Repository Check
# =====================================================

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    if [ "$FORMAT" = "human" ]; then
        echo "❌ Not in a git repository"
    elif [ "$FORMAT" = "status" ]; then
        echo "error"
    else
        echo '{"status": "error", "message": "Not in a git repository"}'
    fi
    exit 5
fi

# =====================================================
# Branch Detection
# =====================================================

if [ -z "$BRANCH" ]; then
    BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
fi

if [ -z "$BRANCH" ]; then
    if [ "$FORMAT" = "human" ]; then
        echo "⚠️  HEAD is detached - not on a branch"
    elif [ "$FORMAT" = "status" ]; then
        echo "detached"
    else
        echo '{"status": "detached", "message": "HEAD is detached, not on a branch", "canWork": false}'
    fi
    exit 5
fi

# =====================================================
# Protected Branch Check
# =====================================================

MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

if [ "$BRANCH" = "$MAIN_BRANCH" ] || [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
    if [ "$FORMAT" = "human" ]; then
        echo "🛡️  On protected branch: $BRANCH"
        echo "   Create a feature branch before making changes"
    elif [ "$FORMAT" = "status" ]; then
        echo "protected"
    else
        echo "{\"status\": \"protected\", \"branch\": \"$BRANCH\", \"message\": \"On protected branch\", \"canWork\": false}"
    fi
    exit 5
fi

# =====================================================
# Fetch Latest Remote Info (silent)
# =====================================================

git fetch origin --quiet 2>/dev/null || true

# =====================================================
# Merge Detection
# =====================================================

MERGED=false
SQUASH_MERGED=false
MERGE_INFO=""

# Check if branch was merged via merge commit
if git branch -r --merged "origin/$MAIN_BRANCH" 2>/dev/null | grep -q "origin/$BRANCH"; then
    MERGED=true
    MERGE_INFO="Branch has been merged into $MAIN_BRANCH"
fi

# Check for squash merge: does the diff between branch and main show no meaningful changes?
# This happens when all commits from the branch are already in main via squash
if [ "$MERGED" = false ]; then
    # Get the merge base
    MERGE_BASE=$(git merge-base "origin/$MAIN_BRANCH" "$BRANCH" 2>/dev/null || echo "")

    if [ -n "$MERGE_BASE" ]; then
        # Check if there are any commits on this branch not in main
        COMMITS_AHEAD=$(git rev-list --count "$MERGE_BASE".."$BRANCH" 2>/dev/null || echo "0")

        if [ "$COMMITS_AHEAD" -gt 0 ]; then
            # Check if the diff between branch and main is empty (squash-merged)
            DIFF_SIZE=$(git diff --stat "origin/$MAIN_BRANCH"..."$BRANCH" 2>/dev/null | wc -l || echo "999")

            if [ "$DIFF_SIZE" -eq 0 ]; then
                SQUASH_MERGED=true
                MERGE_INFO="Branch content appears to be in $MAIN_BRANCH (likely squash-merged)"
            fi
        fi
    fi
fi

# =====================================================
# Remote Sync Check
# =====================================================

DIVERGED=false
LOCAL_AHEAD=0
LOCAL_BEHIND=0
REMOTE_EXISTS=false

if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH" 2>/dev/null; then
    REMOTE_EXISTS=true
    LOCAL_AHEAD=$(git rev-list --count "origin/$BRANCH".."$BRANCH" 2>/dev/null || echo "0")
    LOCAL_BEHIND=$(git rev-list --count "$BRANCH".."origin/$BRANCH" 2>/dev/null || echo "0")

    if [ "$LOCAL_AHEAD" -gt 0 ] && [ "$LOCAL_BEHIND" -gt 0 ]; then
        DIVERGED=true
    fi
fi

# =====================================================
# Stale Branch Check
# =====================================================

STALE=false
DAYS_SINCE_COMMIT=0

LAST_COMMIT_DATE=$(git log -1 --format="%ct" "$BRANCH" 2>/dev/null || echo "0")
if [ "$LAST_COMMIT_DATE" -gt 0 ]; then
    NOW=$(date +%s)
    DAYS_SINCE_COMMIT=$(( (NOW - LAST_COMMIT_DATE) / 86400 ))

    if [ "$DAYS_SINCE_COMMIT" -ge "$STALE_DAYS" ]; then
        STALE=true
    fi
fi

# =====================================================
# Determine Final Status
# =====================================================

STATUS="healthy"
CAN_WORK=true
EXIT_CODE=0
MESSAGE=""
RECOMMENDATION=""

if [ "$MERGED" = true ]; then
    STATUS="merged"
    CAN_WORK=false
    EXIT_CODE=1
    MESSAGE="Branch has been merged into $MAIN_BRANCH"
    RECOMMENDATION="Switch to a new branch or delete this one: git branch -d $BRANCH"
elif [ "$SQUASH_MERGED" = true ]; then
    STATUS="squash-merged"
    CAN_WORK=false
    EXIT_CODE=2
    MESSAGE="Branch content is already in $MAIN_BRANCH (squash-merged)"
    RECOMMENDATION="This branch can be safely deleted: git branch -D $BRANCH"
elif [ "$DIVERGED" = true ]; then
    STATUS="diverged"
    CAN_WORK=true  # Warning only
    EXIT_CODE=4
    MESSAGE="Local branch has diverged from remote (${LOCAL_AHEAD} ahead, ${LOCAL_BEHIND} behind)"
    RECOMMENDATION="Rebase or merge with origin/$BRANCH: git pull --rebase origin $BRANCH"
elif [ "$STALE" = true ]; then
    STATUS="stale"
    CAN_WORK=true  # Warning only
    EXIT_CODE=3
    MESSAGE="No commits for $DAYS_SINCE_COMMIT days"
    RECOMMENDATION="Consider if this work is still relevant"
fi

# =====================================================
# Output
# =====================================================

case $FORMAT in
    json)
        jq -n \
            --arg status "$STATUS" \
            --arg branch "$BRANCH" \
            --arg mainBranch "$MAIN_BRANCH" \
            --argjson canWork "$CAN_WORK" \
            --arg message "$MESSAGE" \
            --arg recommendation "$RECOMMENDATION" \
            --argjson merged "$MERGED" \
            --argjson squashMerged "$SQUASH_MERGED" \
            --argjson stale "$STALE" \
            --argjson diverged "$DIVERGED" \
            --argjson remoteExists "$REMOTE_EXISTS" \
            --argjson localAhead "$LOCAL_AHEAD" \
            --argjson localBehind "$LOCAL_BEHIND" \
            --argjson daysSinceCommit "$DAYS_SINCE_COMMIT" \
            --argjson staleDays "$STALE_DAYS" \
            '{
                status: $status,
                branch: $branch,
                mainBranch: $mainBranch,
                canWork: $canWork,
                message: (if $message == "" then null else $message end),
                recommendation: (if $recommendation == "" then null else $recommendation end),
                details: {
                    merged: $merged,
                    squashMerged: $squashMerged,
                    stale: $stale,
                    diverged: $diverged,
                    remoteExists: $remoteExists,
                    localAhead: $localAhead,
                    localBehind: $localBehind,
                    daysSinceCommit: $daysSinceCommit,
                    staleDays: $staleDays
                }
            }'
        ;;

    human)
        echo "🔍 Branch Health: $BRANCH"
        echo ""

        case $STATUS in
            healthy)
                echo "✅ Status: HEALTHY"
                echo "   Branch is ready for work"
                ;;
            merged)
                echo "⛔ Status: MERGED"
                echo "   $MESSAGE"
                echo ""
                echo "   💡 $RECOMMENDATION"
                ;;
            squash-merged)
                echo "⛔ Status: SQUASH-MERGED"
                echo "   $MESSAGE"
                echo ""
                echo "   💡 $RECOMMENDATION"
                ;;
            stale)
                echo "⚠️  Status: STALE"
                echo "   $MESSAGE"
                echo ""
                echo "   💡 $RECOMMENDATION"
                ;;
            diverged)
                echo "⚠️  Status: DIVERGED"
                echo "   $MESSAGE"
                echo ""
                echo "   💡 $RECOMMENDATION"
                ;;
        esac

        echo ""
        echo "📊 Details:"
        echo "   Main branch: $MAIN_BRANCH"
        if [ "$REMOTE_EXISTS" = true ]; then
            echo "   Remote: origin/$BRANCH (exists)"
            echo "   Local ahead: $LOCAL_AHEAD commits"
            echo "   Local behind: $LOCAL_BEHIND commits"
        else
            echo "   Remote: not pushed"
        fi
        echo "   Last commit: $DAYS_SINCE_COMMIT days ago"
        ;;

    status)
        echo "$STATUS"
        ;;
esac

exit $EXIT_CODE
