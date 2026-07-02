# Formal Requirements System

## Intent

This repository uses a formal requirements system to define, implement, and verify the platform's specification, design, implementation, and verification.

Requirements are written so they can be directly verified, traced one-way from implementation to obligation, audited without manual cross-referencing, and maintained without redundancy.

The authoritative source for this platform is the **eCOA User Requirements Specification (URS)**. The `spec/` directory is the maintained version of that document; an archived copy of v1.0 (the original Google-doc export) lives at `docs/archive/URS-v1.0.{md,pdf}`.

---

## Directory Purpose

- **spec/** — Normative obligations defining what must be true of the platform.
- **spec/INDEX.md** — Auto-generated requirements index (do not edit by hand; refreshed by `elspais fix`).
- **spec/_generated/** — Build artifacts emitted by elspais for the defined-terms feature (glossary, term index). Committed for review; do not edit by hand.
- **spec/images/** — Figures referenced by requirements (named by the requirement that owns them).
- **spec-archive/** — Snapshot of the pre-URS-v1 spec tree (legacy `REQ-{p|o|d}NNNNN` ids). Read-only reference; not scanned by elspais.
- **docs/** — Explanatory documentation, ADRs, plans, and design specs.
- **docs/archive/** — Archived authoritative artifacts (e.g. the original URS Google-doc export).

If it defines *what must be true*, it belongs in `spec/`.
If it explains *how to do something* or *why a decision was made*, it belongs in `docs/`.

---

## Levels

This repo uses four requirement levels:

- **PRD** (`DIARY-PRD-...`) — Product-level obligations: what the platform provides to its users (clinical staff, participants, sponsors).
- **GUI** (`DIARY-GUI-...`) — Presentation obligations: interface behavior, layout, interaction patterns. A GUI requirement typically `Refines` a PRD parent.
- **OPS** (`DIARY-OPS-...`) — Operational obligations: deployment, monitoring runbooks, secret rotation, and similar that operators (not sponsors) consume.
- **DEV** (`DIARY-DEV-...`) — Implementation obligations: how the platform realizes the PRD/GUI/OPS requirements.

The component name (the kebab-case slug after the level) is **stable**: once a requirement has been authored under a given name, renaming it is a breaking change to every reference in code, tests, results, and other requirements.

Naming convention: **entity-first kebab-case**. Group related requirements by their primary entity so file listings self-organize:

```text
DIARY-PRD-user-account-create
DIARY-PRD-user-account-edit
DIARY-PRD-user-account-deactivate
DIARY-GUI-user-account-tabs
```

---

## REQ → REQ relationships

Two relationship kinds, both first-class in elspais 0.115+:

- **Refines** — hierarchy / elaboration. Child REQ adds detail to parent's intent. GUI refines functional PRD. Sub-REQ refines parent. Cross-repo Refines is supported via `FederatedGraph` (sibling repos linked with `elspais associate`).
- **Satisfies** — template / registry instance. The template REQ MUST be marked with the no-value `**Template**` flag on its metadata line (e.g. `**Level**: PRD | **Status**: Active | **Template**`). When a downstream REQ declares `**Satisfies**: X`, elspais clones X's REQ subtree with composite IDs `<declarer-id>::<template-id>`, creating INSTANCE nodes connected via SATISFIES edges. Cross-cutting CODE/TEST annotations target the template assertions directly (NOT the composite ID); coverage flows automatically to every satisfier. Cross-repo Satisfies clones across the FederatedGraph when the template's repo is declared in `[associates.*]`. Use for: "this REQ instantiates the abstract pattern X" — Dialog Patterns, Action Inventory entries, Status Registry values, Common UI Element references. Templates may not have outbound `Refines:` outside their own subtree, and may not be the target of inbound `Refines:`.

`Implements:` for REQ → REQ in spec headers is deprecated; the keyword survives as a placeholder elspais inserts when no Implements ref exists. `// Implements:` is the **correct** keyword for code/test annotations targeting an assertion.

---

## File organization

A `spec/` file MAY contain:

- **One or more requirement blocks** — each is a complete `DIARY-{LEVEL}-{component}` requirement per the requirement grammar (the elspais MCP `agent_instructions()`/`docs()`; the legacy `requirements-spec.md` grammar doc is archived under `spec-archive/`). elspais detects a requirement block by the `DIARY-{LEVEL}-{component}` pattern in the heading text, not by heading depth.
- **Remainder sections** — any heading not matching the REQ pattern is non-normative prose: cross-system narrative, architecture orientation, decisions-rejected commentary, reading-order guidance.
- **Mermaid diagrams** — render in any markdown-aware tool; treated as remainder content.
- **Image links** — for renderers that display them inline.

Conventions:

- One file per design topic. `spec/prd-<topic>.md` for PRDs only, `spec/gui-<topic>.md` for GUIs only, `spec/<topic>.md` if it mixes levels.
- Multi-requirement files: `#` is file title; `##` are chapters (some are requirement blocks `## DIARY-PRD-...`, others are remainder sections `## Overview`); `###` are subsections.
- A multi-REQ topic file SHOULD include orienting remainder sections.
- **Filename = section heading**: the file's `#` title is the section heading that appears in the compiled URS-style PDF. Section structure is derivable from the filename + `#` title; no separate "section heading" convention is enforced. Where a section title and a REQ title coincide verbatim, that is acceptable (one is a chapter, the other a requirement inside it).
- **PDF compile interleaving**: when the compiled URS PDF is regenerated, REQ blocks across files are interleaved by the URS-aligned ordinal of the REQ ID stripped of its namespace and level prefix (e.g. `DIARY-PRD-action-inventory` sorts as `action-inventory`; a sponsor REQ such as `SPONSOR-PRD-role-definitions` sorts as `role-definitions`). This produces a single document ordered by topic kebab regardless of repo or audience tier, mirroring URS reading order. Implementation lives in the Phase-5 pdf template.

### "Only option in code today" follow-up

Several REQs (particularly sponsor-overlay REQs with no platform-side parent and many `GUI-*` REQs) currently encode the only option implemented in code. There is no configurable seam — but there should be, because future sponsors may need different rules. Author these REQs with an explicit subsection flagging the gap:

```markdown
> **Follow-up — configurability**: This requirement currently encodes
> the only option implemented in code. Future sponsors may require
> different rules; introduce a configurable seam (e.g. a parameter on
> the sponsor-overlay parent, or a new platform-side template the
> sponsor-overlay REQ Satisfies) when the need arises. Until that seam
> exists, this REQ is normative for the current deployment.
```

Capture each addition in the commit message so reviewers can audit the set.

---

## Cross-repo references

Sibling repos in the Cure-HHT org:

| Repo | Namespace | Example |
| ---- | --------- | ------- |
| `hht_diary` (this repo) | `DIARY-{PRD\|GUI\|OPS\|DEV}-{kebab}` | `DIARY-PRD-action-inventory` |
| the sponsor overlay repo | sponsor-specific namespace (e.g. `SPONSOR-{PRD\|GUI\|OPS\|DEV}-{kebab}`) | — |
| `hht_admin` | `HHT-{PRD\|OPS\|DEV}-{kebab}` | `HHT-OPS-storage-rules` |
| `event_sourcing` | `EVS-{PRD\|OPS\|DEV}-{kebab}` | `EVS-DEV-provenance-entry-schema` |

When citing a foreign-repo REQ, use the foreign repo's convention. Link sibling repos via `elspais associate <path>`.

### Where operational (OPS) requirements live: public-CI / private-CD routing

Operational requirements are routed to a repo by **what they govern and whether that thing is sponsor-confidential**, not by the OPS letter alone. Three homes:

- **Public CI** — validation of already-public core source and workflows (change detection, traceability, secret/vulnerability scanning, static analysis, testing, branch protection, cross-repo cascading validation). Authored here in `hht_diary` (`spec/ops-ci-validation.md`). Publishing how the core is validated exposes nothing secret and is a positive for an auditor.
- **Private CD** — sponsor deployment governance (environment promotion gates dev/qa/uat/prod, sponsor sign-off, release archive, rollback, image promotion). Authored in the private sponsor-infrastructure repo as a per-sponsor **template**, copied into each sponsor repo at creation and thereafter sponsor-owned (sponsors may tailor their own deployment obligations). Not authored here.
- **Organization infrastructure** — cross-repo identity (the GitHub App issuing short-lived installation tokens; no standing PATs), the shared composite-action / reusable-workflow library, and the five-repo trust topology. Authored as `HHT-OPS-*` in `hht_admin`.

**Governing principle — public describes *how*, never *which*.** Public spec and code describe how *Sponsors* relate to the platform — the mechanisms, concepts, and contracts — and contain **zero** *Sponsor* instances. Every *Sponsor* instance (codename, *Linking Code* prefix, *Sponsor Portal* hostname, routing key) lives in private config or Doppler behind the neutral discovery service, resolved at runtime. A requirement that would have to name or enumerate *Sponsors* belongs in a private repo.

### Federation convention (asymmetric `.elspais.local.toml`)

**Only the sponsor overlay repo declares `.elspais.local.toml` (pointing at hht_diary).** hht_diary does NOT declare a sponsor associate. The reverse — both sides declaring each other — produces an elspais "Associate X declares its own associates" error because of the nested-associates restriction.

Practical effects:

- `elspais` run from the **sponsor** worktree sees both repos' REQs (federation works; cross-repo Refines/Satisfies resolve cleanly).
- `elspais` run from the **hht_diary** worktree sees only hht_diary REQs. Cross-repo refs from `DIARY-*` to the sponsor's REQs appear as "presumed cross-repo" and are suppressed by `[validation].allow_unresolved_cross_repo = true` in `.elspais.toml`.
- The URS compile pipeline lives in [`Cure-HHT/hht_workflows`](https://github.com/Cure-HHT/hht_workflows) (`scripts/urs-compile/`) and is run from the **sponsor** worktree as `PRIMARY_ROOT`, with this hht_diary worktree as `ASSOCIATE_ROOT`. The script uses the federated `elspais graph` so cross-repo refs resolve cleanly during PDF assembly.
<!-- CUR-1557 test (a): spec-only change; expect matrix_only: 0 tests run, matrix regenerated from baseline. -->
