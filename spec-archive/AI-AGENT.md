# AI Agent Usage Note — Requirements Authoring

This repository uses a strict formal requirements system.
AI agents modifying or generating requirements MUST follow these rules.

## Canonical Sources (Read First)

Before writing or editing requirements, read:
1. `spec/requirements-spec.md` — authoritative grammar and rules
2. `spec/requirements-template.md` — required structure
3. Relevant `prd-*.md`, `dev-*.md`, or `ops-*.md` files

Do not infer rules from examples alone.

---

## Non-Negotiable Constraints

- **One-way traceability only**
  - More-specific artifacts reference more-general requirements via `Implements:`
  - Parent requirements MUST NOT reference children

- **No Acceptance Criteria**
  - All testable obligations MUST appear as labeled assertions (A–Z)
  - Tests may reference `REQ-xNNNNN` or `REQ-xNNNNN-F`

- **Assertions are the unit of verification**
  - Each assertion MUST be atomic and independently decidable
  - Assertion labels MUST be stable and never reused

- **No duplication**
  - Do not restate requirements at multiple levels
  - Parent requirements define obligations; children refine them

---

## Audience Discipline

- **PRD**: externally visible behavior and regulatory obligations only  
- **DEV**: architectural and technical commitments  
- **OPS**: runtime, deployment, and operational obligations  

Do not mix audience levels.

---

## What NOT to Do

- Do NOT introduce reverse links (parent → child)
- Do NOT add Acceptance Criteria sections
- Do NOT restate requirements in prose
- Do NOT invent new formats or headings

---

## When in Doubt

Prefer:
- fewer, clearer requirements
- compositional parents with no mechanism detail
- atomic leaf assertions over broad statements

If a rule is unclear, defer to `requirements-spec.md`.
