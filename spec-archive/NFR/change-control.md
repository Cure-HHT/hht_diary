# Change Control

In a 21 CFR Part 11 environment, every change to a baselined system requires
a formal Change Control record demonstrating that the system remains in a
validated state. This document defines:

- the threshold at which a Change Control Form (CCF) is required,
- the CCF template, and
- the workflow that integrates the CCF with the project's tech stack.

For pre-approved low-risk changes that do not require a CCF, see
`standard-changes.md`.

## When a CCF Is Required

The threshold is the system's lifecycle phase, not the size of the change.

### Pre-Baseline (Development)

While the system is under initial construction and has not been released for
the trial, changes are governed by the project's Software Development Life
Cycle (SDLC):

- **Documentation**: Git history, code review records, and automated test
  results.
- **Traceability**: the requirement-extraction tool builds the Traceability
  Matrix from `# Implements:` markers in commits and PRs.
- **CCF**: not required.

### Post-Baseline (Production)

Once the system has been validated and the sponsor has accepted it for the
trial, it enters a baselined state. Any change that could affect safety,
effectiveness, or data integrity now requires a CCF, and the corresponding
PR MUST reference the approved Change Control Number, e.g.:

```text
# Verifies: REQ-CAL-p00029-A; Approved per CCF-2026-001
```

## Change Categories

The Change Management SOP MUST classify each change:

- **Major / Significant Changes** require a CCF and sponsor approval.
  Examples: changing how diary entries are time-stamped, or adding a new
  user role.
- **Minor / Standard Changes** are pre-approved under a simpler process. See
  `standard-changes.md` for the qualifying list and the Standard Change Log
  workflow.

## Change Control Form Template

```text
[System Name] Change Control Form (CCF)
Control Number: CCF-YYYY-NNN  (sequential)
```

| Section | Field |
| --- | --- |
| 1. Change Request Info | Originator (name / role); Date Submitted (YYYY-MM-DD); Priority (Low / Medium / High / Emergency) |
| 2. Description of Change | Title; Reason / Rationale; Scope (code, files, infrastructure affected) |
| 3. Impact Assessment | Affected Requirements (REQ IDs); Regression Risk; Regulatory Impact (effect on 21 CFR Part 11 satisfaction) |
| 4. Implementation Plan | Development Tasks; Verification Method (e.g., automated unit tests + manual UAT); Rollback Plan |
| 5. Pre-Approval (CCB) | Approved By (sponsor / quality representative); Date |
| 6. Closure / Post-Release | Validation Report ID (link to VVR / VSR); Final Status (Completed / Cancelled) |

### Why This Structure

- **Traceability** (Section 3) prevents "dark code" that is not mapped to an
  approved requirement.
- **Rollback Plan** (Section 4) is specifically required by auditors as
  evidence of business-continuity planning.
- **Sponsor Sign-Off** (Section 5) shifts the regulatory burden of the
  change onto the sponsor, who has formally authorized it for their study
  environment.

## Tech Stack Integration

- **Git**: reference the GitHub Pull Request in the Implementation Plan.
- **Terraform**: for VPC or other infrastructure changes, attach the
  `terraform plan` output as a supporting document.
- **Audit Trail**: capture Change Type and Closure Date in the Master Change
  Log, which acts as the high-level index of every CCF.

## Workflow Summary

| Phase | Required Process | Documentation |
| --- | --- | --- |
| Initial Build | SDLC / Code Review | PRs, Unit Tests, Git History |
| First Release | Full Validation | Validation Summary Report (VSR) |
| Updates to Live System | Change Control Board (CCB) | Change Control Form (CCF), Regression Tests |

## Emergency Changes

For critical security patches, the SOP MAY allow verbal CCB approval
followed by a formal CCF within 24 hours.
