#!/usr/bin/env bash
# cleanup-worktree.sh - Remove worktree after session completion
# Can be called automatically by end-session.sh or manually
#
# Usage:
#   ./cleanup-worktree.sh              # Clean up current agent's worktree
#   ./cleanup-worktree.sh --force      # Force remove even if not merged
#   ./cleanup-worktree.sh --keep-branch # Remove worktree but keep branch

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
FORCE=false
KEEP_BRANCH=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --force)
      FORCE=true
      shift
      ;;
    --keep-branch)
      KEEP_BRANCH=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--force] [--keep-branch]"
      exit 1
      ;;
  esac
done

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  Worktree Cleanup${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

# Check for agent config
CONFIG_FILE="$PROJECT_ROOT/untracked-notes/agent-ops.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${RED}Error: No agent config found${NC}"
  echo "Expected: $CONFIG_FILE"
  echo ""
  echo "This script should be run after agent initialization."
  exit 1
fi

# Read agent config
AGENT_NAME=$(jq -r '.agent_name' "$CONFIG_FILE" 2>/dev/null || echo "unknown")
AGENT_BRANCH=$(jq -r '.agent_branch' "$CONFIG_FILE" 2>/dev/null || echo "unknown")
WORKTREE_PATH=$(jq -r '.worktree_path' "$CONFIG_FILE" 2>/dev/null || echo "unknown")

echo -e "${BOLD}Agent:${NC} $AGENT_NAME"
echo -e "${BOLD}Branch:${NC} $AGENT_BRANCH"
echo -e "${BOLD}Worktree:${NC} $WORKTREE_PATH"
echo ""

# Check if worktree exists
if [ ! -d "$WORKTREE_PATH" ]; then
  echo -e "${YELLOW}Worktree does not exist: $WORKTREE_PATH${NC}"
  echo -e "${GREEN}Nothing to clean up.${NC}"
  exit 0
fi

# Check if worktree is registered with git
if ! git worktree list | grep -q "$WORKTREE_PATH"; then
  echo -e "${YELLOW}Worktree not registered with git${NC}"
  echo -e "${YELLOW}Path exists but git doesn't know about it: $WORKTREE_PATH${NC}"
  echo ""
  read -p "Remove directory anyway? (y/n): " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$WORKTREE_PATH"
    echo -e "${GREEN}✓ Removed directory${NC}"
  fi
  exit 0
fi

# Check if branch is merged (unless force)
if [ "$FORCE" = false ]; then
  echo -e "${CYAN}Checking if branch is merged to main...${NC}"

  # Fetch latest from remote
  git fetch origin main --quiet 2>/dev/null || true

  # Check if branch is merged
  if git branch --merged origin/main | grep -q "$AGENT_BRANCH" 2>/dev/null; then
    echo -e "${GREEN}✓ Branch is merged to main${NC}"
    SAFE_TO_DELETE=true
  elif git show-ref --verify --quiet "refs/heads/$AGENT_BRANCH"; then
    echo -e "${YELLOW}⚠ Branch exists but is NOT merged to main${NC}"
    SAFE_TO_DELETE=false
  elif git show-ref --verify --quiet "refs/remotes/origin/$AGENT_BRANCH"; then
    echo -e "${YELLOW}⚠ Branch exists remotely but is NOT merged to main${NC}"
    SAFE_TO_DELETE=false
  else
    echo -e "${YELLOW}⚠ Branch does not exist (may have been deleted)${NC}"
    SAFE_TO_DELETE=true
  fi

  if [ "$SAFE_TO_DELETE" = false ]; then
    echo ""
    echo -e "${RED}WARNING: Branch is not merged to main!${NC}"
    echo "Removing the worktree will NOT delete the branch, but you should verify"
    echo "that all work has been properly archived before proceeding."
    echo ""
    echo "Options:"
    echo "  1. Abort and check branch status"
    echo "  2. Continue (remove worktree, keep branch)"
    echo "  3. Force remove (use --force flag)"
    echo ""
    read -p "Continue with worktree removal? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Aborted."
      exit 1
    fi
  fi
fi

# Remove worktree
echo ""
echo -e "${CYAN}Removing worktree...${NC}"

git worktree remove "$WORKTREE_PATH" 2>/dev/null || {
  echo -e "${YELLOW}Warning: git worktree remove failed, trying force remove...${NC}"
  git worktree remove --force "$WORKTREE_PATH" 2>/dev/null || {
    echo -e "${RED}Error: Could not remove worktree via git${NC}"
    echo -e "${YELLOW}Attempting manual directory removal...${NC}"
    rm -rf "$WORKTREE_PATH"
  }
}

echo -e "${GREEN}✓ Worktree removed${NC}"

# Prune worktree references
git worktree prune 2>/dev/null || true

# Optionally delete branch
if [ "$KEEP_BRANCH" = false ]; then
  echo ""
  echo -e "${CYAN}Checking if branch should be deleted...${NC}"

  # Only offer to delete if merged or force
  if [ "$FORCE" = true ] || [ "$SAFE_TO_DELETE" = true ]; then
    echo "The worktree has been removed. Do you want to delete the branch as well?"
    echo ""
    read -p "Delete branch $AGENT_BRANCH? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      # Delete local branch
      if git show-ref --verify --quiet "refs/heads/$AGENT_BRANCH"; then
        git branch -d "$AGENT_BRANCH" 2>/dev/null || {
          echo -e "${YELLOW}Could not delete with -d, trying -D (force)...${NC}"
          git branch -D "$AGENT_BRANCH"
        }
        echo -e "${GREEN}✓ Deleted local branch${NC}"
      fi

      # Optionally delete remote branch
      if git show-ref --verify --quiet "refs/remotes/origin/$AGENT_BRANCH"; then
        echo ""
        read -p "Also delete remote branch? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          git push origin --delete "$AGENT_BRANCH" 2>/dev/null || {
            echo -e "${YELLOW}Warning: Could not delete remote branch${NC}"
          }
          echo -e "${GREEN}✓ Deleted remote branch${NC}"
        fi
      fi
    else
      echo -e "${YELLOW}Branch kept: $AGENT_BRANCH${NC}"
    fi
  else
    echo -e "${YELLOW}Branch not merged - keeping branch: $AGENT_BRANCH${NC}"
    echo "Use --force to delete unmerged branch"
  fi
fi

echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  Cleanup Complete${NC}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo "Summary:"
echo -e "  ${GREEN}✓${NC} Worktree removed: $WORKTREE_PATH"
if git show-ref --verify --quiet "refs/heads/$AGENT_BRANCH"; then
  echo -e "  ${YELLOW}•${NC} Branch kept: $AGENT_BRANCH"
else
  echo -e "  ${GREEN}✓${NC} Branch deleted: $AGENT_BRANCH"
fi
echo ""
