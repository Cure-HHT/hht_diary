# Git Workflow Guide

## IMPLEMENTS REQUIREMENTS

- REQ-o00017: Version Control Workflow
- REQ-o00053: Branch Protection Enforcement

**Purpose**: Central guide for git workflow, branching strategy, and commit conventions in the Clinical Trial Diary Platform.

**Audience**: All developers

---

## 1. Overview - Project Workflow Philosophy

This project follows a **ticket-based development model with strict requirement traceability** enforced by git hooks and automated tooling. Every code change must:

1. Be claimed as part of an active ticket
2. Reference formal requirements (REQ-xxx) in commit messages
3. Follow branching conventions (feature/, fix/, release/)
4. Pass validation checks before merging to main

**Key Principles**:
- **Requirement-driven**: All work traces back to formal requirements (PRD, Ops, Dev)
- **Ticket-focused**: Work happens within Linear tickets with claimed ownership
- **Distributed-friendly**: Multiple developers can work on same or different tickets across concurrent worktrees
- **Auditable**: Complete history of what changed, why, and when

**Enforcement Mechanisms**:
- Git hooks prevent commits without active tickets and requirement references
- Pre-commit hooks validate requirement format and prevent secrets
- Post-commit hooks record workflow history
- PR validation ensures all quality gates pass before merge

---

## 2. Branching Strategy

### Main Branch Protection

The `main` branch is **protected and read-only** for direct commits.

**Rules**:
- NEVER commit directly to `main`
- ALWAYS create a new branch before making any changes
- All changes to `main` must come through pull requests
- PRs require passing CI/CD validation before merge

### Feature Branches

Use for new features and enhancements.

**Pattern**: `feature/{ticket-id}-{short-description}`

**Examples**:
```bash
git checkout -b feature/CUR-262-offline-sync
git checkout -b feature/CUR-265-auth-refactor
```

**Lifetime**: Deleted after PR merge

### Fix Branches

Use for bug fixes and patches.

**Pattern**: `fix/{ticket-id}-{short-description}`

**Examples**:
```bash
git checkout -b fix/CUR-270-auth-crash
git checkout -b fix/CUR-271-database-timeout
```

**Lifetime**: Deleted after PR merge

### Release Branches

Use for release preparation and version tagging.

**Pattern**: `release/v{version}`

**Examples**:
```bash
git checkout -b release/v1.0.0
git checkout -b release/v2.1.0
```

**Lifetime**: Kept long-term for backport fixes

### Branch Naming Conventions

- **Use lowercase**: `feature/cur-262-name`, not `Feature/CUR-262-Name`
- **Use hyphens**: `feature/cur-262-auth`, not `feature/cur_262_auth`
- **Include ticket ID**: Always reference the ticket (e.g., `CUR-262`)
- **Brief description**: 2-3 words describing the change
- **Valid characters**: alphanumeric, hyphens only

**Invalid names** (rejected):
- `feature/auth-refactor` - missing ticket ID
- `feature/CUR_262_auth` - use hyphens, not underscores
- `feature/cur262auth` - must include hyphens

---

## 3. Ticket-Based Development

### Claiming Tickets

Before starting work on a ticket, you must claim it using the workflow plugin.

**Command**:
```bash
cd tools/anspar-cc-plugins/plugins/workflow
./scripts/claim-ticket.sh <TICKET-ID> [AGENT-TYPE] [SPONSOR]
```

**Examples**:
```bash
# Claim ticket for core functionality
./scripts/claim-ticket.sh CUR-262

# Claim for Claude agent (default is human)
./scripts/claim-ticket.sh CUR-262 claude

# Claim for sponsor-specific work
./scripts/claim-ticket.sh CUR-262 human carina
./scripts/claim-ticket.sh CUR-262 claude callisto
```

**What happens**:
- Creates `.git/WORKFLOW_STATE` (per-worktree state file)
- Marks ticket as active in this worktree
- Enables commit validation with requirement references
- Records metadata (agent type, sponsor context, timestamp)

**Output**:
```
📋 Claiming ticket: CUR-262
   Worktree: /home/user/diary-worktrees/feature-xyz
   Branch: feature-xyz
   Agent: human
   Sponsor: (core functionality)
✅ Ticket claimed successfully!
```

