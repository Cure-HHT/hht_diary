<!-- markdownlint-disable MD050 -->
<!-- This file deliberately uses __term__ (Reference-Document terms) alongside
     **term** (System-Glossary terms); see the example block referencing
     __TLA__ for the convention. -->

# Requirement Style Guide

This document formalizes the authoring rules for requirements in this project.
It complements the Formal Requirements Specification (`requirements-spec.md`)
by adding style, formatting, and governance obligations that ensure every
requirement is testable, unambiguous, and auditable for Trial Master File (TMF)
compliance.

---

# REQ-CAL-o00001: EARS Syntax for Conditional Requirements

**Level**: ops | **Status**: Draft | **Implements**: -

## Rationale

The **Easy Approach to Requirements Syntax** (**EARS**) eliminates ambiguity in
trigger-based requirements by forcing the author to classify the condition type
before stating the obligation. The EARS patterns also enforce active voice by
requiring an explicit subject ("the System"), which prevents passive
constructions that obscure responsibility. Requirements should use imperative
or future tense ("SHALL log"), not present tense ("logs") or past tense
("logged").

The five EARS patterns are:

| Pattern Type      | Mandatory Keyword | Syntax Template                                                      |
|-------------------|-------------------|----------------------------------------------------------------------|
| Ubiquitous        | (None)            | The System SHALL [response].                                         |
| Event-Driven      | When              | When [trigger], the System SHALL [response].                         |
| State-Driven      | While             | While [state], the System SHALL [response].                          |
| Unwanted Behavior | If / Then         | If [unwanted event], then the System SHALL [response].               |
| Optional Feature  | Where             | Where [optional feature], the System SHALL [response].               |

### Examples

**Ubiquitous**: "The System SHALL encrypt all Electronic Records using AES-256
at rest."

**Event-Driven**: "When an Admin submits the *User Account* form, the System SHALL
validate the uniqueness of the *Email Address*."

**State-Driven**: "While the System is in Maintenance Mode, the System SHALL
prohibit all Subject data entry."

**Unwanted Behavior**: "If a User enters an incorrect password three consecutive
times, then the System SHALL lock the *User Account* for 30 minutes."

**Optional Feature**: "Where the Mobile App has access to biometric hardware, the
System SHALL allow 2FA completion via fingerprint or facial recognition."

### Combining Triggers

For high-security clinical functions, you may need to combine these triggers.

**State + Event**: "While in a User Session, when the Admin modifies a Role, the
System SHALL require a secondary Electronic Signature to commit the change."

## Assertions

A. Assertions SHALL use prescriptive language ("The System SHALL ..."), not
   descriptive language ("The system does ..." or "The system has ...").

*End* *EARS Syntax for Conditional Requirements* | **Hash**: f7a386c0

---

# REQ-CAL-o00002: Glossary Term Enforcement

**Level**: ops | **Status**: Draft | **Implements**: -

## Rationale

Consistent terminology prevents misinterpretation across authors. Bolding and
glossary cross-referencing make implicit assumptions explicit and auditable.

## Assertions

A. Every domain-specific term used in an assertion SHALL match a definition in
   the System Glossary.

B. Automated health checks SHALL flag any unbolded domain-specific term that
   appears in the System Glossary.

*End* *Glossary Term Enforcement* | **Hash**: 6f3e4518

---

# REQ-CAL-o00003: Assertion Independence

**Level**: ops | **Status**: Draft | **Implements**: -

## Compound Assertions

Compound assertions produce ambiguous test results: one action may pass while
another fails, yet the assertion as a whole cannot be decisively marked pass or
fail. When a compound assertion is found, the author splits it into separate
labeled assertions.

A list of items governed by a single predicate (e.g., "SHALL NOT contain X, Y,
or Z") is not a compound assertion — it expresses one obligation applied to
multiple values, testable under a single pass/fail criterion.

## Self-Containment

An assertion that references another assertion, requirement, or validation ID
cannot be evaluated in isolation — the reviewer must chase the reference to
determine whether the obligation is met. This couples assertions into chains
that are fragile under change and difficult to trace in a validation protocol.
Each assertion should be independently decidable from its own text.

## Assertions

A. An assertion SHALL NOT reference other assertions, requirements, or
   system-validation identifiers.

B. An assertion SHALL NOT use conjunctions to introduce a second independently
   testable action.

C. An assertion SHALL NOT use semicolons to introduce a second independently
   testable action.

D. An assertion SHALL NOT use phrases such as "as well as" to introduce a
   second independently testable action.

E. An assertion SHALL NOT use phrases such as "in addition to" to introduce a
   second independently testable action.

*End* *Assertion Independence* | **Hash**: 96c3a3c6

---

# REQ-CAL-o00004: Assertion Clarity

**Level**: ops | **Status**: Draft | **Implements**: -

## Ambiguous Adjectives

Ambiguous adjectives cannot produce a clear pass/fail result. Auditors require
that every requirement be verifiable with an objective criterion. Terms such as
"fast," "secure," "user-friendly," "intuitive," "efficient," "reliable,"
"superior," and "robust" are inherently subjective and should be replaced with
measurable thresholds (e.g., "responds within 200 ms" instead of "fast").

## Separation of Obligation from Implementation

Embedding implementation details in product requirements couples the
specification to a particular technology stack and makes the requirement
non-portable. Implementation belongs at the DEV level.

## Assertions

A. Every quantifiable property referenced in an assertion SHALL be accompanied
   by a measurable threshold or verifiable criterion.

B. PRD-level assertions SHALL NOT reference programming languages, libraries,
   frameworks, database schemas, or API signatures.

C. The keywords MUST, MUST NOT, and MAY SHALL NOT appear in requirements.

D. The SHALL keyword SHALL NOT appear outside the Assertions section of a
   requirement, except within quoted examples that illustrate syntax patterns.

*End* *Assertion Clarity* | **Hash**: e78d595e

---

# REQ-CAL-o00005: Notation and Formatting

**Level**: ops | **Status**: Draft | **Implements**: -

## Date and Time Notation

Consistent notation prevents misinterpretation of dates, times, and
measurements across international teams and automated tooling.

## Acronym Usage

Unexpanded acronyms create barriers for reviewers and auditors unfamiliar with
project-specific terminology.

### Example

The following entry defines an acronym in the System Glossary; later
requirement text may then reference the acronym as `__TLA__`:

Three Letter Acronym (TLA)
: This is an example of the syntax for defining a term whose label can be
  used as an acronym in subsequent requirement text.

## Variable Placeholders

A consistent placeholder syntax prevents confusion between configuration
variables and literal values during implementation and review. As a consequence
of assertion D, bare variable names that could be confused with static text
will not appear in requirement text.

## Assertions

A. All dates within requirements SHALL be expressed in ISO 8601 format
   (YYYY-MM-DD).

B. All times within requirements SHALL be expressed in ISO 8601 format with
   timezone offset (HH:MM:SSZ or HH:MM:SS+HH:MM).

C. Any acronym used within a requirements document SHALL be a **defined term**.

D. Variables or configurable values within requirement text SHALL be enclosed in
   double curly braces (e.g., `{{max_inactivity}}`).

*End* *Notation and Formatting* | **Hash**: 06b668d4
