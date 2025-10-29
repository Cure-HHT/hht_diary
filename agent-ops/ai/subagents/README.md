# Specialized Sub-Agents

**Purpose**: Domain-specific expertise agents that the orchestrator can delegate to for complex tasks.

---

## What Are Sub-Agents?

Sub-agents are **specialized AI assistants** with deep knowledge of specific domains. They:

✅ **Analyze and generate** - Read files, analyze patterns, generate formatted output
✅ **Provide expertise** - Deep knowledge of specific systems (requirements, database, testing, etc.)
✅ **Return actionable results** - Formatted text ready to insert, clear recommendations
✅ **Stay read-only** - Never directly modify files (orchestrator does file operations)

**Think of them as expert consultants**: You ask for advice, they analyze and recommend, you implement.

---

## Available Sub-Agents

### Requirements Sub-Agent

**File**: `REQUIREMENTS.md`

**Expertise**:
- Formal requirement system (PRD → Ops → Dev cascade)
- Requirement format and traceability
- Linear ticket integration
- Code header generation
- Validation and analysis

**Use when**:
- Finding requirements for a topic
- Creating new requirements for a feature
- Generating code header comments
- Analyzing requirement-code-ticket associations
- Validating requirement completeness

**Example**: "Find all requirements related to authentication"

---

### Documentation Sub-Agent

**File**: `DOCUMENTATION.md`

**Expertise**:
- Proper documentation scoping (spec/ vs docs/, prd/ops/dev)
- Repetition elimination across files
- Concise rewriting (removing extraneous details)
- Example minimization (keep only essential)
- Template reference enforcement (no inline templates)

**Use when**:
- Documentation is verbose or out of scope
- Repetition across multiple files
- Converting text to properly scoped document
- Too many unnecessary examples
- Inline templates should be references

**Example**: "Rewrite this file to be more concise and properly scoped"

---

## How to Use Sub-Agents

### 1. Orchestrator Delegates

The main orchestrator agent uses the **Task tool** to delegate:

```
Task tool with subagent_type="general-purpose" and prompt:

"Read agent-ops/ai/subagents/REQUIREMENTS.md and follow its instructions.

Task: {specific task}
Context: {relevant details}"
```

### 2. Sub-Agent Analyzes

The sub-agent:
1. Reads its instruction file (e.g., REQUIREMENTS.md)
2. Uses Read, Grep, Glob tools to analyze
3. Generates formatted output
4. Returns results with clear "Orchestrator Actions" section

### 3. Orchestrator Implements

The orchestrator:
1. Receives formatted output from sub-agent
2. Performs file operations (Read, Edit, Write)
3. Runs validation tools
4. Reports to user

---

## Complete Example

**User request**: "Add requirements for password reset feature"

**Orchestrator workflow**:

```
1. Orchestrator delegates to Requirements sub-agent:
   "Read agent-ops/ai/subagents/REQUIREMENTS.md and follow its instructions.
    Task: Create requirements for password reset feature
    Context: User authentication system, needs PRD/Ops/Dev cascade"

2. Requirements sub-agent returns:
   - Formatted PRD requirement block (REQ-p00XXX)
   - Formatted Ops requirement block (REQ-o00YYY)
   - Formatted Dev requirement block (REQ-d00ZZZ)
   - List of files to edit (spec/prd-security.md, etc.)

3. Orchestrator performs edits:
   - Edit spec/prd-security.md to insert REQ-p00XXX
   - Edit spec/ops-security.md to insert REQ-o00YYY
   - Edit spec/dev-security.md to insert REQ-d00ZZZ

4. Orchestrator validates:
   - Bash: python3 tools/requirements/validate_requirements.py

5. Orchestrator reports to user:
   "Added 3 requirements for password reset (REQ-p00XXX, REQ-o00YYY, REQ-d00ZZZ)"
```

---

## Sub-Agent Pattern

All sub-agents follow this structure:

### Instruction File Template