### Releasing Tickets

When work on a ticket is complete or paused, release it.

**Command**:
```bash
./scripts/release-ticket.sh [REASON]
```

**Examples**:
```bash
# Work complete
./scripts/release-ticket.sh

# Work paused (will resume later)
./scripts/release-ticket.sh "Blocked - waiting for review"

# Switching to different ticket
./scripts/release-ticket.sh "Switching to higher priority issue"
```

### Switching Between Tickets

Use this to pause current work and switch to another ticket.

**Command**:
```bash
./scripts/switch-ticket.sh <NEW-TICKET-ID> <REASON>
```

**Example**:
```bash
# Currently working on CUR-262, urgent bug found
./scripts/switch-ticket.sh CUR-270 "P0 production bug"

# This automatically releases CUR-262 and claims CUR-270
```

### Resuming Paused Work

Resume a ticket you were working on previously.

**Command** (interactive):
```bash
./scripts/resume-ticket.sh
```

**Output**:
```
📋 Recently Released Tickets

Select a ticket to resume:

  1  CUR-262
     Released: 2025-10-30 12:00
     Reason: Blocked - waiting for review

  2  CUR-260
     Released: 2025-10-29 15:30
     Reason: Work complete

Enter number (1-2) or 'q' to quit: 1

📋 Resuming ticket: CUR-262
✅ Successfully resumed ticket CUR-262
```

**Direct resume**:
```bash
./scripts/resume-ticket.sh CUR-262
```

### Linear Integration

The workflow plugin integrates with Linear for ticket tracking (optional).

**Configuration**:
- Set `LINEAR_API_TOKEN` environment variable (via Doppler)
- Ticket status syncs with workflow state

**What syncs**:
- Claiming ticket → Linear status = "In Progress"
- Releasing ticket → Linear status updated (optional comment added)
- Requirements fetched from ticket (if available)

**Note**: Workflow state (`.git/WORKFLOW_STATE`) is authoritative for worktree ownership. Multiple worktrees can work on same ticket simultaneously.

---

## 4. Commit Message Conventions

### Requirement References (MANDATORY)

Every commit MUST reference at least one formal requirement.

**Format**: `Implements: REQ-xxx` or `Fixes: REQ-xxx` in commit message body

**Requirement ID Format**: `REQ-{type}{number}` where:
- **Type**: `p` (PRD), `o` (Ops), or `d` (Dev)
- **Number**: 5 digits (e.g., `00027`)

**Examples**:
```
REQ-d00027    - Dev requirement
REQ-p00042    - Product requirement
REQ-o00015    - Operations requirement
```

### Commit Message Template

**Structure**:
```
[TICKET-ID] Brief imperative summary (50 chars or less)

Detailed explanation of what changed and why (if needed).
Context about the change, implementation notes, etc.

Implements: REQ-d00027
```

**Alternatively** (without ticket prefix):
```
Brief imperative summary

Longer explanation here.

Implements: REQ-d00027, REQ-p00042
```

### Valid Commit Examples

**Single requirement**:
```
[CUR-262] Add offline sync to diary entries

Implements offline-first data entry using local SQLite database
with background synchronization to cloud when connectivity restored.

Implements: REQ-p00006
```

**Multiple requirements**:
```
[CUR-265] Refactor authentication module

Split authentication concerns into auth service and permission validator.
Improves testability and reduces coupling with UI layer.

Implements: REQ-d00027, REQ-d00029
```

**Bug fix**:
```
[CUR-270] Fix auth token expiration crash

Properly handle token expiration in sync service instead of
crashing with NPE.

Fixes: REQ-d00089
```

### Invalid Commit Examples (Will Be Rejected)

**No requirement reference**:
```
Add feature X  ❌ No Implements: or Fixes: line
```

**Wrong format**:
```
Implements REQ-d00027  ❌ Missing colon
Implements: REQd00027  ❌ Missing hyphen
Implements: REQ-d0027  ❌ Number not 5 digits
```

**Multiple issues**:
```
feat: Add something

Implements: REQ-x00001  ❌ Type 'x' is invalid (must be p, o, d)
```

