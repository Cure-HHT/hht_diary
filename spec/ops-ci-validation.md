# Continuous-Integration Validation

This file specifies the **pull-request and merge-time** continuous-integration (CI)
obligations enforced in the public core repository. These are the checks that run on
every change to shared platform code before it may merge to a protected branch: change
detection, traceability and compliance enforcement, secret and vulnerability scanning,
static analysis, automated testing, branch protection, and cross-repo validation.

These requirements govern **validation of already-public source and workflows**, so they
are authored in the public core repository. The complementary **promotion / continuous-
delivery (CD)** obligations — environment promotion gates, *Sponsor* sign-off, release
archive, and rollback — govern *Sponsor* deployments and live in the private *Sponsor*
infrastructure spec as a per-sponsor template; they are not duplicated here. A gate such
as "the security scan must pass before promotion to UAT" consumes the scan defined here
(`DIARY-OPS-security-scanning`) but the gate itself is a CD obligation authored privately.

See `spec/README.md` ("Cross-repo references") for the public-CI / private-CD routing
principle, and the "Start here" five-repo orientation doc for the full topology.

---

## DIARY-OPS-change-appropriate-ci: Change-Appropriate CI Validation

**Level**: OPS | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-system-validation-traceability

### Assertions

A. The CI pipeline SHALL detect which areas of the codebase changed — specification, application code, *Database*, tooling, and workflow definitions — before executing validation jobs.

B. The CI pipeline SHALL execute only the validation jobs relevant to the detected change areas, to avoid unnecessary computation.

C. The CI pipeline SHALL always execute secret and vulnerability scanning regardless of which areas changed.

D. The CI pipeline SHALL execute the full set of validation jobs when a workflow definition file is among the changes.

E. The CI pipeline SHALL produce a single consolidated pass/fail summary aggregating every executed validation job, and a merge to a protected branch SHALL be permitted only when that summary is passing.

### Rationale

CI must balance thoroughness against cost: running every check on every change wastes compute and developer time, while skipping relevant checks lets defects through. Change-appropriate validation selects jobs by detected change area, with two safety exceptions — security scanning always runs (a defect there is never acceptable), and a workflow-definition change forces the full set (the change may alter the gate itself). A single consolidated summary gives a clear, auditable merge decision rather than requiring a reviewer to interpret many independent check states.

*End* *Change-Appropriate CI Validation* | **Hash**: 088fec3f

---

## DIARY-OPS-pr-compliance-checks: Pull-Request Compliance Checks

**Level**: OPS | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-system-validation-traceability

### Assertions

A. The CI pipeline SHALL validate that every pull-request title carries a Linear ticket reference of the form `[CUR-NNNN]`, since the squash-merge commit subject on a protected branch is taken verbatim from the title.

B. The CI pipeline SHALL validate on every push to a pull request, including the initial push, that the required traceability references are present, so that defects are surfaced while they are still cheap to fix.

C. The CI pipeline SHALL validate that changed production and test units carry the expected `Implements:` or `Verifies:` annotations and that each cited requirement identifier resolves in the requirements graph.

D. The CI pipeline SHALL validate that specification files follow the audience-prefix naming convention (`prd-`, `gui-`, `ops-`, `dev-`).

E. The CI pipeline SHALL post its compliance result as a required status check that blocks merge to a protected branch when validation fails.

F. The CI pipeline SHALL open a compliance ticket when a commit reaching a protected branch is found to be missing required references, as a detective control for changes that bypass the merge-time gate.

### Rationale

Squash-merge workflows promote the pull-request title to the permanent commit subject, so traceability references must be validated on the title, not just on individual commits. Validating on every push — not only at PR creation — gives early feedback while references are still editable. Citing requirement identifiers that resolve in the graph keeps the implementation-to-obligation mapping intact. The post-merge detective control (F) catches anything that reaches a protected branch through an administrative override, preserving the *Audit Trail* even when the preventive gate is bypassed.

