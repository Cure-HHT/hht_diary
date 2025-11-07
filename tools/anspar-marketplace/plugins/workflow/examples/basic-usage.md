# workflow Basic Usage Examples

This document provides practical examples of using the workflow plugin in your daily development workflow.

## Example 1: Simple Feature Development

```bash
# Start working on a new feature
cd tools/anspar-marketplace/plugins/workflow
./scripts/claim-ticket.sh CUR-100

# Make your changes
cd /path/to/your/worktree
# ... edit files ...

# Commit with requirement reference
git add .
git commit -m "Add new dashboard widget

Implements user dashboard customization feature.

Implements: REQ-d00042
"

# Release ticket when done
cd tools/anspar-marketplace/plugins/workflow
./scripts/release-ticket.sh "Feature complete"
```

## Example 2: Working with Multiple Tickets

```bash
# Start on ticket A
./scripts/claim-ticket.sh CUR-101

# Need to switch to higher priority ticket B
./scripts/switch-ticket.sh CUR-102 "Higher priority issue"

# Work on ticket B, then resume ticket A
./scripts/resume-ticket.sh CUR-101
```

## Example 3: Checking Active Ticket

```bash
# Get active ticket information
./scripts/get-active-ticket.sh --format=human

# Just get the ticket ID
TICKET=$(./scripts/get-active-ticket.sh --format=id)
echo "Working on: $TICKET"
```

## Example 4: Getting REQ Suggestions

```bash
# Get suggested requirement IDs for your commit
./scripts/suggest-req.sh

# Use in commit message
git commit -m "Fix authentication bug

Fixes: $(./scripts/suggest-req.sh | head -n1)
"
```

## Example 5: Viewing History

```bash
# View all workflow history
./scripts/list-history.sh

# View last 5 actions
./scripts/list-history.sh --limit=5

# View only ticket claims
./scripts/list-history.sh --action=claim

# Get JSON output for scripting
./scripts/list-history.sh --format=json
```

## Tips

- Always claim a ticket before making commits
- Include REQ references in commit messages
- Use `switch-ticket.sh` when changing focus
- Use `resume-ticket.sh` to see recently worked tickets
- Check history regularly to track your workflow

For more details, see the main [README.md](../README.md).