### Getting Requirement Suggestions

If unsure which requirements to reference, get suggestions:

```bash
cd tools/anspar-cc-plugins/plugins/workflow
./scripts/suggest-req.sh

# Output:
# REQ-d00027
# REQ-p00042
```

The suggestion script looks at:
1. Active ticket in `.git/WORKFLOW_STATE`
2. Recent commits in this branch
3. Changed files with requirement headers

---

## 5. Pull Request Process

### Creating Pull Requests

**Before creating PR**:
1. Ensure your branch is up-to-date with main:
   ```bash
   git pull origin main
   ```
2. All commits have requirement references
3. All local tests pass
4. No secrets in staged files (pre-commit hook enforces this)

**Create PR** (using GitHub CLI or web interface):
```bash
# Using GitHub CLI
gh pr create --title "Feature description" \
  --body "## Summary

Implementation details here.

## Test Plan
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing complete

Implements: REQ-d00027"
```

**PR Title Format**: `[TICKET-ID] Brief description`

**Examples**:
```
[CUR-262] Add offline sync for diary entries
[CUR-270] Fix auth token expiration crash
[CUR-265] Refactor authentication module
```

### PR Validation Checks

Automatic checks run on all PRs:

- **Requirement validation**: All requirements referenced in commits are valid
- **Traceability matrix**: Regenerated to reflect spec/ changes
- **Secret scanning**: Gitleaks detects exposed credentials
- **Code analysis**: Linting and format checks
- **Tests**: Unit and integration tests must pass
- **Coverage**: Code coverage requirements (configurable)

**PR blocked if**:
- Any validation check fails
- Commits missing requirement references
- Secrets detected in code
- Tests fail
- Coverage drops below threshold

### Review Process

1. **Author** creates PR with complete description and test plan
2. **Reviewers** examine code, requirements, and test evidence
3. **Comments** on code or requirement links if issues found
4. **Approval** once satisfied with changes and traceability
5. **Squash merge** to main (optional, based on project policy)

### Merging Requirements

**Before merge**, all must be true:

- [ ] All validation checks passing
- [ ] At least one approval from reviewer
- [ ] No merge conflicts
- [ ] Branch is up-to-date with main
- [ ] All commits reference requirements
- [ ] Tests passing locally and in CI

**Release ticket when merged** (optional but recommended):

```bash
./scripts/release-ticket.sh "Work complete - merged to main"
```

---

## 6. Requirement Traceability

### Why Every Commit Needs REQ References

**Regulatory compliance**: FDA 21 CFR Part 11 requires complete audit trails showing what code implements which requirements.

**Impact analysis**: When a requirement changes, you can find all affected code using `git log --grep="REQ-d00027"`.

**Traceability matrix**: Automated tools generate matrices showing requirement-to-code relationships for audits.

**Code review**: Reviewers can verify code aligns with stated requirements.

**Root cause analysis**: When bugs occur, you can trace back to requirement to understand intent.

### Git Hook Enforcement

Two git hooks enforce requirement traceability:

#### 1. Pre-Commit Hook (`.githooks/pre-commit`)

**Runs before commit is created**

**Checks**:
1. Active ticket claimed (from `.git/WORKFLOW_STATE`)
2. No secrets in staged files (gitleaks)

**Blocks commit if**:
- No active ticket claimed
- Secrets detected

**Error**:
```
❌ ERROR: No active ticket claimed for this worktree

Before committing, claim a ticket:
  cd tools/anspar-cc-plugins/plugins/workflow
  ./scripts/claim-ticket.sh <TICKET-ID>
```

#### 2. Commit-Msg Hook (`.githooks/commit-msg`)

**Runs after commit message is written**

**Checks**: Commit message contains at least one REQ-{type}{number} reference

**Blocks commit if**:
- No REQ reference found
- Invalid format

**Error**:
```
❌ ERROR: Commit message must contain at least one requirement reference

Expected format: REQ-{type}{number}
  Type: p (PRD), o (Ops), d (Dev)
  Number: 5 digits (e.g., 00042)

Examples:
  Implements: REQ-p00042
  Implements: REQ-d00027, REQ-o00015
  Fixes: REQ-d00089
```

