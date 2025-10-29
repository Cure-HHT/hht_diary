# Orchestrator Guide: Using Specialized Sub-Agents

**Purpose**: Quick reference for when and how to delegate to specialized sub-agents.

---

## Available Sub-Agents

### Requirements Sub-Agent

**File**: `agent-ops/ai/subagents/REQUIREMENTS.md`

**Use when**:
- User asks about requirements system
- Need to find/create/validate requirements
- Need requirement headers for code files
- Analyzing requirement-ticket-code associations
- Explaining requirements methodology

**How to invoke**:
```
Use Task tool with subagent_type="general-purpose" and provide detailed prompt:

"Read agent-ops/ai/subagents/REQUIREMENTS.md and follow its instructions.

Task: {specific requirement task}

Context: {relevant details}"
```

**Example invocations**:

1. **Find requirements**:
```
"Read agent-ops/ai/subagents/REQUIREMENTS.md and follow its instructions.

Task: Find all requirements related to user authentication
Context: User wants to understand what's already specified"
```

2. **Create new requirements**:
```
"Read agent-ops/ai/subagents/REQUIREMENTS.md and follow its instructions.

Task: Create requirements for offline data sync feature
Context: Need top-down cascade (PRD → Ops → Dev) for new feature"
```

3. **Generate code header**:
```
"Read agent-ops/ai/subagents/REQUIREMENTS.md and follow its instructions.

Task: Generate requirement header for database/schema/users.sql
Context: File implements user authentication and RBAC (REQ-p00085, REQ-d00043)"
```

4. **Validate requirements**:
```
"Read agent-ops/ai/subagents/REQUIREMENTS.md and follow its instructions.

Task: Validate all security requirements for completeness
Context: Need to ensure all PRD requirements have Ops/Dev cascade"
```

---

### Documentation Sub-Agent

**File**: `agent-ops/ai/subagents/DOCUMENTATION.md`

**Use when**:
- Documentation is verbose or out of scope
- Need to eliminate repetition across files
- Converting text to properly scoped document
- Too many unnecessary examples
- Inline templates should be references
- Rewriting documentation for conciseness

**How to invoke**:
```
Use Task tool with subagent_type="general-purpose" and provide detailed prompt:

"Read agent-ops/ai/subagents/DOCUMENTATION.md and follow its instructions.

Task: {specific documentation task}

Context: {text to analyze or rewrite}"
```

**Example invocations**:

1. **Analyze scope**:
```
"Read agent-ops/ai/subagents/DOCUMENTATION.md and follow its instructions.

Task: Check if spec/prd-database.md is properly scoped
Context: File may contain SQL code (should be in dev- file)"
```

2. **Eliminate repetition**:
```
"Read agent-ops/ai/subagents/DOCUMENTATION.md and follow its instructions.

Task: Remove repetition across CLAUDE.md and spec/README.md
Context: Requirement format is explained in both files"
```

3. **Rewrite for conciseness**:
```
"Read agent-ops/ai/subagents/DOCUMENTATION.md and follow its instructions.

Task: Rewrite docs/adr/ADR-001.md to be more concise
Context: Currently 450 lines, should be ~150 lines"
```

4. **Replace inline templates**:
```
"Read agent-ops/ai/subagents/DOCUMENTATION.md and follow its instructions.

Task: Replace inline templates in docs/README.md with references
Context: Full ADR template is embedded, should reference template file"
```

---

## Delegation Best Practices

### When to Delegate

✅ **Delegate when**:
- Task requires specialized domain knowledge (requirements system)
- Need detailed analysis across many files
- User explicitly requests requirements work
- Generating formatted output that follows specific patterns

❌ **Don't delegate when**:
- Simple file read/edit operation
- Task is already clear and straightforward
- You have sufficient context to proceed directly

### How to Delegate Effectively

1. **Be specific in prompt**: Tell sub-agent exactly what you need
2. **Provide context**: Include relevant file paths, requirement IDs, user goals
3. **Request actionable output**: Ask for formatted text ready to insert, or clear next steps
4. **Use results directly**: Sub-agent output should be usable without heavy editing

### Example Workflow

**User request**: "Add requirements for the new reporting dashboard"

**Your workflow**:
1. Delegate to Requirements sub-agent:
   ```
   "Read agent-ops/ai/subagents/REQUIREMENTS.md and follow its instructions.

   Task: Create requirements for reporting dashboard feature
   Context: Dashboard will show patient enrollment stats, trial progress metrics.
   Needs PRD (user value), Ops (deployment), Dev (implementation) requirements."
   ```

2. Receive formatted requirement blocks from sub-agent

3. You perform file operations:
   - Read spec/prd-portal.md to find insertion point
   - Edit spec/prd-portal.md to insert PRD requirement
   - Read spec/ops-portal.md to find insertion point
   - Edit spec/ops-portal.md to insert Ops requirement
   - Read spec/dev-portal.md to find insertion point
   - Edit spec/dev-portal.md to insert Dev requirement

