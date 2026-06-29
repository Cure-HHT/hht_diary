# Documentation Directory

This directory contains **implementation and operational documentation** that describes HOW the system is built and maintained, separate from formal requirements.

## Purpose

While `spec/` contains formal requirements documents (WHAT and WHY), the `docs/` directory contains:
- Architecture Decision Records (ADRs)
- Implementation guides and tutorials
- Operational runbooks
- Design notes and technical explanations
- Investigation reports and research findings

## Directory vs spec/

| Directory | Purpose | Content Type | Example |
| --- | --- | --- | --- |
| **spec/** | Formal requirements | WHAT system does, WHY it exists | `prd-diary-app.md`: "System must support offline data entry" |
| **docs/** | Implementation details | HOW decisions were made, technical context | `adr/ADR-001-event-sourcing.md`: "We chose event sourcing because..." |

### Key Differences

**spec/ files are requirements** - They define:
- ✅ What features exist
- ✅ What compliance standards apply
- ✅ What the system must do
- ✅ How to deploy and operate (ops- files)
- ✅ How to implement features (dev- files)

**docs/ files are documentation** - They explain:
- ✅ Why we made specific technical choices
- ✅ What alternatives were considered
- ✅ What trade-offs were accepted
- ✅ How complex systems work internally
- ✅ What investigations were conducted

## Directory Structure

docs/ uses **flat hierarchical naming** for maximum visibility. Most files live in the root with topic-based prefixes; a handful of subdirectories group related material.

### Subdirectories

#### adr/ - Architecture Decision Records

Formal ADR process with template/lifecycle for documenting significant architectural decisions.

**See**: `adr/README.md` for the ADR process and index.

**Examples**:
- `ADR-001-event-sourcing-pattern.md` - Why we use event sourcing

#### operations/ - Operational runbooks

Runbooks for running the deployed system (`runbook-*`): incident response, release/hotfix, dev-environment maintenance.

#### Other subdirectories

- `gcp/` - GCP setup guides (Cloud SQL, Identity Platform, Cloud Run)
- `security/` - Security scanning strategy and secret-management integration
- `migration/` - Platform migration notes
- `branch-and-release/` - Branching strategy and release-flow diagrams
- `diagram/` - Architecture diagrams (source + exports)
- `whitepapers/` - Authentication and design whitepapers
- `e2e/` - End-to-end test runbooks
- `sponsor-summaries/` - Sponsor-facing feature overviews
- `archive/` - Retained reference material (e.g. the URS-v1 migration mapping)

### Root Files - Flat Hierarchical Naming

Most documentation lives in the root with topic-based prefixes for easy discovery.

**File Naming Convention**: `{topic}-{subtopic}-{details}.md`

**Topics**:
- **setup-\*** : Onboarding, configuration, getting started
  - Examples: `setup-team-onboarding.md`, `setup-dev-environment.md`
- **operations/** : Operational runbooks live in the `operations/` subdirectory, named `runbook-*`
  - Examples: `operations/runbook-incident-response.md`, `operations/runbook-hotfix.md`
- **setup-\*-architecture** : System architecture (non-ADR implementation details)
  - Examples: `setup-dev-environment-architecture.md`
- **compliance-\*** : Compliance audits and verification
  - Examples: `compliance-gcp-verification.md`

**Finding files**:
```bash
ls docs/setup-*        # All setup documentation
ls docs/ops-*          # All operations documentation
ls docs/*monitoring*   # All monitoring-related docs
```

**Benefits**:
- `ls docs/` shows all topics immediately
- No hidden content in subdirectories
- Self-documenting filenames
- Easy to grep and search

## When to Add Documentation Here

### Add to docs/ when:
- 📝 Documenting a significant architectural decision (→ `adr/`)
- 📝 Explaining complex implementation details not obvious from code
- 📝 Recording investigation results or research findings
- 📝 Writing detailed operational guides beyond deployment

### Add to spec/ instead when:
- ✅ Defining a new feature or requirement
- ✅ Specifying how to deploy/configure the system (→ `ops-*.md`)
- ✅ Documenting how to implement a feature (→ `dev-*.md`)
- ✅ Describing what the system does (→ `prd-*.md`)

## Cross-Referencing

Documents can reference each other across directories:

**From spec/ to docs/**:
```markdown
This feature uses event sourcing (see docs/adr/ADR-001-event-sourcing-pattern.md
for the architectural decision).
```

**From docs/ to spec/**:
```markdown
This ADR implements requirements REQ-p00004 and REQ-p00013
(see spec/prd-database.md).
```

## Contributing

When adding documentation:

1. **Determine the right location**:
   - Is this a requirement or constraint? → `spec/`
   - Is this explaining a decision or implementation? → `docs/`

2. **Follow the appropriate format**:
   - ADRs: Use the ADR template in `adr/README.md`
   - Other docs: Use clear markdown with headings and examples

3. **Link to requirements**:
   - If documenting code, include requirement references
   - If explaining a decision, reference the requirements it addresses

4. **Update indexes**:
   - Update `adr/README.md` index when adding ADRs
   - Update this README if adding new subdirectories

## References

- **Requirement grammar**: the elspais MCP (`agent_instructions()` / `docs()`)
- **Spec directory**: `spec/README.md`
- **ADR process**: `adr/README.md`
- **Project instructions**: `CLAUDE.md`