#### 3. Post-Commit Hook (`.githooks/post-commit`)

**Runs after commit succeeds**

**Records**: Commit hash and requirement references in `.git/WORKFLOW_STATE` history

**Never blocks commits** (informational only)

### Finding Requirement IDs

**Search spec/ directory**:
```bash
# Find all requirements about authentication
grep -r "authentication" spec/

# Find specific requirement
grep "REQ-d00027" spec/

# Find all requirements by type
grep "REQ-d" spec/       # Dev requirements
grep "REQ-p" spec/       # Product requirements
grep "REQ-o" spec/       # Operations requirements
```

**View spec/INDEX.md**:
```bash
cat spec/INDEX.md    # Complete index of all requirements

# With line numbers
cat -n spec/INDEX.md
```

**Get requirement details**:
```bash
# Using simple-requirements plugin (if available)
python3 tools/anspar-cc-plugins/plugins/simple-requirements/scripts/get-requirement.py REQ-d00027
```

---

## 7. Working with Multiple Worktrees

### When to Use Worktrees

Use git worktrees to work on multiple tickets simultaneously without switching branches:

**Good use cases**:
- Different tickets, different features → separate worktrees
- Same ticket, multiple concerns → separate worktrees
- Code review while working → read-only worktree
- Testing multiple branches → separate worktrees

**Not needed**:
- Single feature with related commits → use regular branches
- Quick fix → stash and create branch temporarily

### Creating Worktrees

```bash
# Create worktree for new feature (auto-creates branch)
git worktree add ../diary-worktrees/feature-xyz feature/CUR-262-name

# Create worktree for existing branch
git worktree add ../diary-worktrees/feature-abc feature/CUR-263-name

# List all worktrees
git worktree list

# Output:
# /home/user/diary-worktrees/main     xxxxxx (detached)
# /home/user/diary-worktrees/feature-a yyyyy [feature/CUR-262-name]
# /home/user/diary-worktrees/feature-b zzzz [feature/CUR-263-name]
```

### Worktree Isolation

Each worktree has **completely independent state**:

- **`.git/WORKFLOW_STATE`**: Per-worktree (different for each)
- **Working directory**: Isolated (changes don't affect other worktrees)
- **Commits**: Shared across worktrees (same git repository)

**This means**:
```bash
# Worktree A: feature-a/
./scripts/claim-ticket.sh CUR-262
# → Only this worktree can commit

# Worktree B: feature-b/
./scripts/claim-ticket.sh CUR-263
# → This worktree has different active ticket

# Worktree A commits
git commit -m "Work\n\nImplements: REQ-d00027"  # ✅ Succeeds (CUR-262 active)

# Worktree B commits
git commit -m "Work\n\nImplements: REQ-d00027"  # ✅ Succeeds (CUR-263 active)

# Each worktree maintains its own claim!
```

### Switching Between Worktrees

```bash
# CD to different worktree
cd ../diary-worktrees/feature-b

# Check active ticket
./tools/anspar-cc-plugins/plugins/workflow/scripts/get-active-ticket.sh --format=human

# Switch tickets (pauses current, claims new)
./tools/anspar-cc-plugins/plugins/workflow/scripts/switch-ticket.sh CUR-265 "Need to prioritize blocker"
```

### Deleting Worktrees

```bash
# Finish work, release ticket
./scripts/release-ticket.sh "Work complete"

# Go back to main worktree
cd ../diary-worktrees/main

# Remove worktree
git worktree remove ../diary-worktrees/feature-a

# Verify removal
git worktree list
```

---

## 8. Best Practices

### Atomic Commits

**Make small, focused commits** that can be understood in isolation.

**Good**:
```
Commit 1: Extract auth service to separate module
Commit 2: Add unit tests for auth service
Commit 3: Update authentication flow to use service
```

**Bad**:
```
Commit 1: Extract auth service, add tests, update flow, fix UI bugs, and update docs
```

**Benefits**:
- Easy to understand what each commit does
- Can revert individual commits if needed
- Better code review
- Easier to find regressions with `git bisect`

### Clear Commit Messages

**Use imperative mood** (as if giving instructions):

```
✅ Add offline sync feature
✅ Fix auth token expiration
✅ Refactor database layer
✅ Update requirement documentation

❌ Added offline sync
❌ Fixed auth token expiration
❌ Refactors database layer
❌ Updating requirement documentation
```

**Explain why**, not just what:

```
✅ Replace synchronous API calls with async streams

Previous synchronous implementation caused UI freezing
when API latency increased. Async streams allow UI to
remain responsive while data loads.

Implements: REQ-d00027

❌ Make API calls async
```

### Regular Pulls from Main

Before creating PRs, always pull latest main:

```bash
# From your feature branch
git pull origin main

# Or if you have uncommitted changes
git stash
git pull origin main
git stash pop
```

**Why**: Prevents merge conflicts and ensures CI runs against latest code

### Testing Before Committing

```bash
# Run tests before commit
npm test        # JavaScript/Node
flutter test    # Flutter
pytest          # Python

# Or set up pre-commit hook to auto-run tests
# (configure in .githooks/pre-commit)

# Only commit if tests pass
git commit -m "feature\n\nImplements: REQ-xxx"
```

### Don't Commit Secrets

**Never commit**:
- API keys
- Database passwords
- Private keys
- Tokens or credentials
- Configuration with secrets

**Instead**:
- Store in environment variables
- Use Doppler for secret management
- Reference secrets in comments (don't include values)

**Pre-commit hook blocks secrets** (gitleaks integration):

```bash
# This will be blocked:
echo "API_KEY=sk_live_abcd1234" > config.js
git add config.js
git commit -m "Add API config"

# ❌ BLOCKED: Secrets detected!

# Instead:
echo "API_KEY=${API_KEY}" > config.js  # Use env var
git add config.js
git commit -m "Add API config (using env var)\n\nImplements: REQ-d00027"

# ✅ Success
```

---

## 9. Common Workflows

### Starting a New Feature

```bash
# 1. Create feature branch from main
git checkout main
git pull origin main
git checkout -b feature/CUR-262-offline-sync

# 2. Claim ticket for this worktree
cd tools/anspar-cc-plugins/plugins/workflow
./scripts/claim-ticket.sh CUR-262

# 3. Make changes and commits
cd /path/to/repo
# ... edit files ...
git add .
git commit -m "Add offline sync

Implements: REQ-p00006"

# 4. Create pull request
git push origin feature/CUR-262-offline-sync
gh pr create --title "[CUR-262] Add offline sync" \
  --body "## Summary\nImplements offline-first sync\n\nImplements: REQ-p00006"

# 5. After merge, release ticket
cd tools/anspar-cc-plugins/plugins/workflow
./scripts/release-ticket.sh "Work complete - merged"
```

### Fixing a Bug

```bash
# 1. Create fix branch
git checkout main
git pull origin main
git checkout -b fix/CUR-270-auth-crash

# 2. Claim ticket
cd tools/anspar-cc-plugins/plugins/workflow
./scripts/claim-ticket.sh CUR-270

# 3. Debug and fix issue
# ... make fix ...

# 4. Write test reproducing bug (if not covered)
# ... write test ...

# 5. Commit with fix reference
git add .
git commit -m "Fix auth token expiration crash

Properly handle token expiration in sync service
instead of crashing with null reference exception.

Test: Added test_handle_expired_token

Fixes: REQ-d00089"

# 6. Create PR
gh pr create --title "[CUR-270] Fix auth crash" \
  --body "## Summary\nFixes NPE on token expiration\n\nFixes: REQ-d00089"
```

### Working on Multiple Tasks

```bash
# 1. Start work on feature A
git worktree add ../feature-a feature/CUR-262-name
cd ../feature-a
./scripts/claim-ticket.sh CUR-262
# ... work on feature A ...

# 2. Start work on feature B in different worktree
git worktree add ../feature-b feature/CUR-263-name
cd ../feature-b
./scripts/claim-ticket.sh CUR-263
# ... work on feature B ...

# 3. Switch to urgent bug in different worktree
git worktree add ../fix-bug fix/CUR-270-name
cd ../fix-bug
./scripts/claim-ticket.sh CUR-270
# ... fix bug ...

# 4. Each worktree maintains independent state
git worktree list
# /home/user/.../feature-a [CUR-262]
# /home/user/.../feature-b [CUR-263]
# /home/user/.../fix-bug [CUR-270]
```

### Pausing and Resuming Work

```bash
# 1. Working on feature
./scripts/claim-ticket.sh CUR-262
# ... work ...

# 2. Urgent priority interrupts
./scripts/switch-ticket.sh CUR-270 "P0 production bug reported"

# 3. Work on urgent bug
# ... fix bug ...
git commit -m "Fix bug\n\nImplements: REQ-d00089"

# 4. Release bug fix
./scripts/release-ticket.sh "Bug fixed"

# 5. Resume original feature
./scripts/resume-ticket.sh
# Shows: [1] CUR-262 (Released: 2hrs ago)
# Enter selection: 1
# ✅ Resumed CUR-262

# 6. Continue work
# ... continue feature ...
git commit -m "Continue feature\n\nImplements: REQ-d00027"
```

### Handling Merge Conflicts

```bash
# 1. Pull latest main into your feature branch
git pull origin main

# 2. If conflicts occur, resolve them
# git shows conflicted files
# Edit files to resolve conflicts
# Remove conflict markers (<<<<, ====, >>>>)

# 3. Stage resolved files
git add <resolved-file>

# 4. Complete merge
git commit

# 5. If you've already committed on main (oops):
git rebase origin/main

# Rebase conflicts require similar resolution
```

---

## 10. References

### In This Project

- **CLAUDE.md**: Project-wide instructions
- **Branch Protection**: CLAUDE.md "Critical Rules" section
- **Requirement Format**: `spec/requirements-format.md`
- **Requirement Index**: `spec/INDEX.md` (complete list of all REQ-xxx)
- **Development Guide**: `spec/dev-requirements-management.md`
- **ADR Process**: `docs/adr/README.md`

### Tools and Plugins

- **Workflow Plugin**: `tools/anspar-cc-plugins/plugins/workflow/README.md`
- **Requirement Tracking**: `tools/anspar-cc-plugins/plugins/simple-requirements/TRACKING-WORKFLOW.md`
- **Requirements Tools**: `tools/requirements/README.md`

### External Resources

- **Git Documentation**: https://git-scm.com/doc
- **GitHub CLI**: https://cli.github.com/
- **GitHub Workflows**: https://docs.github.com/en/actions
- **FDA 21 CFR Part 11**: https://www.fda.gov/regulatory-information

### Related Guides

- **Setup Guide**: `docs/setup-team-onboarding.md`
- **Architecture Decisions**: `docs/adr/`
- **Database Guide**: `docs/database-supabase-pre-deployment-audit.md`

---

## Troubleshooting

### "No active ticket claimed"

**Problem**: Attempting commit without claiming ticket

**Solution**:
```bash
cd tools/anspar-cc-plugins/plugins/workflow
./scripts/claim-ticket.sh <TICKET-ID>
```

### "Commit message must contain requirement reference"

**Problem**: Commit message missing REQ-xxx reference

**Solution**:
```bash
# Get suggestions for which requirements to reference
./scripts/suggest-req.sh

# Then commit with REQ reference:
git commit -m "Your message

Implements: REQ-d00027"
```

### "Branch is outdated with main"

**Problem**: Your branch is behind main, causing merge conflicts

**Solution**:
```bash
git pull origin main
# Resolve any conflicts
git push origin <branch-name>
```

### "Secrets detected in staged files"

**Problem**: Attempted to commit credentials or API keys

**Solution**:
```bash
# Remove secret from file
# Use environment variables instead: API_KEY=${API_KEY}

# Unstage file
git restore --staged <file>

# Re-stage with secret removed
git add <file>

# Try commit again
git commit -m "message\n\nImplements: REQ-xxx"
```

### "jq command not found"

**Problem**: Workflow scripts require jq for JSON parsing

**Solution**:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# Or use dev container (includes jq pre-installed)
```

---

**Last Updated**: 2025-11-11
**Version**: 1.0
**Status**: Active