4. Validate:
   ```bash
   python3 tools/requirements/validate_requirements.py
   ```

5. Report to user: "Added 3 new requirements (p00XXX, o00YYY, d00ZZZ) for reporting dashboard"

---

## Sub-Agent Response Patterns

### Requirements Sub-Agent Returns:

1. **Formatted requirement blocks** ready to insert:
   ```markdown
   ### REQ-p00XXX: Feature Title
   **Level**: PRD | **Implements**: - | **Status**: Draft
   ...
   ```

2. **Code header comments** ready to insert:
   ```language
   // IMPLEMENTS REQUIREMENTS:
   //   REQ-p00XXX: Title
   ```

3. **Analysis with file references**:
   ```markdown
   - REQ-p00XXX: Title (spec/prd-file.md:123)
   ```

4. **Action lists for orchestrator**:
   ```markdown
   ## Orchestrator Actions Required
   1. Read spec/prd-topic.md
   2. Edit spec/prd-topic.md to insert requirement at line 45
   3. Run validation tool
   ```

### Your Job After Delegation

- **File operations**: Read, Edit, Write as recommended
- **Tool execution**: Run validation scripts, bash commands
- **User communication**: Summarize what was done
- **Error handling**: If validation fails, fix issues or re-delegate

---

## Common Delegation Scenarios

### Scenario 1: User Starting New Feature

**User**: "I want to add password reset functionality"

**Your response**:
1. Acknowledge request
2. Delegate to Requirements sub-agent to create requirements
3. Receive formatted requirements
4. Insert into appropriate spec/ files
5. Validate with tools
6. Report completion to user

### Scenario 2: User Asks About Existing Requirements

**User**: "What requirements cover authentication?"

**Your response**:
1. Delegate to Requirements sub-agent to find auth requirements
2. Receive structured list with file locations
3. Read relevant spec files for details if needed
4. Present summary to user

### Scenario 3: Code Needs Requirement Headers

**User**: "Add requirement headers to database schema files"

**Your response**:
1. Identify which files need headers
2. For each file, delegate to Requirements sub-agent:
   - "Generate requirement header for {file}"
   - Include which requirements the file implements
3. Receive formatted headers
4. Insert headers into files
5. Report completion

### Scenario 4: Validating Traceability

**User**: "Check if all requirements are properly linked"

**Your response**:
1. Delegate to Requirements sub-agent for analysis
2. Receive validation report
3. If issues found, work with sub-agent to fix:
   - Missing requirements
   - Broken links
   - Format issues
4. Run validation tool to confirm
5. Report to user

---

## Integration with Agent-Ops System

These specialized sub-agents are **independent** of the agent-ops session tracking system:

- **Agent-ops** (ai-coordination): Manages session lifecycle, diary, archives
- **Specialized sub-agents** (requirements, etc.): Provide domain expertise

**Can use both**:
1. Start session via ai-coordination: `{"event": "start_feature", ...}`
2. Delegate to Requirements sub-agent for requirement work
3. Report implementation to ai-coordination: `{"event": "log_work", ...}`
4. Complete session via ai-coordination: `{"event": "complete_feature"}`

**They don't conflict** - use as needed for your workflow.

---

## Future Sub-Agents (Placeholder)

As the project grows, additional specialized sub-agents can be added:

- **Database Sub-Agent**: Schema design, migration generation, SQL expertise
- **Testing Sub-Agent**: Test generation, coverage analysis, test strategy
- **Documentation Sub-Agent**: ADR creation, README updates, doc structure
- **Security Sub-Agent**: RLS policy generation, RBAC analysis, threat modeling
- **Linear Sub-Agent**: Ticket creation, requirement-ticket linking, workflow automation

Each sub-agent follows the same pattern:
1. Instructions in `agent-ops/ai/subagents/{NAME}.md`
2. Read-only analysis and generation (no direct file modification)
3. Returns formatted output for orchestrator to use
4. Clear "Orchestrator Actions" section in responses

---

## Quick Reference

| Need | Sub-Agent | Example Prompt |
|------|-----------|----------------|
| Find requirements | Requirements | "Find all requirements related to {topic}" |
| Create requirements | Requirements | "Create requirements for {feature}" |
| Code headers | Requirements | "Generate header for {file} implementing {REQs}" |
| Validate requirements | Requirements | "Validate requirements for {topic}" |
| Requirement tracing | Requirements | "Show full trace for REQ-{id}" |
| Check doc scope | Documentation | "Check if {file} is properly scoped" |
| Eliminate repetition | Documentation | "Remove repetition across {files}" |
| Rewrite doc concisely | Documentation | "Rewrite {file} to be more concise" |
| Replace inline templates | Documentation | "Replace inline templates in {file} with references" |
| Remove unnecessary examples | Documentation | "Review examples in {file}, keep only essential" |

---

**Version**: 1.0
**Location**: agent-ops/ai/subagents/ORCHESTRATOR_GUIDE.md
**Purpose**: Quick reference for orchestrator to use specialized sub-agents
