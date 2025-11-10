# Agent Format Standard

**Purpose:** Define the standard structure and format for Claude Code agent files to ensure consistency, clarity, and effectiveness.

**Validation:** The plugin-expert's `validator.js` enforces these standards automatically.

---

## Overview

Agent files are markdown documents that instruct specialized sub-agents how to behave. Good agent design requires:

1. **Clear structure** - Required sections that define identity and capabilities
2. **Balanced emphasis** - Critical points highlighted, but not everything
3. **Actionable content** - Concrete examples and invocation patterns
4. **Thin delegation** - Agents invoke tools/skills, they don't implement logic

---

## Required Format

### 1. YAML Frontmatter (REQUIRED)

Every agent file MUST start with YAML frontmatter:

```markdown
---
name: AgentName
description: Brief description of what this agent does (1-2 sentences)
---
```

**Required fields:**
- `name`: The agent's name (PascalCase, matches filename)
- `description`: Clear, concise description of agent's purpose

**Example:**
```markdown
---
name: RequirementsAgent
description: Specialized agent for requirement operations, change detection, and tracking management
---
```

---

### 2. Required Sections

Every agent MUST include these sections (flexible naming, but content is required):

#### A. Identity Section

**Purpose:** Define WHO the agent is and WHAT it does

**Acceptable section names:**
- `# Role`
- `## Purpose`
- `# Identity`
- `## Overview`

