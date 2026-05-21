# Generic Risk Register

The five generic risks below apply to every clinical-software vendor under
21 CFR Part 11. Each entry lists the hazard, the standard mitigation, and
the validation trace.

## R1. Unauthorized Data Access or PHI Exposure

- **Description**: an unauthorized individual (internal or external) gains
  access to Protected Health Information (PHI) or blinded study data.
- **Mitigation**: Multi-Factor Authentication (MFA) and Role-Based Access
  Control (RBAC) enforcing minimum-necessary access for every user.
- **Validation Trace**: REQ-CAL-p00029-A, REQ-CAL-p00029-E.

## R2. Loss of Data Integrity (ALCOA+ Violations)

- **Description**: Electronic Records are modified, deleted, or corrupted
  without a traceable record of the change, rendering the trial data
  legally indefensible.
- **Mitigation**: a computer-generated, time-stamped audit trail capturing
  the who, what, when, and why of every data modification.
- **Validation Trace**: REQ-CAL-p00029-J.

## R3. System Downtime & Service Disruption

- **Description**: a critical system failure (e.g., GCP region outage)
  prevents patients from entering diary data or investigators from
  reviewing safety triggers.
- **Mitigation**: high-availability architecture (multi-region VPC) and a
  formally tested Disaster Recovery (DR) plan with explicit Recovery Time
  Objectives (RTO).
- **Validation Trace**: verified via the Infrastructure SOP and the DR Test
  Report.

## R4. Non-Compliance with Predicate Rules (21 CFR Part 11)

- **Description**: the software lacks technical controls required by the
  FDA, such as unique user identification or password aging.
- **Mitigation**: hard-coded unique-email constraints, prevention of User
  ID reuse, and enforced password rotation.
- **Validation Trace**: REQ-CAL-p00029-F, REQ-CAL-p00029-H.

## R5. Undocumented Software Changes (Scope Creep)

- **Description**: a developer pushes a hotfix or feature update that was
  not formally reviewed, validated, or approved by the sponsor.
- **Mitigation**: a formal Change Control SOP and an automated Traceability
  Matrix that proves every line of code maps to an approved requirement.
- **Validation Trace**: verified via the SDLC SOP (`SDLC-SOP.md`) and the
  Change Control Logs (`change-control.md`).

## Reference Frameworks

When presenting these risks to a sponsor, cite NIST SP 800-30 or
ISO/IEC 27005 to demonstrate that risk management follows a recognized
standardized process.
