# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a multi-sponsor Diary Platform with strict FDA 21 CFR Part 11 compliance requirements. The system uses event sourcing, comprehensive audit trails, and requirement traceability for all code changes.

**Key Characteristics**:
- Multi-sponsor deployment model (shared core + sponsor-specific customization)
- Strict requirement traceability — REQ ID format varies by repo (see §1)
- FDA compliance (21 CFR Part 11, ALCOA+ principles)
- Plugin-based workflow enforcement via Claude Code marketplace plugins

## Critical Rules

### 1. Requirement Traceability (MANDATORY)

- **PR titles** must include `[CUR-XXX]` — enforced by CI; becomes the squash-merge commit on main.
- **Commit messages**: no enforced format for CUR-XXX or REQ-XXX references (`ENFORCE_CUR_IN_COMMITS` / `ENFORCE_REQ_IN_COMMITS` disabled).
- **REQ ID conventions vary by repo.** Use the convention of the repo whose spec defines the REQ being cited:

  | Repo | REQ ID format | Example |
  | ---- | ------------- | ------- |
  | `hht_diary` (this repo) | `DIARY-{PRD\|GUI\|OPS\|DEV}-{kebab-name}` | `DIARY-PRD-action-inventory`, `DIARY-GUI-user-account-deactivate` |
  | `hht_diary_callisto` | `CAL-{PRD\|GUI\|OPS\|DEV}-{kebab-name}` | `CAL-PRD-permissions-table`, `CAL-GUI-portal-questionnaire-callback` |
  | `hht_admin` | `HHT-{PRD\|OPS\|DEV}-{kebab-name}` | `HHT-OPS-storage-rules` |
  | `event_sourcing` | `EVS-{PRD\|OPS\|DEV}-{kebab-name}` | `EVS-DEV-provenance-entry-schema` |
  | `hht_workflows` (public CI) | no own REQs; consumes from `hht_admin` (e.g. `HHT-OPS-composite-action-library`) | — |

  `hht_diary`'s legacy `REQ-{p\|o\|d}NNNNN` format was migrated to the entity-first kebab convention above on 2026-05-15. The pre-migration tree is preserved under `spec-archive/` for reference and is not scanned by elspais.

  Naming convention: **entity-first kebab-case**. Group related requirements by their primary entity so file listings self-organize (e.g. `DIARY-PRD-user-account-create`, `DIARY-PRD-user-account-edit`, `DIARY-PRD-user-account-deactivate`).

  Named REQ IDs are **stable**: renaming is a breaking change for every reference (annotations, `Refines:`/`Satisfies:` metadata, Rationale prose). Coordinate sweeps; call out renames explicitly in the commit.

- **Annotate functions / script steps with specific Assertions — NOT file-header `IMPLEMENTS REQUIREMENTS:` blocks.** The unit of traceability is the assertion (A, B, C, ...), not the whole REQ. Cite by appending the assertion label(s):

  ```dart
  // Implements: DIARY-PRD-user-account-deactivate/A+B
  void deactivateUserAccount(String userId, String reason) { ... }
  ```

  ```yaml
  # Implements: HHT-OPS-identity-over-keys/A
  - name: Authenticate to Google Cloud
    uses: google-github-actions/auth@<sha>
    ...
  ```

  ```bash
  # Verifies: HHT-OPS-no-secrets-in-tf-state/B
  assert_no_secret_in_state "$TF_STATE_PATH"
  ```

  Format: `<REQ-id>/<assertion-list>`. Single assertion: `/A`. Multiple assertions of one REQ on one unit: `/A+B+D` (elspais default `multi_separator`). Multiple REQs on one unit: stack the annotations as separate comment lines. Use `// Implements:` (or `# Implements:`) on production-code units; use `// Verifies:` (or `# Verifies:`) on test units. Cross-repo refs use the foreign repo's format (e.g. a `hht_diary` file may carry `// Implements: HHT-OPS-identity-over-keys/B` to cite hht_admin's spec).

- **`spec-archive/`** holds the pre-2026-05 spec tree (legacy `REQ-{p|o|d}NNNNN` ids). Read-only reference for the URS-v1 migration. Not scanned by elspais; not part of the active traceability graph.

### 2. Workflow Enforcement
- You MUST claim a ticket using the `workflow:workflow` sub-agent
- You MAY use the `linear-api:linear-api` sub-agent to find an appropriate ticket number
- When doing a PR you MAY use the `workflow:workflow` sub-agent to release a ticket

