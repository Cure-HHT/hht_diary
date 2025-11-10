# PluginReviewer Reference

**Purpose:** Comprehensive architectural review guide for Claude Code plugins using established patterns and best practices.

**How to Use:** This is reference documentation, not a registered sub-agent. Main agent should read this document when conducting plugin reviews.

**When to Use:** After plugin changes, before creating PR, or when user requests plugin review.

---

## Overview

This document provides a structured framework for evaluating plugins against the architectural patterns defined in `tools/anspar-marketplace/docs/PLUGIN_ARCHITECTURE.md`.

**When conducting a review, you should:**
1. Review plugin structure and organization
2. Identify violations of architectural patterns
3. Flag anti-patterns (especially inline skill re-implementation)
4. Suggest specific improvements
5. Validate compliance with security requirements

**Important:** Provide clear findings and recommendations, but don't make changes during the review.

---

## Review Process

### Step 1: Understand Context

Before reviewing, gather:
- **Plugin name and purpose** (what does it do?)
- **Changed files** (what was modified?)
- **Review scope** (full plugin or specific changes?)

### Step 2: Read Architecture Reference

Always review against: `tools/anspar-marketplace/docs/PLUGIN_ARCHITECTURE.md`

This defines:
- Tool type decision matrix
- Thin delegator pattern
- Failure visibility principle
- Search space minimization
- Environment variable enforcement
- All architectural patterns

### Step 3: Conduct Seven-Dimension Review

Evaluate the plugin across all seven dimensions (see below).

### Step 4: Provide Structured Report

Format findings as:
```markdown
## Plugin Review: [plugin-name]

### Summary
[1-2 sentence overall assessment]

### Findings by Dimension

#### 1. Separation of Concerns: [✅ Pass | ⚠️  Warning | ❌ Fail]
[Specific findings...]

#### 2. Tool Type Appropriateness: [✅ Pass | ⚠️  Warning | ❌ Fail]
[Specific findings...]

[... continue for all 7 dimensions ...]

### Critical Issues (Must Fix Before Merge)
- [ ] Issue 1
- [ ] Issue 2

### Recommendations (Should Address)
- Recommendation 1
- Recommendation 2

### Questions for Developer
1. Question 1?
2. Question 2?
```

---

## Seven Review Dimensions

### 1. Separation of Concerns

**What to Check:**
- Does the plugin have a single, clear responsibility?
- Is there overlap with other plugins?
- Are cross-plugin features using orchestrator pattern?

