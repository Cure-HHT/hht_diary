# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a multi-sponsor Clinical Trial Diary Platform with strict FDA 21 CFR Part 11 compliance requirements. The system uses event sourcing, comprehensive audit trails, and requirement traceability for all code changes.

**Key Characteristics**:
- Multi-sponsor deployment model (shared core + sponsor-specific customization)
- Strict requirement traceability (every change must link to REQ-{p|o|d}NNNNN)
- FDA compliance (21 CFR Part 11, ALCOA+ principles)
- Plugin-based workflow enforcement via Claude Code marketplace plugins

## Critical Rules

### 1. Requirement Traceability (MANDATORY)
- **ALL commits** must include `Implements: REQ-xxx` or `Fixes: REQ-xxx` in commit messages
- Git hooks enforce this - commits without REQ references will be blocked
- Requirement format: `REQ-{type}{number}` where type is `p` (PRD), `o` (Ops), or `d` (Dev), and number is 5 digits (e.g., `REQ-d00027`)
- Implementation files must include requirement headers, e.g.:
  ```sql
  -- IMPLEMENTS REQUIREMENTS:
  --   REQ-d00027: Workflow plugin state management
  --   REQ-p00042: Event sourcing audit trail
  ```

### 2. Workflow Enforcement
- You MUST claim a ticket using the workflow sub-agent
- You MAY use the linear-api sub-agent to find an appropriate ticket number
- When doing a PR you MAY use the workflow subg-agent to release a ticket

### 3. Documentation Hierarchy
- **spec/**: Formal requirements defining WHAT to build, organized by audience
  - `prd-*.md`: Product requirements (NO CODE EXAMPLES)
  - `ops-*.md`: Deployment/operations (CLI commands OK)
  - `dev-*.md`: Implementation guides (code examples OK)
- **docs/**: Implementation notes and Architecture Decision Records (ADRs)
- Always read `spec/README.md` before modifying spec/ files
- See `spec/INDEX.md` for complete REQ index

### 4. Sponsor Isolation
- Each sponsor has isolated code in `sponsor/{name}/`
- NEVER cross-reference sponsors or share (inherit) sponsor-specific code
- Core functionality goes in `packages/`, `apps/`, `database/`

### 5. Branch Protection
- ALWAYS create a new branch before editing/creating/deleting files if on `main`
- Never commit directly to `main`
- Follow branch naming: `feature/`, `fix/`, `release/`

### 6. Investigate root causes
- ALWAYS investigate root causes for bugs.
- When encountering an error, use a dedicated debugging sub-agent
- pass relevant domain information from a domain-expert agent to the debugging sub-agent
- Tell sub-agents to be aware of the installed plugins and their sub-agents
- because agents cannot communicate directly with each other, 
they should report to the orchestrator any messages they want to pass to another sub-agent


## Project Structure

```
.
├── spec/                      # Formal requirements (prd-*, ops-*, dev-*)
│   ├── INDEX.md              # Complete requirements index
│   └── README.md             # Naming conventions & scope definitions
├── docs/                      # ADRs and implementation guides
│   └── adr/                  # Architecture Decision Records
├── database/                  # PostgreSQL schema (Supabase)
│   ├── schema.sql            # Core table definitions
│   ├── triggers.sql          # Event store & audit triggers
│   ├── rls_policies.sql      # Row-level security
│   └── migrations/           # Database migrations
├── packages/                  # Core Flutter abstractions (shared)
├── apps/                      # Flutter app templates
├── sponsor/                   # Sponsor-specific implementations
│   └── {sponsor-name}/       # Isolated per sponsor
├── tools/                     # Development & automation tools
│   ├── requirements/         # Validation & traceability scripts
│   ├── dev-env/              # Docker dev containers (role-based)
│   └── anpar-cc-plugins/   # Claude Code plugins
├── .githooks/                 # Git hooks for enforcement
└── .devcontainer/             # Dev container config (recommended)
```


# Plugins

You orchestrate common tasks using dedicated sub-agents.
**ALWAYS** consider using plugin sub-agents for each task first.
Use sub-agents in parallel when possible. 
You may use multiple instances of a sub-agent in parallel when appropriate.

The following **priortiy plugins** are located in `tools/anspar-cc-plugins/plugins/workflow/`

## use workflow sub-agent for
- changes in top-level tasks, as indicated by the current ticket or REQuirement
- changes in tasks phase: new/resume, validation, debug, completion, sharing (e.g. git push)
- work on sponsor-specific tasks is in the appropriate directory

### Git Workflow Best Practices
- **ALWAYS** `git pull` before creating PRs to ensure branch is up-to-date with main
- This prevents merge conflicts and ensures CI runs against latest code

## use linear-api sub-agent for
- anything related to using the Linear API
- Fetch/create/update Linear tickets (issues)

## use requirement-traceability for 
- Requirement-to-ticket traceability

## use simple-requirements sub-agent for
- REQ format, parse, general rules

## use spec-compliance sub-agent to
- Enforce spec/ directory guidelines
- Validate content and format of files in spec/

## **ALWAYS** use plugin-wizard to 
- make any changes to sub-agents or plugins
- research plugins
- validate plugins


# Security Considerations

- **NEVER commit secrets** (API keys, tokens, passwords)
- Use environment variables for all secrets
- Do not use .env files for secrets
- All secrets managed via Doppler (e.g. you were run with `doppler run -- claude`)
- Supabase credentials managed via Doppler (see `spec/ops-security.md`)
- All audit events are tamper-evident (cryptographic hashing)

## Important Notes

- The workflow plugin provides proactive task-switching detection via UserPromptSubmit hooks
- All new requirement IDs generated via GitHub Actions to prevent conflicts
- PR validation runs automatically and blocks merge on validation failures

# External Resources

- Supabase Docs: https://supabase.com/docs
- PostgreSQL Docs: https://www.postgresql.org/docs/
- FDA 21 CFR Part 11: https://www.fda.gov/regulatory-information
- Linear API: https://developers.linear.app/
- Flutter Docs: https://docs.flutter.dev/

# Agent Orchestration Pattern
<!-- ORCHESTRATION_V1 -->

When working with plugins that provide specialized agents:

- **ALWAYS check for available sub-agents** before implementing complex tasks
  - Use `/agents` command to see available specialized agents
  - Check plugin documentation for agent capabilities

- **Delegate to sub-agents** when their expertise matches the task
  - Sub-agents have deep domain knowledge and specialized tools
  - They follow architectural patterns and best practices
  - They provide faster, more accurate results than general implementation

- **Act as orchestrator, not implementer** when agents are available
  - Your role: Understand requirements, select appropriate agent, validate results
  - Agent's role: Execute specialized tasks using domain-specific knowledge
  - Avoid reimplementing functionality that agents provide

- **Trust agent expertise** but validate results
  - Agents are designed to handle specific domains correctly
  - Review their outputs for correctness and completeness
  - Escalate to user when agent results are unclear or incorrect

**Example**: When working with plugins, prefer `/plugin-wizard` over manually creating plugin files.
- always try to use a specific plugin sub-agent