# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a multi-sponsor Diary Platform with strict FDA 21 CFR Part 11 compliance requirements. The system uses event sourcing, comprehensive audit trails, and requirement traceability for all code changes.

**Key Characteristics**:
- Multi-sponsor deployment model (shared core + sponsor-specific customization)
- Strict requirement traceability (every change must link to REQ-{p|o|d}NNNNN)
- FDA compliance (21 CFR Part 11, ALCOA+ principles)

## Critical Rules

### 1. Requirement Traceability (MANDATORY)
- **PR titles** must include `[CUR-XXX]` — this is enforced by CI and becomes the squash-merge commit on main
- Requirement format: `REQ-{type}{number}` where type is `p` (PRD), `o` (Ops), or `d` (Dev), and number is 5 digits (e.g., `REQ-d00027`)

### 2. Inline Assertion References (MANDATORY)
- When writing or modifying code, always insert inline comments referencing the Assertion(s) the code implements
- Place the comment as close as practical to the implementing code
- Use only the most specific applicable Assertion(s) — find them via the elspais MCP (e.g., `discover_requirements`)
- Format: `// Implements: REQ-d00027-A` (or the equivalent comment syntax for the language)

### 3. Documentation Hierarchy
- **spec/**: Formal requirements defining WHAT to build, organized by audience
  - `prd-*.md`: Product requirements (NO CODE EXAMPLES)
  - `ops-*.md`: Deployment/operations (CLI commands OK)
  - `dev-*.md`: Implementation guides (code examples OK)
- **docs/**: Implementation notes and Architecture Decision Records (ADRs)
- Always read `spec/README.md` before modifying spec/ files
- See `spec/INDEX.md` for complete REQ index
- Always uses the elspais MCP when looking for assertions or requirements
- You may use the elspais MCP for any requirement-related tasks

### 4. Sponsor Isolation
- each sponsor has its own private repository, such as hht_diary_callisto
- sponsor directories are typically located as siblings to the main repository
- sponsor configuration is specified in the .elspais.toml file
- sponsor-related secrets are kept in Doppler variables

### 5. Branch Protection
- ALWAYS create a new branch before editing/creating/deleting files if on `main`
- Never commit directly to `main`

### 6. Investigate root causes
- ALWAYS investigate root causes for bugs.
- When encountering an error, use a dedicated debugging sub-agent
- pass relevant domain information from a domain-expert agent to the debugging sub-agent
- Tell sub-agents to be aware of the installed plugins and MCPS, especially elspais

### Git Workflow Best Practices
- **ALWAYS** `git pull` before creating PRs to ensure branch is up-to-date with main
- This prevents merge conflicts and ensures CI runs against latest code
- You MAY use the Linear MCP to find an appropriate ticket number

# Security Considerations

- **NEVER commit secrets** (API keys, tokens, passwords)
- Use environment variables for all secrets
- Do not use .env files for secrets
- All secrets are managed via Doppler (e.g. you were run with `doppler run -- claude`)
- Database credentials managed via Doppler (see `spec/ops-security.md`)
- All audit events are tamper-evident (cryptographic hashing)

## Security Scanning (IMPLEMENTS REQ-p01018)

The project uses a **defense-in-depth security scanning strategy** with multiple specialized tools:

### Automated Security Scanners

1. **Gitleaks** (Secret Detection)
   - Runs: Pre-commit hook + CI/CD
   - Purpose: Prevent accidental commit of secrets (API keys, tokens, passwords)
   - Exit behavior: BLOCKS commit/PR if secrets detected
   - Version pinned in `.github/versions.env`

2. **Trivy** (Multi-Layer Vulnerability Scanner)
   - Runs: CI/CD only
   - Purpose: Detect vulnerabilities in dependencies, IaC configs, containers
   - Scan layers:
     - Filesystem: npm, pub, pip package vulnerabilities
     - IaC: Dockerfile, Terraform, K8s misconfigurations
     - Container: Docker image OS package vulnerabilities
   - Exit behavior: Report only (doesn't block PR)
   - Results: Uploaded to GitHub Security → Code scanning

3. **Flutter Analyze** (Dart/Flutter Static Analysis)
   - Runs: CI/CD and locally
   - Purpose: Static analysis for Dart/Flutter code (CodeQL alternative)
   - Checks: Type safety, unused code, potential nulls, security patterns
   - Exit behavior: BLOCKS PR if errors detected

4. **Squawk** (PostgreSQL Migration Safety)
   - Runs: CI/CD only (on changed SQL files)
   - Purpose: Prevent dangerous PostgreSQL migrations (locks, downtime, data loss)
   - Checks: Table locks, missing indexes, unsafe ALTER TABLE, NOT NULL without DEFAULT
   - Exit behavior: BLOCKS PR if dangerous patterns detected
   - Version pinned in `.github/versions.env`

### Why NOT CodeQL?

**CodeQL does NOT support Dart/Flutter** (our primary language). 

### Security Scanning Guidance for Claude

When implementing code:
- **Secrets**: Use environment variables, never hardcode. Gitleaks will block commits with secrets.
- **Dependencies**: Keep packages updated. Trivy alerts appear in GitHub Security tab.
- **Code Quality**: Run `flutter analyze` locally before committing. CI will fail if errors exist.
- **Database Migrations**: Use safe PostgreSQL patterns. Squawk will block dangerous migrations.
  - Always use `CONCURRENTLY` for index creation
  - Add `DEFAULT` when adding NOT NULL columns
  - Avoid operations that lock tables in production
- **Review Findings**: Check PR status checks. Address any security scanner failures before merge.

**Documentation**: See `docs/security/scanning-strategy.md` for complete scanner details, workflows, and troubleshooting.

## Important Notes

- PR validation runs automatically and blocks merge on validation failures

# External Resources

- PostgreSQL Docs: https://www.postgresql.org/docs/
- GCP Identity Platform: https://cloud.google.com/security/products/identity-platform
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

- When a command or a sequence of commands requires execution within a specific directory, use a subshell to contain the directory change. example: (cd /path/to/specific/directory && command1 && command2)