**Red Flags:**
- Plugin handles multiple unrelated domains (e.g., tickets AND database migrations)
- Duplicate functionality across plugins
- Direct coupling between plugins (one plugin imports another's code)

**Examples:**

✅ **Good:**
```
linear-integration/
  Purpose: Linear ticket management only
  Scope: Fetch, create, update tickets

workflow/
  Purpose: Git workflow enforcement only
  Scope: Ticket claiming, state tracking, commit validation
```

❌ **Bad:**
```
mega-plugin/
  Purpose: Handles tickets, requirements, git workflow, AND deployments
  Scope: Everything under the sun
```

**Assessment Template:**
```markdown
#### 1. Separation of Concerns: [✅ Pass | ⚠️  Warning | ❌ Fail]

Purpose: [plugin's stated purpose]
Actual scope: [what it actually does]

Findings:
- [Finding 1]
- [Finding 2]

Recommendation: [if not pass, what to fix]
```

---

### 2. Tool Type Appropriateness

**What to Check:**
- Are complex decisions handled by agents?
- Are user workflows implemented as commands?
- Are automatic triggers implemented as hooks?
- Is reusable automation implemented as skills?
- Are low-level utilities implemented as scripts?

**Decision Matrix Reference:**
| Tool Type | When to Use | Example |
|-----------|-------------|---------|
| Agent | Complex decision-making | linear-agent decides priority/labels |
| Command | User-initiated workflow | `/ticket new` |
| Hook | Auto-trigger on event | UserPromptSubmit detects context switch |
| Skill | Reusable automation | create-ticket.sh |
| Script | Low-level utility | validate.py |

**Red Flags:**
- Simple validation implemented as agent (overkill)
- Reusable automation only in command (not accessible to agents)
- Complex decision-making in script (should be agent)

**Examples:**

✅ **Good:**
```
Ticket creation:
- Agent: linear-agent (decides which project, priority, labels)
- Skill: create-ticket.js (handles API call)
- Command: /ticket new (user-friendly wrapper)
```

❌ **Bad:**
```
Requirement validation:
- Agent: requirement-agent (overkill for simple validation)
Should be: Script + Hook
```

**Assessment Template:**
```markdown
#### 2. Tool Type Appropriateness: [✅ Pass | ⚠️  Warning | ❌ Fail]

Tool breakdown:
- Agents: [count] - [appropriate? Y/N]
- Commands: [count] - [appropriate? Y/N]
- Hooks: [count] - [appropriate? Y/N]
- Skills: [count] - [appropriate? Y/N]
- Scripts: [count] - [appropriate? Y/N]

Findings:
- [Finding 1]
- [Finding 2]

Recommendation: [if not pass, what to change]
```

---

### 3. Thin Delegator Compliance

**What to Check:**
- Do agents invoke skills instead of implementing inline?
- Are there fake "Tools" documented that don't exist in Claude Code?
- When skills fail, do agents report errors or work around them?
- Is skill invocation efficient (1 call vs 30+ operations)?

**This is Critical:** Most common anti-pattern is agents doing too much work instead of delegating to skills.

**Red Flags:**
- Agent documentation lists "Available Tools" that aren't real Claude Code tools
- Agent has 20+ step workflows for things that should be 1 skill call
- Agent catches skill errors and implements alternative approaches
- Agent "helps" by working around missing environment variables

**Examples:**

❌ **Bad (linear-agent currently):**
```markdown
## Available Tools

You have access to:
- LinearFetchTickets: Fetch tickets from Linear
- LinearCreateTicket: Create a new ticket
```

These tools don't exist. Agent implements entire Linear API interaction inline (30+ operations).

✅ **Good (linear-agent should be):**
```markdown
## Available Skills

Use the Bash tool to invoke:

### Fetch Tickets
node ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-tickets.js --format=json [--status=active]

### Create Ticket
node ${CLAUDE_PLUGIN_ROOT}/scripts/create-ticket.js --title="..." --description="..." --project=...
```

Agent invokes skill with 1 Bash call.

**Error Handling Check:**

❌ **Bad (working around failure):**
```
Agent: The fetch-tickets skill failed, so I'll fetch tickets manually using curl...
*Proceeds to implement entire API interaction*
```

✅ **Good (reporting failure):**
```
Agent: ❌ Skill 'fetch-tickets' failed with: LINEAR_API_TOKEN not set

I cannot proceed without this environment variable. Either:
1. Set LINEAR_API_TOKEN in your environment
2. Fix the skill if it should handle missing tokens differently

I will NOT fetch tickets manually.
```

**Assessment Template:**
```markdown
#### 3. Thin Delegator Compliance: [✅ Pass | ⚠️  Warning | ❌ Fail]

Agent delegation:
- Uses real skills: [Y/N]
- Fake "Tools" documented: [Y/N]
- Inline implementation found: [Y/N]
- Error handling appropriate: [Y/N]

Findings:
- [Finding 1: e.g., "Agent implements ticket creation inline instead of using create-ticket.js"]
- [Finding 2: e.g., "Agent works around skill failures instead of reporting them"]

Examples of violations:
[Code snippets or references]

Recommendation: [what needs to change]
```

---

### 4. Search Space Minimization

**What to Check:**
- Can an agent find the right tool in <30 seconds?
- Is there a quick reference table at the top of agent docs?
- Are files organized by category (agents/, scripts/, skills/, etc.)?
- Are file names descriptive and action-oriented?
- Are file counts within recommended limits?

**Recommended Limits:**
| Directory | Max Files | Current | Status |
|-----------|-----------|---------|--------|
| agents/ | 3 | [count] | [OK/Over] |
| commands/ | 10 | [count] | [OK/Over] |
| hooks/ | 1 (hooks.json) | [count] | [OK/Over] |
| scripts/ | 20 | [count] | [OK/Over] |
| skills/ | 15 | [count] | [OK/Over] |

**Red Flags:**
- No quick reference table in agent documentation
- Files scattered without clear organization
- Vague names (`helper.js`, `util.sh`, `do-thing.py`)
- Excessive file counts (>20 scripts, >15 skills)

**Examples:**

✅ **Good:**
```markdown
## Quick Reference: Available Tools

| Task | Tool | Invocation |
|------|------|------------|
| Fetch tickets | fetch-tickets.js | `node scripts/fetch-tickets.js --format=json` |
| Create ticket | create-ticket.js | `node scripts/create-ticket.js --title="..." --project=...` |
| Update ticket | update-ticket.js | `node scripts/update-ticket.js TICKET_ID --status=...` |
| Validate ticket | validate-ticket-id.js | `node scripts/validate-ticket-id.js TICKET_ID` |
```

Agent can scan table and find the right tool immediately.

❌ **Bad:**
```markdown
## Scripts

We have various scripts in the scripts/ folder. Check there for utilities.
```

Agent has to search through potentially dozens of files.

**Assessment Template:**
```markdown
#### 4. Search Space Minimization: [✅ Pass | ⚠️  Warning | ❌ Fail]

Quick reference table: [Present/Missing]
File organization: [Clear/Unclear]
File naming: [Descriptive/Vague]

File counts:
- agents/: [count]/3 max
- commands/: [count]/10 max
- hooks/: [count]/1 max
- scripts/: [count]/20 max
- skills/: [count]/15 max

Findings:
- [Finding 1]
- [Finding 2]

Recommendation: [if not pass, what to improve]
```

---

### 5. Hook Usage Patterns

**What to Check:**
- Are hooks used as "bumpers" (guidance) not blocks?
- Are hooks fast (<100ms execution time)?
- Do hooks provide specific, actionable messages?
- Are hooks reliable (exit 0 for bumpers, exit 1 for blocks)?

**Hook Types:**
| Hook | When | Purpose |
|------|------|---------|
| SessionStart | Session begins | Set context, announce status |
| UserPromptSubmit | Before user message | Detect context switch, offer guidance |
| PreToolUse | Before tool execution | Validate params, warn |
| PostToolUse | After tool execution | Record state, suggest next |

**Bumpers vs Blocks:**

**Bumper (Recommended):**
```bash
# UserPromptSubmit - detect context switch
if detect_context_switch; then
  echo "⚠️  Detected possible context switch to CUR-999"
  echo "Current ticket: CUR-337"
  echo "Switch with: /workflow:claim CUR-999"
fi
exit 0  # Allow user message to continue
```

**Block (Use Sparingly):**
```bash
# pre-commit - enforce ticket claiming
if ! has_active_ticket; then
  echo "❌ No active ticket claimed"
  echo "Claim with: ./scripts/claim-ticket.sh CUR-XXX"
  exit 1  # Block the commit
fi
```

**Red Flags:**
- Hooks that block unnecessarily (should guide instead)
- Slow hooks (>100ms, causes lag)
- Vague messages ("Something is wrong" vs "Ticket CUR-337 is active")
- No actionable fix suggested

**Assessment Template:**
```markdown
#### 5. Hook Usage Patterns: [✅ Pass | ⚠️  Warning | ❌ Fail]

Hooks present:
- [hook name]: [bumper/block] - [appropriate? Y/N]
- [hook name]: [bumper/block] - [appropriate? Y/N]

Findings:
- [Finding 1: e.g., "Hook blocks when it should guide"]
- [Finding 2: e.g., "Hook message not actionable"]

Recommendation: [if not pass, what to change]
```

---

### 6. Consistency with Codebase

**What to Check:**
- Does the plugin follow the standard structure?
- Do naming conventions match other plugins?
- Do error messages use standard templates?
- Is documentation format consistent?

**Standard Plugin Structure:**
```
plugin-name/
├── .claude-plugin/
│   └── plugin.json
├── agents/
├── commands/
├── hooks/
│   └── hooks.json
├── scripts/
├── skills/
├── cache/
├── tests/
└── README.md
```

**Naming Conventions:**
- Files: kebab-case (`fetch-tickets.js`)
- Commands: `/plugin-name:command-name`
- Agents: PascalCase in docs (`LinearAgent.md`)
- Environment vars: SCREAMING_SNAKE_CASE (`LINEAR_API_TOKEN`)

**Error Message Template:**
```
❌ [What failed]

Error: [Specific error message]

[Explanation of what went wrong]

Either:
1. [Possible cause 1]
2. [Possible cause 2]

[Actionable fix]
```

**Red Flags:**
- Non-standard directory structure
- Inconsistent naming (mix of camelCase, snake_case, etc.)
- Error messages that don't follow template
- README format different from other plugins

**Assessment Template:**
```markdown
#### 6. Consistency with Codebase: [✅ Pass | ⚠️  Warning | ❌ Fail]

Structure compliance: [Y/N]
Naming conventions: [Consistent/Inconsistent]
Error message format: [Standard/Non-standard]
Documentation format: [Consistent/Inconsistent]

Findings:
- [Finding 1]
- [Finding 2]

Recommendation: [if not pass, what to align]
```

---

### 7. Security & Secrets Management

**What to Check:**
- All secrets via environment variables (not CLI args, not .env files)
- Exit immediately if required env vars missing
- No workarounds for missing env vars
- Standard placeholder values in documentation
- No realistic-looking secrets in examples

**The Rules:**
1. **ONLY environment variables for secrets**
2. **Exit immediately if missing** (don't prompt, don't fall back)
3. **Never work around missing variables**

**Standard Placeholders:**
| Type | Placeholder |
|------|-------------|
| API Key | `EXAMPLE_API_KEY_VALUE` |
| Secret | `EXAMPLE_SECRET_VALUE` |
| Email | `example@fake.email` |
| URL | `https://example.com` |
| ID | `EXAMPLE_ID_12345` |

**Red Flags:**

❌ **Hardcoded secrets:**
```bash
LINEAR_TOKEN="lin_api_abc123..."
```

❌ **Accepting secrets via CLI:**
```bash
./script.sh --token="$1"
```

❌ **Falling back to .env:**
```bash
if [ -z "$LINEAR_API_TOKEN" ]; then
  source .env
fi
```

❌ **Prompting for secrets:**
```bash
read -p "Enter API token: " token
```

❌ **Realistic-looking examples:**
```bash
export LINEAR_API_TOKEN="lin_api_1234..."  # Looks real
```

✅ **Correct:**
```bash
if [ -z "$LINEAR_API_TOKEN" ]; then
  echo "Error: LINEAR_API_TOKEN environment variable not set"
  echo "Set it with: export LINEAR_API_TOKEN=\"EXAMPLE_API_KEY_VALUE\""
  exit 1
fi
```

**Gitleaks Check:**

Verify `.gitleaks.toml` only allows standard placeholders:
```toml
[allowlist]
  paths = [
    '''EXAMPLE_API_KEY_VALUE''',
    '''EXAMPLE_SECRET_VALUE''',
    '''example@fake\.email''',
  ]
```

**Assessment Template:**
```markdown
#### 7. Security & Secrets Management: [✅ Pass | ⚠️  Warning | ❌ Fail]

Environment variable usage: [Correct/Incorrect]
Missing env var handling: [Exit immediately/Works around]
Placeholder values: [Standard/Non-standard]
Realistic secrets in docs: [None found/Found]

Findings:
- [Finding 1: e.g., "Script accepts token via CLI arg"]
- [Finding 2: e.g., "Documentation uses realistic-looking token"]

Recommendation: [if not pass, what to fix]
```

---

## Common Anti-Patterns to Flag

### Anti-Pattern 1: Re-implementing Skills on Failure

**What to Look For:**
```markdown
Agent: The fetch-tickets skill failed, so I'll use curl instead...
```

**Why It's Bad:** Hides bugs, creates maintenance burden

**Flag as:** ❌ Critical - Thin Delegator Compliance violation

### Anti-Pattern 2: Fake Tools

**What to Look For:**
```markdown
## Available Tools
- FetchTickets: Fetches tickets
- CreateTicket: Creates a ticket
```

**Why It's Bad:** Agent implements inline, 30+ operations

**Flag as:** ❌ Critical - Thin Delegator Compliance violation

### Anti-Pattern 3: Mixing Responsibilities

**What to Look For:**
Single plugin handling tickets, requirements, git workflow, deployments

**Why It's Bad:** Unclear boundaries, hard to maintain

**Flag as:** ❌ Critical - Separation of Concerns violation

### Anti-Pattern 4: Hardcoded Secrets

**What to Look For:**
```bash
API_KEY="abc123..."
```

**Why It's Bad:** Security risk, secret scanning violations

**Flag as:** ❌ Critical - Security violation

### Anti-Pattern 5: Interactive Skills

**What to Look For:**
```bash
read -p "Enter ticket ID: " ticket_id
```

**Why It's Bad:** Can't be used by agents (blocks waiting for input)

**Flag as:** ⚠️  Warning - Design flaw

### Anti-Pattern 6: Vague Naming

**What to Look For:**
- `helper.js`
- `util.sh`
- `do-thing.py`

**Why It's Bad:** Increases search space, unclear purpose

**Flag as:** ⚠️  Warning - Search Space issue

### Anti-Pattern 7: No Quick Reference

**What to Look For:**
Agent documentation with no upfront tool table

**Why It's Bad:** Agent spends minutes searching for tools

**Flag as:** ⚠️  Warning - Search Space issue

---

## Review Output Format

Always provide a structured report:

```markdown
## Plugin Review: [plugin-name]

**Reviewed by:** PluginReviewer Agent
**Date:** [date]
**Scope:** [full plugin | specific changes]

### Summary

[1-2 sentence overall assessment. Examples:
- "Plugin follows architectural patterns well with minor improvements needed."
- "Critical violations found in thin delegator compliance - agent re-implements skills."
- "Good separation of concerns, but security issues with hardcoded tokens."]

---

### Findings by Dimension

#### 1. Separation of Concerns: [✅ Pass | ⚠️  Warning | ❌ Fail]

Purpose: [stated purpose]
Actual scope: [what it does]

[Findings...]

Recommendation: [what to fix if not pass]

---

#### 2. Tool Type Appropriateness: [✅ Pass | ⚠️  Warning | ❌ Fail]

[Findings...]

Recommendation: [what to change if not pass]

---

#### 3. Thin Delegator Compliance: [✅ Pass | ⚠️  Warning | ❌ Fail]

[Findings...]

Recommendation: [what to change if not pass]

---

#### 4. Search Space Minimization: [✅ Pass | ⚠️  Warning | ❌ Fail]

[Findings...]

Recommendation: [what to improve if not pass]

---

#### 5. Hook Usage Patterns: [✅ Pass | ⚠️  Warning | ❌ Fail]

[Findings...]

Recommendation: [what to change if not pass]

---

#### 6. Consistency with Codebase: [✅ Pass | ⚠️  Warning | ❌ Fail]

[Findings...]

Recommendation: [what to align if not pass]

---

#### 7. Security & Secrets Management: [✅ Pass | ⚠️  Warning | ❌ Fail]

[Findings...]

Recommendation: [what to fix if not pass]

---

### Critical Issues (Must Fix Before Merge)

- [ ] Issue 1 with reference to file:line
- [ ] Issue 2 with reference to file:line

### Recommendations (Should Address)

- Recommendation 1
- Recommendation 2

### Questions for Developer

1. Question 1?
2. Question 2?

---

### Overall Assessment

[Pass | Pass with Recommendations | Needs Work | Blocked]

[Final paragraph summarizing review and next steps]
```

---

## Usage Guidelines

### When to Invoke This Agent

Invoke PluginReviewer when:
- Creating PR for new plugin
- Modifying existing plugin significantly
- User requests plugin review
- Suspicious patterns detected (main agent can proactively invoke)

### What This Agent Does

- Reads plugin files
- Evaluates against PLUGIN_ARCHITECTURE.md patterns
- Provides structured findings
- Suggests specific improvements

### What This Agent Does NOT Do

- Make changes to files (review only)
- Implement recommendations (developer's job)
- Create new plugins (use PluginExpert for that)
- Write code (only review existing code)

### Collaboration with Other Agents

**PluginExpert:** Creates plugins, PluginReviewer reviews them
**DocumentationAgent:** Fetches docs, PluginReviewer uses them as reference
**Main Agent:** Coordinates, invokes PluginReviewer when needed

---

## Example Invocation

**User message:**
"Review the linear-integration plugin architecture"

**Main agent invokes:**
```
Task: Review linear-integration plugin
Agent: PluginReviewer
Prompt: "Review the linear-integration plugin for architectural compliance.
Focus on thin delegator pattern - this plugin was previously implementing
ticket operations inline instead of using skills."
```

**PluginReviewer output:**
[Structured review following the format above]

**Main agent to user:**
"I've completed the architectural review. Here are the findings..."
[Summarizes key points from review]

---

## Final Checklist

Before submitting your review:

- [ ] Reviewed against PLUGIN_ARCHITECTURE.md patterns
- [ ] Evaluated all 7 dimensions
- [ ] Provided specific findings with file references
- [ ] Flagged critical issues that block merge
- [ ] Suggested actionable improvements
- [ ] Used structured output format
- [ ] Included overall assessment
- [ ] Answered: "Can this plugin merge as-is?"

---

## Remember

Your job is to **ensure architectural quality**. Be thorough, specific, and constructive. The goal is maintainable, secure, efficient plugins that follow established patterns.

When in doubt, refer to `tools/anspar-marketplace/docs/PLUGIN_ARCHITECTURE.md`.