### 3. Documentation Hierarchy
- **spec/**: Formal requirements defining WHAT to build, organized by audience
  - `prd-*.md`: Product requirements (NO CODE EXAMPLES)
  - `gui-*.md`: Presentation requirements — interface behavior, layout, interaction patterns (refines a PRD parent)
  - `ops-*.md`: Deployment/operations (CLI commands OK)
  - `dev-*.md`: Implementation guides (code examples OK)
- **spec/_generated/**: Build artifacts emitted by elspais (`INDEX.md`, glossary, term index). Committed for review; do not edit by hand.
- **spec-archive/**: Pre-2026-05 spec snapshot (legacy ids); reference only, not scanned.
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

### 7. Phase Design Spec Requirements

This rule applies to `hht_diary`'s own design specs at `docs/superpowers/specs/*-design.md`. (The repo's pre-commit hook enforces it. `docs/superpowers/` is gitignored — these files are working artifacts and the hook only triggers if you `git add -f`.)

Every new design spec MUST include a `## Requirements` section that:

- Lists existing applicable REQs. For `hht_diary` REQs, use `discover_requirements` via the elspais MCP. For cross-repo REQs (`HHT-*` in `hht_admin`, `EVS-*` in `event_sourcing`), cite by name with the file path of the authoritative spec.
- Drafts new REQ entries (title, rationale, assertion list A/B/C/...) for any new functionality. New `hht_diary` REQs claim `DIARY-{PRD|GUI|OPS|DEV}-{kebab-name}` ids (pick the entity-first kebab slug at authoring time; the slug is stable) and land in `spec/prd-*.md`, `spec/gui-*.md`, `spec/ops-*.md`, or `spec/dev-*.md` via the implementation plan; new `CAL-*` / `HHT-*` / `EVS-*` REQs land in the relevant sibling repo's `spec/`.
- Identifies the function-level `// Implements: <REQ-id>/<assertion-list>` (production code) and `// Verifies: <REQ-id>/<assertion-list>` (tests) annotations the plan must apply on every code unit it touches. **No file-header `IMPLEMENTS REQUIREMENTS:` blocks** — see §1.
- References the required `spec/dev-*.md` and `spec/INDEX.md` updates (or, for cross-repo REQs, the sibling repo's spec update).

For stub files at `docs/superpowers/specs/*-stub.md`: a single line "Requirements: deferred until full design" suffices — the obligation lands when the stub is upgraded to a full design spec.

Pre-commit hook enforcement: `.githooks/pre-commit` section 6 checks that `*-design.md` files include `## Requirements` and at least one REQ reference. Both the new `DIARY-/CAL-/HHT-/EVS-{PRD|GUI|OPS|DEV}-{kebab}` form and the legacy `REQ-[pod]NNNNN` form satisfy the check (the latter still needed while `spec-archive/` source files are cherry-picked during the URS-v1 migration). To bypass (NOT RECOMMENDED): `git commit --no-verify`.


## Project Structure

```
.
├── spec/                      # Formal requirements (prd-*, ops-*, dev-*)
│   ├── INDEX.md              # Complete requirements index
│   └── README.md             # Naming conventions & scope definitions
├── docs/                      # ADRs and implementation guides
│   └── adr/                  # Architecture Decision Records
├── database/                  # PostgreSQL schema
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
│   └── dev-env/              # Docker dev containers (role-based)
├── .githooks/                 # Git hooks for enforcement
└── .devcontainer/             # Dev container config (recommended)
```


# Plugins

You orchestrate common tasks using dedicated sub-agents.
**ALWAYS** consider using plugin sub-agents for each task first.
Use sub-agents in parallel when possible. 
You may use multiple instances of a sub-agent in parallel when appropriate.

The following **priority plugins** are provided by the `anspar-wf` package (installed via pip)

## use `workflow:workflow` sub-agent for
- changes in top-level tasks, as indicated by the current ticket or REQuirement
- changes in tasks phase: new/resume, validation, debug, completion, sharing (e.g. git push)
- work on sponsor-specific tasks is in the appropriate directory

### Git Workflow Best Practices
- **ALWAYS** `git pull` before creating PRs to ensure branch is up-to-date with main
- This prevents merge conflicts and ensures CI runs against latest code

## use `linear-api:linear-api` sub-agent for
- anything related to using the Linear API
- Fetch/create/update Linear tickets (issues)

## use `requirement-traceability:requirement-traceability` sub-agent for
- Requirement-to-ticket traceability

## use `simple-requirements:simple-requirements` sub-agent for
- REQ format, parse, general rules

## use `spec-compliance:spec-compliance` sub-agent to
- Enforce spec/ directory guidelines
- Validate content and format of files in spec/

## **ALWAYS** use `plugin-wizard:plugin-wizard` sub-agent to
- make any changes to sub-agents or plugins
- research plugins
- validate plugins


# Security Considerations

- **NEVER commit secrets** (API keys, tokens, passwords)
- Use environment variables for all secrets
- Do not use .env files for secrets
- All secrets managed via Doppler (e.g. you were run with `doppler run -- claude`)
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

**CodeQL does NOT support Dart/Flutter** (our primary language). The "28 CodeQL alerts" in repository history were about GitHub Actions workflow files, not codebase security. CodeQL was never actually enabled for application code scanning.

**Current approach provides better coverage**:
- Trivy scans dependencies and infrastructure
- Flutter Analyze provides Dart-specific static analysis
- Squawk prevents PostgreSQL migration issues
- Gitleaks prevents secret leaks

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

- The workflow plugin provides proactive task-switching detection via UserPromptSubmit hooks
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

**Example**: When working with plugins, prefer `/plugin-wizard` over manually creating plugin files.
- always try to use a specific plugin sub-agent
- When a command or a sequence of commands requires execution within a specific directory, use a subshell to contain the directory change. example: (cd /path/to/specific/directory && command1 && command2)