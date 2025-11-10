# Plugin Architecture Patterns

This document defines the architectural patterns and best practices for Claude Code plugins in the anspar-marketplace.

## Table of Contents

1. [Core Principles](#core-principles)
2. [Tool Type Decision Matrix](#tool-type-decision-matrix)
3. [Thin Delegator Pattern](#thin-delegator-pattern)
4. [Failure Visibility Principle](#failure-visibility-principle)
5. [Search Space Minimization](#search-space-minimization)
6. [Sibling Agent Architecture](#sibling-agent-architecture)
7. [Hooks as Workflow Bumpers](#hooks-as-workflow-bumpers)
8. [Environment Variable Enforcement](#environment-variable-enforcement)
9. [Dual Usage Patterns](#dual-usage-patterns)
10. [Error Handling Templates](#error-handling-templates)

---

## Core Principles

### 1. Single Responsibility
Each plugin has ONE clear purpose. Don't mix concerns across plugin boundaries.

**Good:**
- `linear-integration`: Linear ticket management only
- `workflow`: Git workflow enforcement only
- `spec-compliance`: Spec directory validation only

**Bad:**
- A plugin that handles both tickets AND database migrations
- A plugin that mixes compliance checking with deployment

### 2. Separation of Concerns
- Plugin code stays in its plugin directory
- Cross-plugin features use orchestrator pattern (scripts that invoke multiple plugins)
- Sub-agents for plugin-specific capabilities

### 3. Modularity
- Reusable utilities can be extracted to shared locations
- Scripts should be composable (take input, produce output)
- Clear interfaces between components

### 4. Minimize Search Space
Organize tools so agents can find the right capability in <30 seconds through:
- Categorization (agents/, commands/, hooks/, scripts/, skills/)
- Upfront reference tables
- Clear, descriptive naming

---

## Tool Type Decision Matrix

When building plugin functionality, choose the right tool type:

| Tool Type | When to Use | Example | Access Pattern |
|-----------|-------------|---------|----------------|
| **Skill** | Reusable automation that agents invoke | `create-ticket.sh` | Agent → Bash → Skill |
| **Command** | User-initiated workflows | `/ticket new` | User → Main → Command |
| **Hook** | Proactive workflow guidance | `UserPromptSubmit` | Automatic on event |
| **Script** | Low-level executable | `validate.py` | Called by skills/hooks |
| **Agent** | Complex decision-making | `linear-agent` | Main → Task → Agent |

### Decision Flow

```
Need to add functionality?
│
├─ Does it require complex decisions? → Agent
│
├─ Is it user-initiated? → Command (slash command)
│
├─ Should it trigger automatically? → Hook
│
├─ Is it reusable automation? → Skill
│
└─ Is it a low-level utility? → Script
```

### Examples

**Creating a Linear ticket:**
- ❌ Script only: Too low-level for agent use
- ❌ Command only: Not reusable by agents
- ✅ Skill + Command: Skill for agents, command wraps it for users
- ✅ Agent: When decision-making needed (which project? labels? priority?)

**Validating requirements:**
- ❌ Agent: Overkill for simple validation
- ✅ Script + Hook: Script does validation, hook triggers it on events

**Claiming tickets:**
- ✅ Skill: Core automation
- ✅ Command: User-friendly wrapper (`/workflow:claim`)
- ✅ Hook: Proactive reminder if user switches context

---

## Thin Delegator Pattern

**Definition:** Agents invoke existing skills rather than implementing functionality inline. If a skill fails, the agent reports the error clearly - it does NOT re-implement the skill.

### The Problem

**Bad Example (linear-agent doing 30+ operations):**
```markdown
## Available Tools

You have access to:
- LinearFetchTickets: Fetch tickets from Linear
- LinearCreateTicket: Create a new ticket
- LinearUpdateTicket: Update ticket details
```

The agent sees these "tools" but they don't actually exist in Claude Code. The agent then implements the entire Linear API interaction inline:

```
1. Parse user request
2. Construct API request
3. Set headers
4. Make HTTP call
5. Parse response
6. Handle pagination
7. Format results
8. Present to user
... (20+ more steps)
```

### The Solution

**Good Example (linear-agent as thin delegator):**
```markdown
## Available Skills

Use the Bash tool to invoke these skills:

### Fetch Tickets
node ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-tickets.js --format=json [--status=active|backlog]

### Create Ticket
node ${CLAUDE_PLUGIN_ROOT}/scripts/create-ticket.js --title="Title" --description="Description" [--project=PROJECT_ID]

### Update Ticket
node ${CLAUDE_PLUGIN_ROOT}/scripts/update-ticket.js TICKET_ID --status=STATUS
```

The agent invokes the skill:
```bash
node /path/to/linear-integration/scripts/fetch-tickets.js --format=json --status=active
```

**Result:** 1 operation instead of 30+

### When Skills Should Be Used

Agents should use skills when:
- The skill provides the exact functionality needed
- The task is automation-focused (fetch, create, update, validate)
- The skill is well-documented with clear parameters

Agents should NOT use inline implementation when:
- A skill exists but fails (see Failure Visibility Principle)
- The task could be "simplified" by doing it inline
- The agent "thinks it can do it better"

---

## Failure Visibility Principle

**Core Principle:** When a skill fails, agents must report the error clearly. They must NOT work around failures by re-implementing the skill inline.

### Why This Matters

If an agent works around skill failures:
- Bugs in skills go unnoticed
- Incorrect invocations aren't caught
- Maintenance burden increases (fixing bugs in agents instead of skills)
- Skills become untested and unreliable

### The Right Response to Skill Failure

**CRITICAL RULE:** If you encounter an error when invoking a skill, **ALWAYS** report it to the user and ask how to proceed.

When a skill fails, the agent should:

1. **Report the error with full context**
2. **Suggest what might be wrong** (invocation? environment? skill bug?)
3. **Ask the user how to proceed** (fix skill? report bug? wait?)
4. **NEVER work around it** - even if user asks "can you help?" or similar

**Why ask the user?** This prevents agents from making assumptions about acceptable workarounds. The user decides whether to fix the skill, use a different approach, or wait.

### Error Reporting Templates

#### Template 1: Missing Environment Variable
```
❌ Skill 'fetch-tickets' failed

Error: LINEAR_API_TOKEN environment variable not set

This skill requires LINEAR_API_TOKEN to be configured. Either:
1. I invoked the skill incorrectly (should have checked prerequisites)
2. Your environment is not configured (run: export LINEAR_API_TOKEN=...)

I cannot proceed without this being fixed. I will NOT fetch tickets manually.
```

#### Template 2: Invalid Parameters
```
❌ Skill 'create-ticket' failed

Error: --project parameter required

I invoked: node scripts/create-ticket.js --title="Fix bug"
Expected: node scripts/create-ticket.js --title="Fix bug" --project=PROJECT_ID

Either:
1. I need to provide the --project parameter (which project should I use?)
2. The skill should have a default project (skill bug?)

Please clarify so I can invoke correctly, or fix the skill if it should have defaults.
```

#### Template 3: Unexpected Failure
```
❌ Skill 'update-ticket' failed

Error: HTTP 404 - Ticket CUR-999 not found

I invoked: node scripts/update-ticket.js CUR-999 --status=done

Possibilities:
1. The ticket ID is wrong (does CUR-999 exist?)
2. The API token lacks access (permissions issue?)
3. The skill has a bug (incorrect API endpoint?)

How would you like me to proceed?
1. I can investigate why CUR-999 doesn't exist
2. You can provide the correct ticket ID
3. We can check if the skill needs fixing
```

#### Template 4: User Asks for Help After Failure
```
User: "The search-tickets skill failed. Can you help?"

❌ WRONG Response:
"Sure! I'll use fetch-tickets and filter the results manually..."

✅ CORRECT Response:
"I can help by:
1. Fixing the search-tickets skill to use the current Linear API
2. Reporting this as a bug for the plugin maintainer
3. Waiting for you to fix the skill

I cannot work around the broken skill by fetching all tickets and filtering manually,
as this hides the problem and creates inefficient workarounds.

Which approach would you prefer?"
```

### Anti-Pattern: Working Around Failures

**❌ NEVER DO THIS:**
```markdown
Agent: The fetch-tickets skill failed, so I'll fetch the tickets using curl instead...

*Agent proceeds to implement entire Linear API interaction inline*
```

**❌ ALSO NEVER DO THIS:**
```markdown
User: "Can you help?"
Agent: "Sure! I'll use fetch-tickets and grep to search instead..."

*Agent works around broken search-tickets skill*
```

**✅ CORRECT APPROACH:**
```markdown
Agent: The fetch-tickets skill failed with error: "LINEAR_API_TOKEN not set"

I cannot fetch tickets without this environment variable. Either:
1. Set LINEAR_API_TOKEN in your environment
2. Fix the skill if it should handle missing tokens differently

I will not implement an alternative fetch mechanism.
```

---

## Search Space Minimization

**Goal:** Agents should find the right tool in <30 seconds of searching documentation.

### Organization Strategies

#### 1. Upfront Reference Tables

Put a comprehensive tool list at the top of agent documentation:

```markdown
## Quick Reference: Available Tools

| Task | Tool | Invocation |
|------|------|------------|
| Fetch tickets | fetch-tickets.js | `node scripts/fetch-tickets.js --format=json` |
| Create ticket | create-ticket.js | `node scripts/create-ticket.js --title="..." --project=...` |
| Update ticket | update-ticket.js | `node scripts/update-ticket.js TICKET_ID --status=...` |
```

#### 2. Clear Categorization

```
plugin-name/
├── agents/           # Decision-making (1-3 files max)
├── commands/         # User-initiated (5-10 commands)
├── hooks/           # Auto-triggered (3-5 hooks)
├── scripts/         # Low-level utilities (10-20 scripts)
└── skills/          # Agent-invocable automation (5-15 skills)
```

#### 3. Descriptive Naming

**Good:**
- `fetch-tickets-by-status.js` (clear what it does)
- `validate-requirement-format.py` (clear purpose)
- `claim-ticket.sh` (action-oriented)

**Bad:**
- `helper.js` (what does it help with?)
- `util.py` (what utility?)
- `do-stuff.sh` (what stuff?)

#### 4. Consolidated Documentation

Instead of scattering info across files:

```markdown
## Linear Integration Skills

All skills are in scripts/ and invoked via Bash tool.

### Fetching Data
- fetch-tickets.js: Get tickets by status/assignee
- fetch-project.js: Get project details

### Creating/Updating
- create-ticket.js: Create new Linear ticket
- update-ticket.js: Modify existing ticket

### Validation
- validate-ticket-id.js: Check if ticket exists
```

---

## Sibling Agent Architecture

**Pattern:** Flat agent pool where the main Claude agent invokes specialized sub-agents or consults reference documentation.

### Why Flat (Not Hierarchical)?

Sub-agents cannot invoke other sub-agents (they lack the Task tool). Therefore:

**❌ Hierarchical (Doesn't Work):**
```
Main Agent
  └─ PluginExpert (sub-agent)
       └─ DocumentationAgent (can't invoke - no Task tool!)
```

**✅ Sibling/Flat (Works):**
```
Main Agent
  ├─ PluginExpert (sub-agent via Task tool)
  ├─ DocumentationAgent (sub-agent via Task tool)
  └─ PluginReviewer.md (reference docs via Read tool)
```

### Agent vs Reference Documentation

Not everything needs to be a registered sub-agent:

| Type | Access | Use Case | Example |
|------|--------|----------|---------|
| **Registered Agent** | Task tool | Complex decision-making, autonomous work | PluginExpert, DocumentationAgent |
| **Reference Docs** | Read tool | Structured frameworks, checklists, templates | PluginReviewer.md |

**When to use reference docs instead of agents:**
- Content is primarily informational (not decision-making)
- Provides templates/frameworks for main agent to apply
- Simpler than full agent invocation overhead
- Plugin manifest limits (one agent per plugin)

### Agent/Resource Responsibilities

| Resource | Type | Purpose | When Main Uses |
|----------|------|---------|----------------|
| **PluginExpert** | Agent | Plugin creation guidance | User asks "create plugin for X" |
| **PluginReviewer.md** | Docs | Architectural review framework | After plugin changes, before PR |
| **DocumentationAgent** | Agent | Fetch/search docs | Need info from cached docs |

### Invocation Pattern

Main agent uses clear keywords to decide how to access resources:

```markdown
User: "Create a new plugin for X"
→ Main invokes PluginExpert (Task tool)

User: "Review this plugin architecture"
→ Main reads PluginReviewer.md (Read tool)
→ Applies framework to plugin
→ Provides structured findings

User: "How do I configure hooks?"
→ Main invokes DocumentationAgent (Task tool)
```

### Agent Design Guidelines

**CRITICAL: Documentation Accuracy**

The purpose of agents is to **make work faster with less overhead**. Documentation MUST be accurate on first read.

Inaccurate agent documentation causes:
- Wasted invocations (retries due to wrong syntax)
- Increased latency (trial-and-error instead of success)
- Higher costs (multiple API calls for single operation)
- Poor user experience (agent appears broken)

**Documentation requirements:**
- ✅ Verify all skill invocations against actual scripts
- ✅ Test all documented examples
- ✅ Use exact parameter names (--query= not "query")
- ✅ Match reality, don't guess or assume

Each agent should:
1. **Have a single clear purpose** (described in one sentence)
2. **Delegate to skills** (not implement inline)
3. **Report failures clearly** (follow Failure Visibility Principle)
4. **Minimize search space** (quick reference tables)
5. **Be independently invocable** (no dependencies on other sub-agents)
6. **Have accurate, tested documentation** (no trial-and-error needed)

---

## Hooks as Workflow Bumpers

**Pattern:** Hooks provide proactive guidance rather than hard blocks.

### Hook Types

| Hook | When Fired | Purpose |
|------|------------|---------|
| `SessionStart` | Session begins | Set context, announce workflow status |
| `UserPromptSubmit` | Before processing user message | Detect context switches, offer guidance |
| `PreToolUse` | Before tool execution | Validate tool parameters, warn of issues |
| `PostToolUse` | After tool execution | Record state, suggest next steps |

### Bumpers vs Blocks

**Bumper (Recommended):** Guide without preventing
```bash
# UserPromptSubmit hook
if detect_context_switch; then
  echo "⚠️  Detected possible context switch to CUR-999"
  echo "Current ticket: CUR-337"
  echo "Switch with: /workflow:claim CUR-999"
fi
exit 0  # Allow user message to continue
```

**Block (Use Sparingly):** Prevent invalid actions
```bash
# pre-commit hook
if ! has_active_ticket; then
  echo "❌ No active ticket claimed"
  echo "Claim with: ./scripts/claim-ticket.sh CUR-XXX"
  exit 1  # Block the commit
fi
```

### When to Use Each

**Use Bumpers for:**
- Context switch detection
- Suggesting better approaches
- Workflow reminders
- Best practice hints

**Use Blocks for:**
- Compliance requirements (must have ticket before commit)
- Data integrity (must pass validation)
- Security (must not commit secrets)

### Hook Design Principles

1. **Be specific:** "Ticket CUR-337 is active" not "A ticket is active"
2. **Be actionable:** Always suggest the fix: "Run: ./script.sh"
3. **Be fast:** Hooks run on every event, keep them <100ms
4. **Be reliable:** Exit 0 for bumpers, exit 1 for blocks

---

## Environment Variable Enforcement

**Zero Tolerance Policy:** Plugins MUST use environment variables for secrets. No exceptions.

### The Rules

1. **ONLY environment variables for secrets**
   - API keys: `LINEAR_API_TOKEN`, `GITHUB_TOKEN`, etc.
   - Credentials: `DB_PASSWORD`, `SUPABASE_KEY`, etc.
   - Never in: CLI args, .env files, config files

2. **Exit immediately if missing**
   ```bash
   if [ -z "$LINEAR_API_TOKEN" ]; then
     echo "Error: LINEAR_API_TOKEN environment variable not set"
     exit 1
   fi
   ```

3. **Never work around missing variables**
   - Don't prompt user to paste token
   - Don't fall back to .env file
   - Don't suggest workarounds

### Documentation Placeholders

When documenting examples, use standardized placeholders:

**Good:**
```bash
export LINEAR_API_TOKEN="EXAMPLE_API_KEY_VALUE"
export GITHUB_TOKEN="EXAMPLE_SECRET_VALUE"
export NOTIFY_EMAIL="example@fake.email"
```

**Bad:**
```bash
export LINEAR_API_TOKEN="lin_api_1234..."  # Looks like real token
export GITHUB_TOKEN="your_token_here"      # Vague
export NOTIFY_EMAIL="user@example.com"     # Could be real
```

### Standard Placeholders

| Type | Placeholder |
|------|-------------|
| API Key | `EXAMPLE_API_KEY_VALUE` |
| Secret | `EXAMPLE_SECRET_VALUE` |
| Email | `example@fake.email` |
| URL | `https://example.com` |
| ID | `EXAMPLE_ID_12345` |

### Gitleaks Configuration

Exclude ONLY these exact placeholders:

```toml
[allowlist]
  description = "Standardized documentation placeholders only"
  paths = [
    '''EXAMPLE_API_KEY_VALUE''',
    '''EXAMPLE_SECRET_VALUE''',
    '''example@fake\.email''',
  ]
```

---

## Dual Usage Patterns

Plugins should support both direct agent invocation and user-initiated workflows.

### Pattern 1: Direct Agent → Skill

Agent invokes skill directly:
```bash
# Agent uses Bash tool
node ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-tickets.js --format=json --status=active
```

**Use case:** Agent needs ticket data during automated workflow

### Pattern 2: User → Main → Plugin Agent → Skill

User triggers via natural language:
```
User: "Create a ticket for the new auth feature"
→ Main Agent recognizes Linear-related request
→ Main Agent invokes linear-agent (Task tool)
→ linear-agent uses Bash to invoke create-ticket.js skill
→ Result returned to user
```

**Use case:** User wants AI to make decisions (which project? priority? labels?)

### Pattern 3: User → Command → Skill

User invokes slash command:
```
User: /ticket new
→ Command script invokes create-ticket.js with defaults
→ Interactive prompts for required fields
→ Result displayed to user
```

**Use case:** User wants quick, predictable workflow

### Design Implication

Skills must be designed to support all patterns:
- **Scriptable:** Take params, return structured output
- **Non-interactive:** Don't prompt for input (accept params or fail)
- **Composable:** Can be chained together
- **Idempotent:** Safe to retry on failure

---

## Error Handling Templates

### Template 1: Missing Prerequisites

```markdown
❌ Cannot proceed

Missing requirement: LINEAR_API_TOKEN environment variable

This is required for Linear API access. Set it with:
export LINEAR_API_TOKEN="your_token_here"

I will NOT attempt to work around this by:
- Prompting you for the token
- Using a cached/default token
- Implementing an alternative method

Fix the environment and retry.
```

### Template 2: Invalid Invocation

```markdown
❌ Skill invocation failed

I invoked: node scripts/create-ticket.js --title="Fix bug"
Error: Missing required parameter: --project

Either:
1. I invoked incorrectly (need to specify --project)
2. The skill should have a default (skill bug)

Which project should I use? Or should the skill be fixed to default to a project?
```

### Template 3: Unexpected API Error

```markdown
❌ Skill failed with unexpected error

Command: node scripts/fetch-tickets.js --format=json
Error: HTTP 401 Unauthorized

Possible causes:
1. LINEAR_API_TOKEN is invalid/expired
2. Token lacks required permissions
3. Linear API is down

I cannot fetch tickets by implementing an alternative method. This needs to be debugged:
- Check token validity
- Verify token permissions
- Check Linear API status
```

### Template 4: Skill Not Found

```markdown
❌ Skill does not exist

I tried to invoke: node scripts/archive-ticket.js
Error: File not found

Either:
1. This skill doesn't exist yet (needs to be created)
2. I'm using the wrong path/name
3. The plugin is not installed correctly

I will NOT implement ticket archiving inline. If this functionality is needed:
- Create the skill: scripts/archive-ticket.js
- Document it in the agent
- Then I can invoke it
```

---

## Plugin Structure Reference

Standard plugin layout:

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json           # Manifest (agents, commands, skills)
│
├── agents/                    # Sub-agents (1-3 max)
│   ├── MainAgent.md          # Primary agent for plugin
│   └── ReviewerAgent.md      # Optional: specialized agent
│
├── commands/                  # Slash commands (user-initiated)
│   ├── command1.md           # /plugin:command1
│   └── command2.md           # /plugin:command2
│
├── hooks/                     # Event hooks (auto-triggered)
│   └── hooks.json            # Hook definitions (auto-loaded)
│
├── scripts/                   # Low-level executables
│   ├── create.sh
│   ├── validate.py
│   └── fetch.js
│
├── skills/                    # Agent-invocable automation
│   ├── skill1.sh             # Wraps scripts for agent use
│   └── skill2.sh
│
├── cache/                     # Cached resources
│   └── docs/                 # Documentation cache
│
├── tests/                     # Test suite
│   └── test_plugin.sh
│
└── README.md                  # Plugin documentation
```

### File Limits (Minimize Search Space)

| Directory | Recommended Max | Reason |
|-----------|----------------|---------|
| agents/ | 3 files | Too many = unclear responsibilities |
| commands/ | 10 files | Keep focused on core workflows |
| hooks/ | 1 file (hooks.json) | Consolidate for clarity |
| scripts/ | 20 files | Utilities can be numerous |
| skills/ | 15 files | Reusable automation |

If you exceed these limits, consider:
- Splitting into multiple plugins
- Consolidating similar functionality
- Removing unused code

---

## Anti-Patterns to Avoid

### ❌ Anti-Pattern 1: Re-implementing Skills on Failure

**Problem:**
```markdown
Agent: The fetch-tickets skill failed, so I'll fetch tickets manually using curl...
```

**Solution:** Report the error, don't work around it (see Failure Visibility Principle)

### ❌ Anti-Pattern 2: Creating Fake Tools

**Problem:**
```markdown
## Available Tools
- FetchTickets: Fetch Linear tickets
- CreateTicket: Create a new ticket
```

These "tools" don't exist in Claude Code. Agent implements them inline.

**Solution:** Document actual Bash invocations of real skills

### ❌ Anti-Pattern 3: Mixing Plugin Responsibilities

**Problem:** A single plugin that:
- Manages Linear tickets
- Validates requirements
- Enforces git workflow

**Solution:** Three separate plugins with clear boundaries

### ❌ Anti-Pattern 4: Hardcoding Secrets

**Problem:**
```bash
LINEAR_TOKEN="lin_api_abc123..."
```

**Solution:** Environment variables only, fail fast if missing

### ❌ Anti-Pattern 5: Hierarchical Agents

**Problem:**
```markdown
Main calls PluginExpert calls DocumentationAgent
```

Sub-agents can't call sub-agents (no Task tool).

**Solution:** Flat sibling architecture

### ❌ Anti-Pattern 6: Interactive Skills

**Problem:**
```bash
read -p "Enter ticket ID: " ticket_id
```

Skills that prompt for input can't be used by agents.

**Solution:** Accept parameters, fail if missing (non-interactive)

### ❌ Anti-Pattern 7: Unclear Naming

**Problem:**
- `helper.js`
- `util.sh`
- `do-thing.py`

**Solution:** Descriptive action-oriented names:
- `fetch-tickets.js`
- `validate-requirements.sh`
- `create-ticket-from-requirement.py`

---

## Checklist for New Plugins

Before creating a PR for a new plugin:

- [ ] Single clear purpose (one sentence description)
- [ ] All secrets via environment variables
- [ ] Skills are non-interactive (accept params, fail if missing)
- [ ] Agents delegate to skills (no inline implementation)
- [ ] Error handling follows Failure Visibility Principle
- [ ] Quick reference table at top of agent docs
- [ ] File counts within recommended limits
- [ ] No hierarchical agent invocations
- [ ] Hooks are fast (<100ms) and reliable
- [ ] README.md documents all capabilities
- [ ] Tests cover core functionality
- [ ] No hardcoded secrets or realistic-looking examples
- [ ] Follows standard plugin structure

---

## Review Checklist

Use this when reviewing existing plugins (see PluginReviewer agent):

### 1. Separation of Concerns
- [ ] Plugin has single clear responsibility
- [ ] No overlap with other plugins
- [ ] Cross-plugin features use orchestrator pattern

### 2. Tool Type Appropriateness
- [ ] Complex decisions = agents
- [ ] User workflows = commands
- [ ] Auto-triggers = hooks
- [ ] Reusable automation = skills
- [ ] Low-level utilities = scripts

### 3. Thin Delegator Compliance
- [ ] Agents invoke skills, don't implement inline
- [ ] No fake "Tools" in agent documentation
- [ ] Skills fail fast with clear errors
- [ ] No workarounds for skill failures

### 4. Search Space Minimization
- [ ] Quick reference table at top
- [ ] Clear categorization (agents/, scripts/, etc.)
- [ ] Descriptive naming
- [ ] File counts within limits

### 5. Hook Usage
- [ ] Hooks are bumpers (guidance) not blocks
- [ ] Fast execution (<100ms)
- [ ] Specific, actionable messages

### 6. Security
- [ ] All secrets via environment variables
- [ ] Exit immediately if env vars missing
- [ ] No .env file fallbacks
- [ ] Standard placeholder values in docs

### 7. Consistency
- [ ] Follows standard plugin structure
- [ ] Naming conventions match codebase
- [ ] Error messages use standard templates
- [ ] Documentation format consistent

---

## Conclusion

These patterns ensure:
- **Maintainability:** Skills are the source of truth, agents just invoke them
- **Debuggability:** Failures are visible and actionable
- **Efficiency:** Agents find tools in <30 seconds
- **Reliability:** No hidden workarounds, bugs get fixed
- **Security:** Zero tolerance for hardcoded secrets
- **Scalability:** Clear boundaries enable parallel plugin development

When in doubt, ask: "Am I minimizing search space and maximizing failure visibility?"
