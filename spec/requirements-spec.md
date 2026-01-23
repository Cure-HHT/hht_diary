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
- `REQ-pXXXXX`
- `REQ-dXXXXX-G`
- `REQ-oXXXXX`

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

Addresses: {JNY-xxx-NN, ...}
```

Rules:
- `Implements` lists **only less-specific requirements**.
- Parent requirements MUST NOT reference children.
- Use `-` if the requirement has no parent.
- `Addresses` is optional; when present, it lists User Journey IDs this requirement supports.
- The `Addresses` line appears after the metadata line, before any section content.
- The `Addresses` line is NOT part of the hashed content.

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

## User Journeys (JNY)

User Journeys describe what a user wants to achieve, step by step, from their perspective. They capture the key interactions and expected outcomes for major flows.

### Purpose

User Journeys exist to:
- communicate the intended user experience,
- provide context for why requirements exist,
- help stakeholders understand the system from the user's point of view.

User Journeys are **non-normative**. They do not define obligations and are not subject to automated validation.

User Journeys SHALL NOT use normative keywords (SHALL, SHALL NOT, MUST, MUST NOT, REQUIRED).

### User Journey IDs

Each User Journey is uniquely identified by an ID of the form:

```
JNY-{Descriptor}-{number}
```

Where:
- `JNY` signals this is a User Journey (not a requirement)
- `Descriptor` is a short hyphenated term identifying the journey context (e.g., `Admin-Portal`, `Participant-Diary`, `Site-Enrollment`)
- `number` is a two-digit sequence within that descriptor

Examples:
- `JNY-Admin-Portal-01`
- `JNY-Participant-Diary-03`
- `JNY-Site-Enrollment-02`

### User Journey Structure

A User Journey SHOULD follow this structure:

```markdown
# JNY-{Descriptor}-{number}: {Title}

**Actor**: {Name} ({Role})
**Goal**: {what the user wants to achieve}
**Context**: {situational background that sets up the scenario}

## Steps

1. {User action or system response}
2. {User action or system response}
3. ...

## Expected Outcome

{What success looks like from the user's perspective}

*End* *{Title}*
```

Field guidance:
- **Actor**: Include a persona name and role in parentheses for readability (e.g., "Dr. Lisa Chen (Principal Investigator)")
- **Goal**: A single sentence describing what the user wants to achieve
- **Context**: Optional but recommended; provides situational background (e.g., "Trial sponsor's IT team has deployed the portal. Dr. Chen has been designated as the first administrator.")
- **Steps**: Numbered sequence of user actions and system responses
- **Expected Outcome**: Brief statement of success from the user's perspective
- **End marker**: Required for parsing; uses format `*End* *{Title}*` (no hash since JNYs are non-normative)

### Referencing User Journeys in Requirements

Requirements MAY reference User Journeys they address. This reference appears after the REQ header line but before the body content (outside the hashed area):

```markdown
# REQ-pXXXXX: Admin Site Management

**Level**: PRD | **Status**: Active | **Implements**: REQ-p00001

Addresses: JNY-Admin-Portal-01, JNY-Admin-Portal-02

## Assertions
...
```

The `Addresses:` line:
- is optional,
- lists one or more JNY IDs separated by commas,
- indicates which user journeys this requirement supports,
- is NOT part of the hashed content.

### Do's and Don'ts

**DO:**
- Focus on major flows and happy paths
- Write from the user's perspective using natural language
- Describe what the user sees and does
- Keep steps at a high level of abstraction
- Include the expected outcome

**DON'T:**
- Enumerate all validation rules or error cases
- Use normative keywords (SHALL, MUST, REQUIRED, etc.) — this is enforced
- Include implementation details or technical specifics
- Duplicate content that belongs in assertions
- Create journeys for every minor variation

### Relationship to Requirements

| Aspect | User Journey (JNY) | Requirement (REQ) |
| ------ | ------------------ | ----------------- |
| Purpose | Describe user experience | Define obligations |
| Language | Descriptive ("User clicks...") | Prescriptive ("System SHALL...") |
| Validation | Manual walkthrough | Automated/formal verification |
| Granularity | Major flows only | Every testable obligation |
| Normative | No | Yes |

User Journeys provide **context**; Requirements provide **contracts**.

---

## Hash Definition

Each requirement MUST end with a Footer including a content hash:

```markdown
*End* *{Title}* | **Hash**: {value}
```

The hash SHALL be calculated from:
- every line AFTER the Header line
- every line BEFORE the Footer line

