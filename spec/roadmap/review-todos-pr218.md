# Spec Review TODOs from PR #218

**Source**: PR #218 "Spec review + Cur 188 gcp requirements doc"
**Reviewer**: Michael Bushe
**Date**: 2026-01-06

This document captures review TODOs from the spec review that were lost during the rebase of extract-tools branch. These should be addressed in follow-up tickets.

---

## prd-diary-app.md

### REQ-p00043: Clinical Diary Mobile Application
- TODO - need to validate web security for web version
- TODO - to where? CureHHT is the default sponsor until enrollment? Do old records sync? Do new records sync to both?
- TODO - User's Guide?
- TODO - Chat Support?
- TODO - Contact with study personnel
- TODO - Upgrades - automatic? On choice/forced?
- TODO - Observability - can the app report errors, metrics, logs to a server?

### REQ-p00007: Automatic Sponsor Configuration
- TODO - is "study" == site? Is site set in the portal?
- TODO - Does the app need to know the site?
- TODO - can a site have it's own brand?
- TODO - unless they already sync to CureHHT (re: patient cannot switch sponsor)

### REQ-p00006: Offline-First Data Entry
- TODO - we don't have a welcome screen. Is this shown once with a "don't show again"?
- TODO details - Conflict detection and resolution for multi-device scenarios
- TODO - do we have to record failures? (re: automatic retry logic)
- TODO - we sync immediately after each change, 15 min sync probably not necessary

### REQ-p01002: Optimistic Concurrency Control
- TODO - there is no conflict described
- TODO - this is not clear (re: scenario with different data values)

### REQ-p00050: Temporal Entry Validation
- TODO - always or on sponsor config? (re: entries >24 hours old require justification)
- TODO - always or on sponsor config? (re: entries <2 min old require confirmation)
- TODO - warning when overlaps exist (re: no time overlap)
- TODO - What does "current time" mean? (re: current time updates dynamically)
- TODO - Other (specify) may not be allowed, should only allow a fixed set
- TODO - then what's the use of a start day?
- TODO - any device for the logged in user or the device for a non-logged in user
- TODO - that's three grays (re: future dates styling)

---

## prd-portal.md

### REQ-p00025: Patient Enrollment Workflow
- TODO - need how a linking code maps to a sponsor so the diary app knows which site to auth with

### REQ-p00027: Questionnaire Management
- TODO - Not described - who and how the questionnaires are created and added to the system. Also versioning.

### REQ-p00028: Token Revocation and Access Control
- TODO - Audit use of token after revocation?

### REQ-p00029: Auditor Dashboard
- TODO - should site staff users also select a site (would they ever have access to more than one?)

---

## prd-diary-web.md

### REQ-p01042: Web Diary Application
- TODO - this needs another spec #
- TODO - Is this spec testable?
- TODO - needs details
- TODO - on what criteria?
- TODO - How secure? 2FA required? Biometrics?
- TODO - needs details (re: clear help text and guidance)

---

## prd-evidence-records.md

- TODO - do we need a PRD-level OpenTimestamps description?
- TODO - this needs details. When does the patient choose? (re: geolocation)
- TODO - only general longitude and not latitude at all

---

## prd-event-sourcing-system.md

- TODO - waves hands (re: pluggable conflict resolution strategies)
- TODO - This adds unnecessary complexity

---

## prd-backup.md

- TODO - email? (re: notifications)
- TODO - what's 25 year and what's 7 year? (re: retention)
- TODO - better as a notification for a report in the portal, email reports are a pain

---

## prd-security-RLS.md

- TODO - doesn't this conflict with GDPR?
- TODO - does the developer admin have access to patient data?

---

## prd-database.md

- TODO - perhaps "Materialized View" should be mentioned here
- TODO - It's linking the patient id (or "participant Id" below) with the enrollment code?
- TODO - how about another name for the user not in a study? They aren't their doctor's patient
- TODO - is there a good generic name for a portal user? "Portal User"?
- TODO - linking code is confusing here, it's not PHI, right?

---

## prd-architecture-multi-sponsor.md

- TODO - and site? (re: enrollment token identifies sponsor)

---

## dev-app.md

- TODO - Event type selection (sponsor-configured) - what's this?
- TODO - this needs clarity
- TODO - User information (local only - never sync'd)???

---

## dev-database.md / dev-database-reference.md

- TODO - _audit is commonly used when audit tables are added to a db
- TODO - record_materialized_view might be a more apt name
- TODO - PRDs should not reference table names, etc.

---

## dev-portal.md

- TODO - is this true for mobile too? if so, we should just remove or move this
- TODO - move to dev-app.md
- TODO - remove or move to dev-app.md

---

## ops-deployment.md

- TODO - build scripts need organizing and streamlining
- TODO - Dart is great for many tasks but this is best done with shell scripts
- TODO - dart run <dartfile> may not be the best tool for this, every build will need an sdk download
- TODO - this is taken from Dartatic.io, we may not need flutter nor all these tools
- TODO - a portal docker file

---

## ops-cicd.md

- TODO - GitHub Secrets for CI/CD pipelines (sync'ed via Doppler?)

---

## ops-infrastructure-as-code.md

- TODO - this seems to need more detail and discovery
- TODO - this needs details on how alerts are managed. They often pile up.

---

## ops-system.md

- TODO - this would violate GDPR for EU residents in the US
- TODO - similar to the above, then what? Incidents need human management.
- TODO - what does geo redundancy do to our scheme for all-EU for GDPR?

---

## General / Structure TODOs

- `scripts/` - TODO - update-index.js does what?
- `build-reports/` - TODO - doc
- `functions.sql` - TODO - necessary?
- `build/` - (Speculative Sponsor Integration - TODO fix)
- TODO - needs adjustment, also should be in ./apps/common-dart or move this to ./dart-common

---

## Next Steps

1. Create Linear tickets for each major TODO area
2. Assign to appropriate team members for resolution
3. Update requirements as TODOs are addressed
