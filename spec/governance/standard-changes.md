# Standard Changes

A **Standard Change** is a change that does not impact the validated state
of the clinical data or the system's security posture. Standard Changes
are pre-approved under the Change Management SOP and do not require a
per-change Change Control Form (see `change-control.md`).

## Qualifying Categories

A change qualifies as a Standard Change only if it falls into one of these
categories:

- **UI / UX aesthetic fixes**: correcting typos in labels, adjusting
  button colors, fixing layout alignment — provided the change does not
  hide required information.
- **Documentation-only updates**: updating help text, FAQs, or internal
  developer comments.
- **Routine infrastructure patches**: minor OS or dependency security
  patches that have passed automated regression tests in the staging
  environment.
- **Known bug fixes**: fixing a bug previously documented in a Validation
  Summary Report (VSR) as a minor deviation.
- **Config-data updates**: updating non-clinical data such as help-desk
  contact names or phone numbers.

## Pre-Approved Workflow

Standard Changes still leave a paper trail; they bypass the CCF, not
auditability.

- **Log**: each Standard Change is recorded in the **Standard Change Log**
  (a spreadsheet or issue tracker).
- **Evidence**: each entry MUST link to a Pull Request and a passing test
  result, demonstrating that no other behavior was affected.

## SOP Clause

> Changes categorized as Standard Changes (see Appendix A) do not require
> individual Change Control Board approval. These changes SHALL be
> documented in the Standard Change Log and verified through the automated
> Continuous Integration (CI) pipeline. Any change not explicitly listed
> as a Standard Change SHALL be treated as a Major Change requiring a
> formal Change Control Form (CCF).

## Safety Valve

If a Standard-Change-eligible PR touches a Critical Attribute (e.g.,
time-stamp logic, audit-trail content, authentication, or RBAC policy),
the SOP MUST require automatic escalation to a Major Change.

## CI Automation

A `type:standard-change` GitHub label can drive the CI/CD pipeline to
generate the Standard Change Log entry automatically when the PR merges,
removing manual bookkeeping.