**What to include:**
- Clear statement of agent's primary purpose
- Scope boundaries (what it does and doesn't do)
- When to invoke this agent

**Example:**
```markdown
# Role

You are the Requirements Agent, a specialized sub-agent for working with formal requirements in the spec/ directory. You have expertise in requirement traceability, change detection, and implementation tracking.
```

---

#### B. Operational Approach Section

**Purpose:** Define HOW the agent operates

**Acceptable section names:**
- `## Capabilities`
- `## Core Capabilities`
- `## Workflow`
- `## Operational Approach`
- `## What You Can Do`

**What to include:**
- List of capabilities (what the agent can do)
- Workflow or decision-making process
- Constraints or limitations

**Example:**
```markdown
## Core Capabilities

You can:
- **Fetch requirements** by ID using get-requirement.py
- **Detect changes** using detect-changes.py
- **Manage tracking** using update-tracking.py
- **Interpret requirement content** and metadata
- **Guide implementation** based on requirement specifications
- **Verify traceability** between requirements and code
```

---

#### C. Available Tools Section

**Purpose:** Document EXACTLY how to invoke skills/scripts

**Acceptable section names:**
- `## Available Tools`
- `## Available Skills`
- `## Tools and Skills`
- `## How to Invoke`

**What to include:**
- Specific invocation commands (using Bash tool)
- Use `${CLAUDE_PLUGIN_ROOT}` for path references
- Parameters and arguments
- When to use each tool
- Code examples in triple-backtick blocks

**Example:**
```markdown
## Available Tools

### 1. Get Requirement
**Script**: `scripts/get-requirement.py`

**Purpose**: Fetch and display a requirement by ID

**Usage**:
```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/get-requirement.py REQ-d00027
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/get-requirement.py d00027 --format json
```

**When to use**:
- User asks "What is REQ-d00027?"
- Need full requirement text and metadata
- Checking requirement details during implementation
```

**CRITICAL:** This section MUST show concrete invocation examples. Agents need to know EXACTLY what Bash command to run.

---

### 3. Recommended Sections

These sections are optional but highly recommended:

#### D. When to Use / Auto-Invocation Triggers

**Purpose:** Define when the main agent should invoke this sub-agent

**Example:**
```markdown
## When to Use This Agent

The main agent should invoke you when:
- User asks about a specific requirement (e.g., "What does REQ-d00027 say?")
- User wants to check for changed requirements
- User needs to update implementation based on requirement changes
- Any requirement-related questions or operations
```

---

#### E. Examples

**Purpose:** Show concrete usage scenarios

**Example:**
```markdown
## Examples

### Example 1: Fetching a Requirement

**User**: "What does REQ-d00027 say?"

**You invoke**:
```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/get-requirement.py REQ-d00027
```

**Then**: Parse the output and explain the requirement to the user in plain language.
```

---

## Emphasis Guidelines

### What to Emphasize

Use emphasis markers (`CRITICAL`, `IMPORTANT`, `MUST`, `NEVER`, `ALWAYS`, `MANDATORY`) for:

1. **Architectural principles** that must not be violated
2. **Security requirements** that prevent vulnerabilities
3. **User-blocking actions** that require waiting for user input
4. **Failure modes** that would cause incorrect behavior
5. **Integration requirements** with other systems

### Emphasis Balance

The validator enforces these rules:

- **0 markers**: Warning (suggest adding emphasis for critical points)
- **1-15 markers**: ✅ Good balance
- **16-20 markers**: Suggestion (consider if all are truly critical)
- **21+ markers**: ⚠️  Warning (too many - when everything is emphasized, nothing is)
- **>5% word ratio**: ⚠️  Warning (emphasis overuse)

### Examples

✅ **Good Emphasis:**
```markdown
## Available Tools

**CRITICAL**: Always use the Bash tool to invoke skills. NEVER re-implement skill logic inline.

Use get-requirement.py when:
- User asks about specific requirement
- Need to validate REQ reference
```

**Analysis**: 2 emphasis markers in context. Clear why it's critical.

---

❌ **Bad Emphasis:**
```markdown
## IMPORTANT Tools - CRITICAL Section

**MANDATORY**: ALWAYS use these tools. NEVER skip this. CRITICAL for all operations.

**IMPORTANT**: get-requirement.py is REQUIRED and MANDATORY.
```

**Analysis**: 8 emphasis markers in 3 lines. No new information. Everything sounds urgent, so nothing stands out.

---

### Orphaned Emphasis

**NEVER** use emphasis markers without explanation:

❌ **Bad:**
```markdown
**CRITICAL**

Use the right tool.
```

✅ **Good:**
```markdown
**CRITICAL**: Always invoke skills via Bash tool - never re-implement logic inline. This prevents duplication and ensures consistency.
```

---

## Heading Structure

### Hierarchy Rules

1. **First heading**: Must be level 1 (`# Title`)
2. **Logical nesting**: Don't skip levels (# → ## → ###, not # → ###)
3. **Section markers**: Use ## for major sections, ### for subsections

### Example Hierarchy

```markdown
# AgentName Agent                    ← Level 1: Agent title

## Core Capabilities                 ← Level 2: Major section

### Capability 1                     ← Level 3: Subsection
### Capability 2                     ← Level 3: Subsection

## Available Tools                   ← Level 2: Major section

### Tool 1: fetch-tickets            ← Level 3: Individual tool
### Tool 2: create-ticket            ← Level 3: Individual tool
```

---

## Thin Delegator Pattern

Agents should **delegate to skills**, not implement logic themselves.

### ✅ Good Agent Design

```markdown
## Available Tools

### Fetch Tickets
```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/fetch-tickets.js --format=json
```

Use this when the user wants to see their assigned tickets.
```

**Then in the agent's instructions:**
```markdown
When user asks "What are my tickets?":
1. Invoke fetch-tickets.js using Bash tool
2. Parse the JSON output
3. Present results to user in friendly format
```

**Analysis**: Agent invokes 1 skill. Total operations: ~3

---

### ❌ Bad Agent Design

```markdown
## Available Tools

You have access to:
- LinearFetchTickets: Fetch tickets from Linear
- LinearCreateTicket: Create a new ticket

When fetching tickets:
1. Get LINEAR_API_TOKEN from environment
2. Construct GraphQL query
3. Make POST request to Linear API
4. Parse response
5. Filter by assignee
6. Sort by priority
... (25 more steps)
```

**Analysis**: No real tools. Agent re-implements everything. Total operations: 30+

**Problem**: This isn't a "tool" - it's inline re-implementation. Creates massive duplication and maintenance burden.

---

## Validation

The plugin-expert validator checks:

### Errors (Must Fix)
- ❌ Missing YAML frontmatter
- ❌ Missing `name:` field
- ❌ Missing `description:` field
- ❌ No section headers

### Warnings (Should Fix)
- ⚠️  Missing Identity section
- ⚠️  Missing Operational section
- ⚠️  Missing Tools section
- ⚠️  Too many emphasis markers (21+)
- ⚠️  Emphasis overuse (>5% of words)
- ⚠️  Available Tools section has no invocation examples
- ⚠️  Agent body too short (<200 chars)
- ⚠️  First heading not level 1
- ⚠️  Orphaned emphasis markers

### Suggestions (Nice to Have)
- 💡 No emphasis markers (consider adding for critical points)
- 💡 High emphasis count (16-20, review if all are critical)
- 💡 Missing Examples section
- 💡 Missing auto-invocation triggers

---

## Complete Template

```markdown
---
name: YourAgentName
description: Brief description of what this agent does
---

# YourAgentName Agent

You are the YourAgentName agent, specialized in [specific domain]. You provide [key capabilities].

## Core Capabilities

You can:
- **Capability 1**: Description
- **Capability 2**: Description
- **Capability 3**: Description

## When to Use This Agent

The main agent should invoke you when:
- Scenario 1
- Scenario 2
- Scenario 3

## Available Tools

### 1. Tool Name
**Script**: `scripts/tool-name.sh`

**Purpose**: What this tool does

**Usage**:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/tool-name.sh [args]
```

**When to use**:
- Specific scenario requiring this tool
- Another scenario

**Parameters**:
- `arg1`: Description
- `arg2`: Description

### 2. Another Tool
[Same structure...]

## Workflow

When activated, follow these steps:

1. **Analyze the request**: Understand what the user wants
2. **Select the right tool**: Based on the request type
3. **Invoke via Bash**: Use the Bash tool to call the script
4. **Parse results**: Interpret the output
5. **Report to user**: Explain findings in clear language

## Examples

### Example 1: Common Scenario

**User**: "Example user request"

**Action**:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/tool-name.sh --param value
```

**Output**: Expected result

**Then**: Explain the result to the user

## Important Notes

**CRITICAL**: Key architectural principle that must not be violated.

- Regular note
- Another note
- Third note
```

---

## Metrics

The validator provides these metrics:

```javascript
{
  emphasisCount: 12,              // Total CRITICAL/IMPORTANT/etc markers
  sectionCount: 8,                // Number of sections
  hasIdentity: true,              // Has role/purpose section
  hasOperationalApproach: true,   // Has capabilities/workflow section
  hasAvailableTools: true,        // Has tools/skills section
  hasExamples: true               // Has examples section
}
```

Use these to assess agent quality and completeness.

---

## References

- **Plugin Architecture**: `tools/anspar-marketplace/docs/PLUGIN_ARCHITECTURE.md`
- **Plugin Reviewer**: `tools/anspar-marketplace/plugins/plugin-expert/reference/PluginReviewer.md`
- **Validator Implementation**: `tools/anspar-marketplace/plugins/plugin-expert/scripts/orchestrators/validator.js`

---

## Summary Checklist

Before finalizing an agent file:

- [ ] YAML frontmatter with name and description
- [ ] Identity section (role/purpose)
- [ ] Operational section (capabilities/workflow)
- [ ] Available Tools section with concrete invocation examples
- [ ] Auto-invocation triggers or "When to Use" section
- [ ] Examples demonstrating usage
- [ ] 5-15 emphasis markers for truly critical points
- [ ] Each emphasis marker has context/explanation
- [ ] First heading is level 1
- [ ] Proper heading hierarchy (no skipped levels)
- [ ] Invocations use `${CLAUDE_PLUGIN_ROOT}` variable
- [ ] Tools are delegated to, not re-implemented
- [ ] At least 200 characters of content

Run validation:
```bash
node tools/anspar-marketplace/plugins/plugin-expert/scripts/orchestrators/validator.js /path/to/agent.md
```
