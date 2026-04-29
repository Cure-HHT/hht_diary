# Agent Design Principles

**Read this file at the start of each session and after each compact event.**

This is the HHT Diary adaptation of the principles file. The HHT Diary project is a Dart/Flutter monorepo with FDA 21 CFR Part 11 compliance, multi-sponsor isolation, event sourcing, and strict requirement traceability. Every principle below is one of: a generic agent-discipline rule, a Dart/project-specific adaptation, or a project-specific addition (security, sponsor isolation, FDA compliance).

## Core Architecture Principles

- The event log is the source of truth for state changes; DO NOT introduce parallel state stores.
- The requirement graph (managed by the `elspais` MCP server) is the single source of truth for `REQ-{p|o|d}NNNNN` identifiers and assertion text. DO NOT keep parallel REQ databases.
- DO NOT change the shape of `Source`, `StoredEvent`, `StorageBackend`, `EntryTypeDefinition`, or `ProvenanceEntry` without an explicit REQ amendment.
- DO NOT violate existing encapsulation.
- DO NOT consult git history for context; rely on the current state of the code and the requirement graph.
- DO NOT cross-reference sponsor-specific code in `sponsor/{name}/`; sponsors are isolated by deployment (per-sponsor VPC), not just by build flag (CLAUDE.md "Sponsor Isolation").

## API Usage

- ALWAYS use existing library APIs in `apps/common-dart/`, `apps/common-flutter/`, and `packages/`.
- ALWAYS use `EventStore.append` / `ingestBatch` / `ingestEvent` for event-log mutations; DO NOT bypass to `StorageBackend` directly except inside library internals.
- ALWAYS use `mcp__elspais__*` tools to query/mutate the requirement graph; DO NOT grep `spec/` when a graph query exists.
- Use `mcp__elspais__discover_requirements`, `search`, or `get_requirement` for REQ lookups before grepping spec files.
- DO NOT manually traverse provenance chains when `EventStore.isLocallyOriginated` / `EventStore.verifyEventChain` cover the case.

## Testing