*End* *Pull-Request Compliance Checks* | **Hash**: f941e940

---

## DIARY-OPS-security-scanning: Secret and Vulnerability Scanning

**Level**: OPS | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-system-validation-traceability

### Assertions

A. The CI pipeline SHALL scan for committed secrets on every push to a pull request, including the initial push, examining the repository at its current state.

B. The CI pipeline SHALL scan project dependencies for known vulnerabilities.

C. The CI pipeline SHALL scan infrastructure-as-code definitions — container, Terraform, and Kubernetes configurations — for misconfigurations.

D. The CI pipeline SHALL upload vulnerability and misconfiguration findings to the repository's code-scanning surface for tracking and remediation.

E. A detected secret SHALL block merge to a protected branch.

### Rationale

A committed secret or a vulnerable dependency is an immediate risk to a platform handling data, so scanning runs at multiple layers — git state for secrets, dependency manifests for known vulnerabilities, and infrastructure definitions for misconfigurations. Secret detection blocks merge because an exposed credential demands immediate remediation; vulnerability and misconfiguration findings feed the code-scanning surface for tracked, prioritized follow-up rather than blocking every change. The scan results produced here are the evidence that the private promotion gates re-verify before advancing an artifact to UAT or production, so the same scan serves both the merge gate and the later promotion gates.

*End* *Secret and Vulnerability Scanning* | **Hash**: 6a9c6588

---

## DIARY-OPS-code-quality-gate: Code Quality and Static Analysis

**Level**: OPS | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-system-validation-traceability

### Assertions

A. The CI pipeline SHALL run static analysis on all changed Dart and Flutter code.

B. The CI pipeline SHALL validate formatting compliance on changed code.

C. The CI pipeline SHALL lint changed database-migration files for dangerous patterns, including table locks, missing indexes, and unsafe schema alterations.

D. A static-analysis failure SHALL block merge to a protected branch.

E. A formatting violation SHALL block merge to a protected branch.

### Rationale

Static analysis and formatting enforcement catch defects before review and testing, where they are cheapest to fix: analysis detects type errors, null-safety violations, and deprecated-API usage, and formatting enforcement keeps style consistent across contributors. Migration linting prevents schema operations — table locks, missing indexes, unsafe alterations — that could cause production downtime. Blocking merge on analysis and formatting failures keeps the protected branch at a known quality floor.

*End* *Code Quality and Static Analysis* | **Hash**: 5c760687

---

## DIARY-OPS-automated-test-execution: Automated Test Execution

**Level**: OPS | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-system-validation-traceability

### Assertions

A. The CI pipeline SHALL run unit tests for the packages affected by the changes in a pull request.

B. The CI pipeline SHALL run integration tests when any component they depend on has changed, including shared configuration and *Database* schema.

C. The CI pipeline SHALL measure and report test coverage for every executed test suite.

D. The CI pipeline SHALL upload coverage reports as retained artifacts.

E. The CI pipeline SHALL enforce a minimum coverage threshold for any component that defines one.

F. A unit-test or integration-test failure SHALL block merge to a protected branch.

### Rationale

Automated testing gives confidence that a change introduces no regression. Unit tests scoped to changed packages give fast feedback on isolated functionality; integration tests must run more broadly because they depend on shared infrastructure — *Database* schema, configuration, service contracts — where a change in one component can break another. Coverage measurement with a per-component threshold keeps test quality in step with codebase growth, and retained coverage artifacts provide the test evidence an audit expects.

*End* *Automated Test Execution* | **Hash**: a12471d2

---

## DIARY-OPS-traceability-validation: Traceability Validation and Matrix Generation

**Level**: OPS | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-system-validation-traceability

### Assertions

A. The CI pipeline SHALL validate requirement format, hierarchy, content-hash currency, and broken references on every pull request that changes specification files.

B. The CI pipeline SHALL generate a traceability matrix relating requirements to their implementing and verifying units.

C. The CI pipeline SHALL post the traceability result as a comment on the associated pull request.