```markdown
# {Name} Sub-Agent Instructions

**Role**: {What this sub-agent specializes in}

**Capabilities**: Analysis, recommendations, formatted output generation (NOT direct file modification)

---

## Your Responsibilities

✅ What you DO
❌ What you DON'T do

---

## Core Knowledge Base

{Domain-specific knowledge the sub-agent has}

---

## Tasks You Handle

### Task 1: {Name}

**Orchestrator asks**: "{Example question}"

**Your process**:
1. {Step 1}
2. {Step 2}

**Response format**:
```markdown
{Example formatted response}
```

---

## Response Style

{Guidelines for responses}

---

## Limitations and Boundaries

{Clear boundaries of what sub-agent can/cannot do}
```

---

## Benefits of Sub-Agent Architecture

### 1. Simplified Orchestrator

The main CLAUDE.md doesn't need to contain all the detailed knowledge. It just knows:
- "For requirement tasks, use Requirements sub-agent"
- "For database tasks, use Database sub-agent"

### 2. Deep Expertise

Each sub-agent has comprehensive knowledge of its domain without cluttering the main instructions.

### 3. Consistent Patterns

Sub-agents always return:
- Formatted output ready to use
- Clear "Orchestrator Actions" list
- File paths and line numbers

### 4. Extensible

Add new sub-agents without modifying existing ones:
- Create `SUBAGENT_NAME.md` in this directory
- Add entry to ORCHESTRATOR_GUIDE.md
- Update CLAUDE.md quick reference table

### 5. Testable

Sub-agents can be tested independently by:
1. Reading their instruction file
2. Asking them specific questions
3. Verifying their formatted output

---

## Creating New Sub-Agents

### When to Create a Sub-Agent

Create a new sub-agent when:
- ✅ Domain is complex with many rules/patterns
- ✅ Task requires specialized knowledge
- ✅ Orchestrator repeatedly needs this expertise
- ✅ Domain has clear boundaries and tools

Don't create sub-agents for:
- ❌ Simple one-off tasks
- ❌ Tasks that are self-explanatory
- ❌ Domains without clear patterns

### Sub-Agent Creation Process

1. **Identify domain**: What expertise is needed?
2. **Define boundaries**: What can/cannot the sub-agent do?
3. **Document knowledge**: Write comprehensive instructions
4. **Define response patterns**: How should output be formatted?
5. **Test with examples**: Verify sub-agent works as expected
6. **Update guides**: Add to ORCHESTRATOR_GUIDE.md and CLAUDE.md

### Example Future Sub-Agents

**Database Sub-Agent**:
- Schema design recommendations
- Migration generation
- SQL query optimization
- RLS policy generation

**Testing Sub-Agent**:
- Test case generation
- Coverage analysis
- Test strategy recommendations
- Mock data generation

**Security Sub-Agent**:
- Threat modeling
- RLS policy analysis
- RBAC role design
- Vulnerability pattern detection

---

## Integration with Agent-Ops

**Important**: These sub-agents are **independent** of the agent-ops session tracking system.

**Agent-ops** (`ai-coordination` sub-agent):
- Manages session lifecycle (start, log, complete)
- Maintains diary and archives
- Tracks work in progress

**Specialized sub-agents** (Requirements, Database, etc.):
- Provide domain expertise
- Generate formatted output
- Recommend file operations

**Use both together**:
1. Start session with ai-coordination
2. Use specialized sub-agents for domain tasks
3. Report work to ai-coordination
4. Complete session with ai-coordination

They complement each other - no conflicts.

---

## Documentation

- **ORCHESTRATOR_GUIDE.md**: How orchestrator uses sub-agents (delegation patterns)
- **REQUIREMENTS.md**: Requirements sub-agent instructions
- **{FUTURE}.md**: Additional sub-agent instructions as created

---

**Version**: 1.0
**Location**: agent-ops/ai/subagents/README.md
**Purpose**: Overview of specialized sub-agent system