- ALWAYS include `// Verifies: REQ-xxx-Y` annotations in test bodies, pointing at specific assertion IDs.
- Test names SHOULD reference a specific assertion (e.g., `test_REQ_d00141_A_renames_event_store`).
- Tests without assertion references will not link to requirements in the traceability graph.
- ALWAYS use a sub-agent to write tests (CLAUDE.md "Agent Orchestration Pattern").
- Run `dart test` (or the package's `flutter test`) before committing; use `dart analyze` for static checks. CI also runs `flutter analyze` and blocks the PR on errors.
- For database changes, run the SQL test suite under `database/tests/` (file pattern `*_test.sql`) — see `database/tests/run_all_tests.sh`.

## Workflow

- ALWAYS work on a feature branch (`feature/`, `fix/`, or `release/`); never commit to `main` (CLAUDE.md Rule 5).
- ALWAYS bump the version in the touched package's `pubspec.yaml` before each commit.
- PR titles MUST include `[CUR-NNNN]` (CLAUDE.md Rule 1, enforced by CI).
- Update the touched package's `CHANGELOG.md` if the package has one (check before assuming).
- Update `CLAUDE.md` for architectural changes.
- Update `spec/INDEX.md` when adding new REQs.
- Run `.githooks/pre-commit` before committing; it enforces REQ-trace and Phase Design Spec compliance (CLAUDE.md Rule 7).
- Commit after each phase; DO NOT batch multiple phases into one commit.
- DO NOT use `--no-verify` to bypass hook failures; diagnose and fix.
- ALWAYS `git pull --rebase` before opening a PR to ensure the branch is up-to-date with `main`.

## Implementation

- Search the codebase for existing functionality before implementing.
- Reuse existing modules in `apps/common-dart/`, `apps/common-flutter/`, and `packages/`.
- New interface layers MUST consume existing APIs directly without intermediate data structures.
- DO NOT introduce `sponsor_id` plumbing in any backend data layer; sponsor tenancy is enforced by per-sponsor VPC infrastructure.
- Library code stays generic — DO NOT bake server-product names (`diary-server`, `portal-server`) into library types or constants; use role-based identifiers per the open `Source.hopId` taxonomy (REQ-d00142).
- Cross-cutting protocols (concurrency, merge, audit) belong in shared libraries, not duplicated in each consumer.

## Spec Authoring

### Read first (in order)

Before drafting or reviewing any REQ, read:

1. `spec/requirements-spec.md` — the canonical grammar, identity rules, hashing, decomposition, and reference rules for THIS repo's `REQ-{p|o|d}NNNNN` namespace (336 lines; the authoritative formal-requirements spec).
2. `spec/NFR/style-guide.md` — sponsor-shared authoring style rules: EARS syntax for conditional REQs, glossary term enforcement, assertion independence, assertion clarity (no ambiguous adjectives), notation and formatting (ISO 8601 dates/times, acronym definition, variable placeholders).
3. `spec/NFR/spec-review-checklist.md` — the peer-review checklist used as the human-in-the-loop gate before a REQ is hashed into the validation suite.
4. `spec/NFR/glossary-core.md`, `spec/NFR/glossary-conflict.md`, `spec/NFR/glossary-example.md` — the System Glossary plus authoring conventions for marking domain-specific terms (`**term**` for System-Glossary terms, `__term__` for Reference-Document terms).
5. `spec/NFR/requirements-spec.md` — sponsor-shared formal-requirements spec from the platform repo (complements this repo's `spec/requirements-spec.md`).
6. `spec/NFR/SDLC-SOP.md`, `spec/NFR/change_control.md`, `spec/NFR/standard_changes.md`, `spec/NFR/risks.md`, `spec/NFR/software-validation-plan.md`, `spec/NFR/validation-package.md` — process / governance docs for the SDLC, change control, and validation packaging.
7. `spec/AI-AGENT.md` — the AI-agent usage note for requirements authoring (non-negotiable constraints: one-way traceability, no acceptance-criteria sections, atomic assertions, stable assertion labels).
8. `spec/EXAMPLE-requirement.md` — a one-screen example showing the structural template (heading, level/status/implements line, assertions, rationale, end-marker with hash).

`spec/NFR/` is added to elspais `skip_dirs` and `.markdownlintignore` because (a) its REQs use a `REQ-CAL-*` namespace from the platform repo that does not match this repo's `REQ-{p|o|d}NNNNN` pattern, and (b) the glossary uses `__term__` vs `**term**` as a meaningful distinction that conflicts with `markdownlint`'s MD050 single-strong-style rule. Cite NFR files by file path from dev/ops/prd specs.

### Drafting rules

- Before authoring or editing a REQ that names a code symbol (class, method, field, file path, package), grep current code to confirm the symbol exists. Categorize each symbol as: exists, net-new (proposed by this spec), or stale (named-but-renamed). Only proceed after the audit clears.
- Use final-state voice in spec files — no "removed / no longer / does NOT require" framing; greenfield has no prior version to contrast with.
- Frame requirements as vendor-side capability ("the system SHALL provide the capability to...") rather than regulated-entity compliance ("the system SHALL comply with..."). The regulations apply to our customers (sponsors / CROs); our job is to provide the tools and evidence that let them comply.
- Use "link" or "connect" for participant-device-sponsor association; DO NOT use "enroll" — enrollment is the sponsor's regulated activity, not ours.
- Apply `spec/NFR/style-guide.md` REQ-CAL-o00001 (EARS): use `When [trigger], the System SHALL ...` for event-driven, `While [state], ...` for state-driven, `If [unwanted event], then ...` for unwanted-behavior, `Where [optional feature], ...` for optional-feature; and the bare `The System SHALL ...` for ubiquitous obligations.
- Apply REQ-CAL-o00003 (assertion independence): each assertion must be atomic and independently decidable; no semicolons, conjunctions, or "as well as" / "in addition to" introducing a second testable action. (A single predicate over a list — "SHALL NOT contain X, Y, or Z" — is one obligation, not compound.)
- Apply REQ-CAL-o00004 (assertion clarity): no ambiguous adjectives ("fast", "secure", "user-friendly"); use measurable thresholds. PRD-level assertions SHALL NOT reference programming languages, libraries, frameworks, schemas, or API signatures.
- Apply REQ-CAL-o00004-D: `SHALL` only inside the `Assertions` section (not in Rationale prose), except inside quoted examples.
- Every new phase design spec at `docs/superpowers/specs/*-design.md` MUST include a `## Requirements` section (CLAUDE.md Rule 7; enforced by `.githooks/pre-commit`).

### elspais auto-fix surprises

The pre-commit hook runs `elspais fix` which auto-stages REQ hash updates and regenerates `spec/INDEX.md`. Two real failure modes worth knowing:

- **Sub-section headers under `## Assertions` break parsing.** A REQ shaped as `## Assertions\n\n### Group 1\n\nA. ...\nB. ...\n\n### Group 2\n\nF. ...` is rewritten by `elspais fix` on a SUBSEQUENT commit: it REPLACES the `## Assertions` line with a synthetic `*End* *Title* | **Hash**: N/A` marker, terminating the REQ at the rationale and orphaning the lettered assertions. This was observed in REQ-d00157's history (commit `8b211ef7` diff). DO NOT use `### sub-section` headers between `## Assertions` and the lettered assertions; group via inline parentheticals on the assertion text instead (e.g., `A. (Causality field) ...`, `F. (Aggregate version query) ...`).
- **Hash regeneration is one commit lagged.** The hash literal in the file (`*End* ... | **Hash**: <hex>`) is stamped by `elspais fix` AFTER your edit. A freshly authored REQ with placeholder hash `00000000` may persist for one commit; the next commit touching the file will normalize it. Don't try to compute hashes yourself — let the hook do it.

## Architecture Review

- After implementing a feature, ALWAYS have a sub-agent evaluate architectural soundness.
- The review MUST check that the implementation uses existing APIs appropriately.
- The review MUST check that shared library functions are not being overlooked.
- The review MUST verify compliance with the specification REQs cited in the implementation's `// Implements:` headers.
- Use `feature-dev:code-reviewer` or `superpowers:code-reviewer` for post-implementation review.

## Specification Compliance

- Implementation MUST comply with specification assertions.
- When a REQ says "SHALL be at <path>" or "SHALL be named <X>", DO NOT diverge silently — amend the REQ or align the code.
- Add `// Implements: REQ-d00XXX-A` comments to new/modified source so the traceability graph picks up coverage.
- Cross-reference implementation against spec assertions before committing.

## Sub-Agent Usage

- Use plugin sub-agents per CLAUDE.md "Plugins":
  - `workflow:workflow` — ticket-lifecycle changes (claim, validate, debug, complete, push)
  - `linear-api:linear-api` — Linear ticket fetch/create/update
  - `requirement-traceability:requirement-traceability` — REQ-to-ticket traceability
  - `simple-requirements:simple-requirements` — REQ format and parsing
  - `spec-compliance:spec-compliance` — `spec/` directory enforcement
  - `plugin-wizard:plugin-wizard` — any plugin changes
  - `feature-dev:code-architect`, `feature-dev:code-explorer`, `feature-dev:code-reviewer` — design / exploration / review
  - `superpowers:*` skills — brainstorming, planning, debugging, TDD
- Provide sub-agents with: master plan path, task file path, current task number, current checklist item.
- Tell sub-agents to read this file before starting work.
- Always check for available sub-agents before implementing complex tasks (CLAUDE.md "Agent Orchestration Pattern").

## Security

- DO NOT commit secrets (API keys, tokens, passwords, `.env` files).
- All secrets are managed via Doppler; the harness was started with `doppler run --`.
- Address `.githooks/pre-commit` Gitleaks failures by removing the secret, not by disabling the hook.
- Database migrations MUST follow Squawk's safe-PostgreSQL patterns (`CONCURRENTLY` for index creation, `DEFAULT` on new NOT NULL columns); CI blocks the PR otherwise.
- All audit events are tamper-evident (cryptographic hashing); DO NOT bypass `EventStore` write paths to insert events.

## Recovery

- After `/clear` or compact event, read `MASTER_PLAN.md` (or the active `MASTER_PLANx.md`) for current work.
- Continue from the first unchecked box in the active plan file.
- Read the corresponding `*_TASK_N.md` for context on completed steps.
- Verify understanding of current state before proceeding — re-verify code symbols against current code. Plan documents and the `Verified Symbols` tables they contain are point-in-time snapshots; treat them as starting hypotheses, not as current truth.
