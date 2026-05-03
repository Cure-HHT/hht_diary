# Validation Package

The Validation Package is the body of evidence demonstrating that the platform
is fit for purpose under 21 CFR Part 11 and ready for sponsor review.

## 1. Core Validation Package

This section proves the platform meets its requirements.

- **System Requirement Specification (SRS)**: the full list of hashed
  requirements and assertions.
- **Validation Plan (VP)**: the strategy used to test the system, including
  the requirement-extraction tooling. See `software-validation-plan.md`.
- **Traceability Matrix (TM)**: the report showing every requirement maps to
  a corresponding test and code implementation.
- **Verification / Validation Reports (VVR / VSR)**: the summary of test
  results. For a SaaS deployment, the Vendor Validation Report demonstrates
  that the platform is stable.
- **Risk Assessment (RA)**: a document showing risks have been considered
  (e.g., data loss, unauthorized access) and that controls (e.g., MFA, audit
  trails) have been implemented. See `risks.md`.

## 2. Infrastructure & Security Documentation

For a GCP-on-Terraform deployment, the sponsor needs evidence that the
environment is managed.

- **Architecture Diagram**: a high-level view of the VPC, cloud portal, and
  the data flow to the EDC.
- **Infrastructure-as-Code (IaC) Audit Trail**: a summary or log showing that
  environment changes are tracked through Git and Terraform.
- **Disaster Recovery (DR) & Backup Plan**: proof that patient data is backed
  up and recoverable from a regional outage.
- **Security Assessment / Penetration-Test Summary**: a high-level summary of
  any security audits or penetration tests performed on the application.

## 3. Hand-Over SOPs & Manuals

The sponsor and clinical sites must know how to use and govern the software.

- **User Manual / Training Materials**: instructions and screenshots for
  patients (the diary application) and administrators (the portal).
- **Administrator Guide**: how to create and edit accounts and how to manage
  Role assignments.
- **System Admin SOPs**: when the vendor hosts the application, internal SOPs
  for Change Management (how updates are pushed) and Incident Management (how
  bugs are handled). See `SDLC-SOP.md`.

## 4. Technical Logs (On Request / Regularly)

Logs are not stored in the validation binder, but the vendor MUST provide the
mechanism for the sponsor to retrieve them.

- **Electronic Audit Trails**: computer-generated, time-stamped logs of every
  eSource entry and account change.
- **System Logs**: evidence of system uptime and server-level security
  events.

## Vendor Assessment

Sponsors typically issue a Vendor Assessment Questionnaire before a trial
begins, drawing on the documents above to qualify the vendor. Maintaining the
package in a SharePoint site or a secure vendor portal accelerates this
review and provides a single source of truth across multiple sponsors.
