# SDLC and Governance SOP Inventory

This document lists the Standard Operating Procedures every clinical
software vendor MUST maintain to demonstrate controlled development under
21 CFR Part 11.

## 1. Software Development Life Cycle (SDLC) SOPs

The most critical category for an auditor: these prove the *how* and *why*
of the code.

- **SDLC Management**: how software is planned, developed, and released
  (e.g., the Agile / Scrum process mapped to GAMP 5).
- **Requirements Management**: how requirements are captured and hashed
  (e.g., the `REQ-CAL-p00029` family).
- **Code Review & Commit**: the peer-review process that ensures only
  validated code reaches production.
- **Configuration Management**: how Terraform, Git, and Doppler are used
  to control and track environment changes.
- **System Validation**: how OQ / PQ testing is performed and how the
  Traceability Matrix is generated.

## 2. IT Infrastructure & Security SOPs

These prove the GCP environment is secure and patient data is protected.

- **User Access Control**: how team members (developers and admins) get
  access to the backend and how periodic access reviews are performed.
- **Data Backup & Recovery**: the automated backup schedule and proof of
  a tested data restoration.
- **Disaster Recovery (DR)**: the runbook for a GCP regional outage.
- **Encryption & Key Management**: how data is protected at rest and in
  transit.

## 3. Quality & Compliance SOPs

The corporate procedures that define the vendor's quality posture.

- **Document Control**: how SOPs and PRDs are version-controlled (the
  meta-process).
- **Training & Qualification**: proof that every developer has been
  trained on the SDLC and on 21 CFR Part 11.
- **Incident & Bug Management**: how bugs are tracked, categorized
  (Critical / Major / Minor), and fixed.
- **Change Control**: the formal process for approving changes to a
  validated system. See `change-control.md`.
- **CAPA (Corrective and Preventive Action)**: how systemic failures are
  investigated and prevented from recurring.

## 4. Human Resources

- **Job Descriptions**: a signed job description for every role
  (e.g., Lead Developer, QA Engineer).
- **CV / Resume Management**: up-to-date and signed resumes for every
  staff member involved in the project.

## Sponsor-Facing Summary

| SOP | Why the Sponsor Needs It |
| --- | --- |
| SDLC SOP | Verifies the software was built under control. |
| Change Control SOP | Ensures updates do not break study data. |
| Backup & DR SOP | Satisfies the data-retention requirement. |
| Training SOP | Demonstrates developer qualification on clinical tooling. |
| Access Management SOP | Verifies authority checks under §11.10(g). |

The vendor typically provides a SOP Index (titles plus version numbers)
to the sponsor; the full text of individual SOPs is reviewed during a
live screen-share or via read-only portal access.
