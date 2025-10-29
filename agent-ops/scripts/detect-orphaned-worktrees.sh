#!/usr/bin/env bash
# detect-orphaned-worktrees.sh - Find and optionally clean up orphaned worktrees
# Detects worktrees that:
#   - Point to merged branches (safe to remove)
#   - Point to deleted branches (orphaned)
#   - Point to non-agent branches (mismatched)
#
# Usage:
#   ./detect-orphaned-worktrees.sh           # Detect and interactively clean up
#   ./detect-orphaned-worktrees.sh --list    # Just list, don't prompt for cleanup
#   ./detect-orphaned-worktrees.sh --auto    # Auto-remove safe orphans (merged/deleted)

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Parse arguments
MODE="interactive"  # interactive, list, auto

while [[ $# -gt 0 ]]; do
  case $1 in
    --list)
      MODE="list"
      shift
      ;;
    --auto)
      MODE="auto"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--list|--auto]"
      exit 1
      ;;
  esac
done

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  Orphaned Worktree Detection${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

# Fetch latest from remote
echo -e "${CYAN}Fetching latest from remote...${NC}"
git fetch --all --quiet 2>/dev/null || true
echo ""

# Get all worktrees (excluding main)
WORKTREES=$(git worktree list --porcelain | awk '
  /^worktree / { path=$2 }
  /^branch / { branch=$2; if (path != "") print path "|" branch; path=""; branch="" }
  /^detached/ { branch="(detached)"; if (path != "") print path "|" branch; path=""; branch="" }
' | tail -n +2)

if [ -z "$WORKTREES" ]; then
  echo -e "${GREEN}No additional worktrees found.${NC}"
  echo "All clean!"
  exit 0
fi

# Arrays to categorize worktrees
declare -a SAFE_TO_REMOVE=()      # Merged or deleted branches
declare -a PROBABLY_SAFE=()       # Agent branches not currently active
declare -a KEEP=()                # Active or unmerged non-agent branches

echo -e "${BOLD}Analyzing worktrees...${NC}"
echo ""

# Get current agent (if any)
CURRENT_AGENT=""
if [ -f "$PROJECT_ROOT/untracked-notes/agent-ops.json" ]; then
  CURRENT_AGENT=$(jq -r '.agent_name' "$PROJECT_ROOT/untracked-notes/agent-ops.json" 2>/dev/null || echo "")
fi

while IFS='|' read -r worktree_path branch_ref; do
  [ -z "$worktree_path" ] && continue

  # Extract branch name from ref
  branch=$(echo "$branch_ref" | sed 's|refs/heads/||' | sed 's|refs/remotes/origin/||')

  # Determine status
  status="unknown"
  reason=""
  category="keep"

  # Check if branch exists
  branch_exists=false
  if git show-ref --verify --quiet "refs/heads/$branch" || \
     git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    branch_exists=true
  fi

  if [ "$branch_exists" = false ]; then
    status="orphaned"
    reason="Branch deleted"
    category="safe"
  elif git branch --merged origin/main 2>/dev/null | grep -q "^[* ] $branch$"; then
    status="merged"
    reason="Merged to main"
    category="safe"
  elif [[ "$branch" == claude/* ]]; then
    # Agent branch
    agent_name=$(echo "$branch" | sed 's|claude/||')

    if [ "$agent_name" = "$CURRENT_AGENT" ]; then
      status="current"
      reason="Current agent"
      category="keep"
    else
      status="inactive_agent"
      reason="Inactive agent branch"
      category="probably_safe"
    fi
  else
    # Non-agent branch, not merged
    status="active"
    reason="Unmerged non-agent branch"
    category="keep"
  fi

  # Format status with color
  case "$status" in
    orphaned)
      status_display="${RED}🔴 ORPHANED${NC}"
      ;;
    merged)
      status_display="${GREEN}🟢 MERGED${NC}"
      ;;
    current)
      status_display="${CYAN}🔵 CURRENT${NC}"
      ;;
    inactive_agent)
      status_display="${YELLOW}🟡 INACTIVE AGENT${NC}"
      ;;
    active)
      status_display="${YELLOW}🟠 ACTIVE${NC}"
      ;;
    *)
      status_display="${RED}❓ UNKNOWN${NC}"
      ;;
  esac

  # Store in appropriate array
  entry="$worktree_path|$branch|$status|$reason|$status_display"

  case "$category" in
    safe)
      SAFE_TO_REMOVE+=("$entry")
      ;;
    probably_safe)
      PROBABLY_SAFE+=("$entry")
      ;;
    keep)
      KEEP+=("$entry")
      ;;
  esac

done <<< "$WORKTREES"

# Display results
echo -e "${BOLD}${GREEN}═══ Safe to Remove (${#SAFE_TO_REMOVE[@]}) ═══${NC}"
echo ""

if [ ${#SAFE_TO_REMOVE[@]} -eq 0 ]; then
  echo -e "${GREEN}None${NC}"
  echo ""
else
  for entry in "${SAFE_TO_REMOVE[@]}"; do
    IFS='|' read -r path branch status reason status_display <<< "$entry"
    echo -e "${BOLD}Worktree:${NC} $path"
    echo -e "${BOLD}Branch:${NC} $branch"
    echo -e "${BOLD}Status:${NC} $status_display - $reason"
    echo ""
  done
fi

echo -e "${BOLD}${YELLOW}═══ Probably Safe to Remove (${#PROBABLY_SAFE[@]}) ═══${NC}"
echo ""

if [ ${#PROBABLY_SAFE[@]} -eq 0 ]; then
  echo -e "${GREEN}None${NC}"
  echo ""
else
  for entry in "${PROBABLY_SAFE[@]}"; do
    IFS='|' read -r path branch status reason status_display <<< "$entry"
    echo -e "${BOLD}Worktree:${NC} $path"
    echo -e "${BOLD}Branch:${NC} $branch"
    echo -e "${BOLD}Status:${NC} $status_display - $reason"
    echo -e "${YELLOW}  Note: Verify this agent is not active elsewhere${NC}"
    echo ""
  done
fi

echo -e "${BOLD}${CYAN}═══ Keep (${#KEEP[@]}) ═══${NC}"
echo ""

if [ ${#KEEP[@]} -eq 0 ]; then
  echo -e "${GREEN}None${NC}"
  echo ""
else
  for entry in "${KEEP[@]}"; do
    IFS='|' read -r path branch status reason status_display <<< "$entry"
    echo -e "${BOLD}Worktree:${NC} $path"
    echo -e "${BOLD}Branch:${NC} $branch"
    echo -e "${BOLD}Status:${NC} $status_display - $reason"
    echo ""
  done
fi

# Exit if just listing
if [ "$MODE" = "list" ]; then
  echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
  exit 0
fi

# Interactive or auto cleanup
total_to_remove=$((${#SAFE_TO_REMOVE[@]} + ${#PROBABLY_SAFE[@]}))

if [ $total_to_remove -eq 0 ]; then
  echo -e "${GREEN}No worktrees to clean up!${NC}"
  exit 0
fi

echo -e "${BOLD}${CYAN}═══ Cleanup Options ═══${NC}"
echo ""

if [ "$MODE" = "auto" ]; then
  echo -e "${YELLOW}Auto mode: Removing safe worktrees only${NC}"
  echo ""

  for entry in "${SAFE_TO_REMOVE[@]}"; do
    IFS='|' read -r path branch status reason status_display <<< "$entry"
    echo -e "${CYAN}Removing: $path${NC}"
    git worktree remove "$path" 2>/dev/null || git worktree remove --force "$path"
    echo -e "${GREEN}✓ Removed${NC}"
    echo ""
  done

  git worktree prune 2>/dev/null || true

  echo -e "${GREEN}Auto cleanup complete.${NC}"
  echo "Removed ${#SAFE_TO_REMOVE[@]} worktree(s)"

else
  # Interactive mode
  echo "Found $total_to_remove worktree(s) that may need cleanup."
  echo ""
  echo "Options:"
  echo "  1. Remove safe worktrees only (merged/deleted)"
  echo "  2. Remove all detected worktrees (including inactive agents)"
  echo "  3. Interactive (choose each worktree)"
  echo "  4. Cancel"
  echo ""
  read -p "Choose option (1-4): " -n 1 -r
  echo ""
  echo ""

  case "$REPLY" in
    1)
      for entry in "${SAFE_TO_REMOVE[@]}"; do
        IFS='|' read -r path branch status reason status_display <<< "$entry"
        echo -e "${CYAN}Removing: $path (${branch})${NC}"
        git worktree remove "$path" 2>/dev/null || git worktree remove --force "$path"
        echo -e "${GREEN}✓ Removed${NC}"
        echo ""
      done
      ;;
    2)
      for entry in "${SAFE_TO_REMOVE[@]}" "${PROBABLY_SAFE[@]}"; do
        IFS='|' read -r path branch status reason status_display <<< "$entry"
        echo -e "${CYAN}Removing: $path (${branch})${NC}"
        git worktree remove "$path" 2>/dev/null || git worktree remove --force "$path"
        echo -e "${GREEN}✓ Removed${NC}"
        echo ""
      done
      ;;
    3)
      for entry in "${SAFE_TO_REMOVE[@]}" "${PROBABLY_SAFE[@]}"; do
        IFS='|' read -r path branch status reason status_display <<< "$entry"
        echo -e "${BOLD}Worktree:${NC} $path"
        echo -e "${BOLD}Branch:${NC} $branch"
        echo -e "${BOLD}Status:${NC} $status_display - $reason"
        echo ""
        read -p "Remove this worktree? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          git worktree remove "$path" 2>/dev/null || git worktree remove --force "$path"
          echo -e "${GREEN}✓ Removed${NC}"
        else
          echo -e "${YELLOW}Kept${NC}"
        fi
        echo ""
      done
      ;;
    4)
      echo "Cancelled."
      exit 0
      ;;
    *)
      echo "Invalid option. Cancelled."
      exit 1
      ;;
  esac

  git worktree prune 2>/dev/null || true

  echo -e "${GREEN}Cleanup complete.${NC}"
fi

echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