D. The CI pipeline SHALL upload the generated traceability matrix as a retained artifact, with artifact metadata recording the commit identifier and the run timestamp.

### Rationale

Automated traceability validation enforces the requirement-to-implementation mapping at merge time, supporting compliance and audit readiness. Validating format, hierarchy, hash currency, and references keeps the requirements graph internally consistent; generating and retaining the matrix produces a contemporaneous, attributable record (commit identifier plus timestamp) that links build artifacts to the requirements they satisfy. This is the merge-time traceability check; the per-environment traceability **gate** that must pass before UAT and production promotion is a continuous-delivery obligation authored in the private sponsor-deployment template and consumes the matrix produced here.

*End* *Traceability Validation and Matrix Generation* | **Hash**: 31ff8627

---

## DIARY-OPS-branch-protection: Branch Protection Enforcement

**Level**: OPS | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-system-validation-traceability

### Assertions

A. The system SHALL block direct commits to a protected branch.

B. The system SHALL require pull-request approval before merging to a protected branch.

C. The system SHALL require all designated status checks to pass before merging to a protected branch.

D. The designated status checks SHALL include requirement validation.

E. An administrative override of branch protection SHALL produce an *Audit Trail* entry.

### Rationale

Branch protection ensures every change to a protected branch passes peer review and automated validation before integration, preventing accidental or intentional bypass of the CI gate. Requiring requirement validation among the status checks ties the protection rule to traceability enforcement. An emergency override capability is retained for incident response, but every override is recorded in the *Audit Trail* so that even bypasses remain attributable and reviewable, consistent with tamper-evident change control.

*End* *Branch Protection Enforcement* | **Hash**: d3c5b956

---

## DIARY-OPS-cross-repo-cascading-ci: Cross-Repository Cascading Validation

**Level**: OPS | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-system-validation-traceability

### Assertions

A. When core platform code changes, the CI pipeline SHALL trigger validation in each associated *Sponsor* repository against the changed core, using a short-lived cross-repository credential rather than a standing personal access token.

B. When *Sponsor* code changes, the CI pipeline SHALL trigger combined requirement validation in the core repository over the core specification together with the originating *Sponsor*'s specification.

C. The CI pipeline SHALL report the result of a cross-repository validation back as a status check on the pull request that originated it, so that a contributor sees every result on one pull request.

D. The CI pipeline SHALL block merge of a core change when an associated *Sponsor* validation triggered by that change fails.

### Rationale

The platform is a public core consumed by private per-*Sponsor* repositories, so a change in either must be validated against the other before it can merge. A core change cascades to each *Sponsor* to confirm the *Sponsor* still builds and validates against the new core; a *Sponsor* change cascades to the core to run combined requirement validation across both specifications. Reporting every result back onto the originating pull request means a contributor never has to manually chase cross-repository status. Triggering uses a short-lived, scoped cross-repository credential — the org-level identity mechanism is specified in the private organization-infrastructure spec — so no standing personal access token is required. This requirement describes the cascade **mechanism** generically; it names no *Sponsor* instance, consistent with the principle that the public repository describes how *Sponsors* relate to the platform, never which *Sponsors* exist.

*End* *Cross-Repository Cascading Validation* | **Hash**: 3c81277d

---

## Reading order and related specifications

- **Public CI (this file)** — merge-time validation of the public core repository.
- **Private CD** — environment promotion gates (dev / qa / uat / prod), *Sponsor* sign-off,
  release archive, and rollback. Authored as a per-*Sponsor* template in the private
  sponsor-infrastructure repository and copied into each *Sponsor* repository at creation;
  each *Sponsor* may thereafter tailor its own deployment obligations.
- **Organization infrastructure** — the cross-repository identity mechanism (a GitHub App
  issuing short-lived installation tokens, no standing personal access tokens), the shared
  composite-action / reusable-workflow library, and the five-repo trust topology. Authored
  as `HHT-OPS-*` requirements in the private organization-administration repository.
