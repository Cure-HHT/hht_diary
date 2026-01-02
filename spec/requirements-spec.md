# Formal Requirements Specification

## Purpose

This document defines the **canonical grammar, structure, and authoring rules** for all formal requirements in the `spec/` directory.

It is the **single source of truth** for how requirements are written, identified, hashed, decomposed, and referenced. Both humans and automated agents MUST follow this specification.

This document intentionally avoids workflow, tooling, or process guidance. Those belong in tooling or developer documentation.

---

## Normative Model

- Requirements define **obligations**, not descriptions.
- Obligations are stated using **SHALL** or **SHALL NOT**.
- Each obligation appears **exactly once** in the repository.
- Traceability is **one-way only**: more specific requirements reference more generic requirements via `Implements:` metadata.

---

## Requirement Identity

### Requirement IDs

Each requirement is uniquely identified by an ID of the form:

```
REQ-{prefix}{number}[-{assertion}]
```

Where:
- `prefix` indicates audience:
  - `p` = PRD = Product Requirements Documention
  - `d` = DEV = Development Specification
  - `o` = OPS = Operations Documentation
- `number` is a zero-padded integer
- `assertion` is an optional single letter label [A-Z] for an Assertion

Examples:
- `REQ-p00044`
- `REQ-d00123-G`
- `REQ-o00007`

### Sponsor-Scoped Requirements

Sponsor-specific requirements MAY include a sponsor prefix in the numeric
portion of the ID, as defined by repository conventions.

Example:
- `TTN-REQ-p00001-F`.

---

## Requirement Header Grammar

Each requirement MUST begin with a header in the following exact form:

```markdown
# REQ-{id}: {Short Descriptive Title}

**Level**: {PRD | Dev | Ops} | **Status**: {Draft | Review | Active | Deprecated} | **Implements**: {REQ-xNNNNN, REQ-yNNNNN | -} 
```

Rules:
- `Implements` lists **only less-specific requirements**.
- Parent requirements MUST NOT reference children.
- Use `-` if the requirement has no parent.

---

## Assertions (Normative Content)

### Assertion Block

All testable obligations MUST appear in an `## Assertions` section.

```markdown
## Assertions

A. The system SHALL ...
B. The system SHALL ...
```

### Assertion Rules

- Each assertion MUST:
  - use SHALL,
  - express exactly one obligation,
  - be independently decidable as true or false.
- Assertion labels:
  - MUST be uppercase letters A–Z,
  - MUST be unique within the requirement,
  - MUST remain stable over time,
  - MUST NOT be reused once removed (**IMPORTANT**)
- If more than 26 assertions are required, the requirement MUST be split.

### Assertion References

Tests and other verification artifacts MAY reference:
- the entire requirement: `REQ-d00032`, or
- a specific assertion: `REQ-d00032-F`.

## Rationale Block (Optional, Non-Normative)

A requirement MAY include a `Rationale`, `Description`, `Discussion` or other non-normative blocks. 
These are for context only and are NOT part of the testable requirements.
Rationale blocks MAY exist before and after the Assertion block.
Any section not titled "Assertions" SHALL be treated as a Rationale block. 

```markdown
## {Rationale Block Type}
<explanation>
```

Rules:
- Rationale MUST NOT introduce new obligations.
- Rationale MUST NOT restate assertions.
- Rationale MUST NOT use SHALL or MUST language.

---

## Acceptance Criteria

Acceptance Criteria SHALL NOT be used.

Requirements MUST be written such that the assertions themselves constitute the acceptance conditions.

---

## Compositional Requirements

A compositional requirement defines a **normative obligation boundary** that is satisfied through the combined effect of multiple lower-level requirements.

Compositional requirements:
- state a single obligation,
- do not enumerate behaviors,
- do not reference contributing requirements,
- rely on downstream `Implements:` declarations for composition.

Composition is inferred, never declared.

---

## Decomposition Rules

### Refinement

A child requirement refines a parent when it:
- adds specificity,
- adds constraints,
- commits to mechanisms or guarantees.

The child MUST implement the parent via `Implements:`.

### Cascade

Multiple requirements MAY exist at the same Level refining a shared higher-level obligation. This is valid and expected.

---

## Leaf Requirements

A requirement is a leaf when:
- all obligations are fully expressed as labeled assertions, and
- further decomposition would only restate the same obligations or turn them
  into tests.

Leaf requirements are the attachment points for implementation and verification.

---

## Prescriptive Language Requirement

Requirements MUST be prescriptive, not descriptive.

Allowed:
- "The system SHALL ..."

Forbidden:
- "The system does ..."
- "The system has ..."

Requirements define what must be true, not what currently exists.

---

## When a Section Needs a Requirement ID

A section requires a `REQ-` ID if and only if it introduces at least one
normative obligation.

Explanatory, contextual, or illustrative sections MUST NOT have requirement IDs.

---

## Document Structure Rules

- Requirement documents SHOULD use a flat heading structure.
- `REQ-` blocks SHOULD be a top-level section.
- Subheadings within a requirement are limited to:
  - Assertions
  - Rationale

---

## Hash Definition

Each requirement MUST end with a Footer including a content hash:

```markdown
*End* *{Title}* | **Hash**: {value}
```

The hash SHALL be calculated from:
- every line AFTER the Header line
- every line BEFORE the Footer line

