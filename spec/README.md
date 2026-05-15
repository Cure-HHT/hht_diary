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
- **OPS** (`DIARY-OPS-...`) — Operational obligations: deployment, monitoring, secret rotation, and similar.
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
- **Satisfies** — template / registry instance. When a REQ declares `Satisfies: X`, elspais clones X's REQ subtree with composite IDs, creating INSTANCE nodes connected via SATISFIES edges. Use for: "this REQ instantiates the abstract pattern X" — Dialog Patterns, Action Inventory entries, Status Registry values, Common UI Element references.

`Implements:` for REQ → REQ in spec headers is deprecated; the keyword survives as a placeholder elspais inserts when no Implements ref exists. `// Implements:` is the **correct** keyword for code/test annotations targeting an assertion.

---

## File organization

A `spec/` file MAY contain:

- **One or more requirement blocks** — each is a complete `DIARY-{LEVEL}-{component}` requirement per the grammar in `requirements-spec.md`. elspais detects a requirement block by the `DIARY-{LEVEL}-{component}` pattern in the heading text, not by heading depth.
- **Remainder sections** — any heading not matching the REQ pattern is non-normative prose: cross-system narrative, architecture orientation, decisions-rejected commentary, reading-order guidance.
- **Mermaid diagrams** — render in any markdown-aware tool; treated as remainder content.
- **Image links** — for renderers that display them inline.

Conventions:

- One file per design topic. `spec/prd-<topic>.md` for PRDs only, `spec/gui-<topic>.md` for GUIs only, `spec/<topic>.md` if it mixes levels.
- Multi-requirement files: `#` is file title; `##` are chapters (some are requirement blocks `## DIARY-PRD-...`, others are remainder sections `## Overview`); `###` are subsections.
- A multi-REQ topic file SHOULD include orienting remainder sections.

---

## Cross-repo references

Sibling repos in the Cure-HHT org:

| Repo | Namespace | Example |
| ---- | --------- | ------- |
| `hht_diary` (this repo) | `DIARY-{PRD\|GUI\|OPS\|DEV}-{kebab}` | `DIARY-PRD-action-inventory` |
| `hht_diary_callisto` | `CAL-{PRD\|GUI\|OPS\|DEV}-{kebab}` | `CAL-PRD-permissions-table` |
| `hht_admin` | `HHT-{PRD\|OPS\|DEV}-{kebab}` | `HHT-OPS-storage-rules` |
| `event_sourcing` | `EVS-{PRD\|OPS\|DEV}-{kebab}` | `EVS-DEV-provenance-entry-schema` |

When citing a foreign-repo REQ, use the foreign repo's convention. Link sibling repos via `elspais associate <path>`.
