# Software Validation Plan (SVP)

The SVP is the foundational document that defines what is being validated,
how it will be validated, and what evidence will be produced. Auditors
review the SVP first when investigating a discrepancy; failure to follow
the SVP is among the most-cited findings in FDA Warning Letters.

## Core Components

### Scope

Defines exactly what is being validated (e.g., the mobile diary
application, the cloud portal, and the EDC sync interface) and, equally
importantly, what is **not** in scope.

### Validation Strategy

Describes the chosen approach (e.g., GAMP 5 risk-based validation),
including:

- the requirement-extraction tooling used to maintain traceability, and
- the order of precedence for definitions (see `glossary-precedence.md`).

### Roles & Responsibilities

A Delegation of Authority (DoA) matrix defining who writes the tests, who
executes them, and who has final approval authority.

### Acceptance Criteria

The definition of done. States the threshold for critical-requirement pass
rates and how minor defects are documented as allowable deviations.

### Deliverables

A checklist of the documents the validation effort will produce
(e.g., Risk Assessment, Traceability Matrix, Validation Summary Report).
See `validation-package.md` for the full package outline.

## Why the SVP Is the Foundation

- **Risk-Based Effort**: the FDA encourages a risk-based approach. The SVP
  justifies why, for example, fifty tests cover audit-trail behavior
  (high risk) while only five cover the help menu (low risk).
- **Audit Defense**: auditors first compare findings against the SVP.
  Following the SVP is itself evidence of a controlled process.
- **Standardization**: a single SVP ensures every team uses the same
  Requirement Style Guide (`style-guide.md`) and test-protocol format
  across the project.
