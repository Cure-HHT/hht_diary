# Clinical Questionnaire System

**Version**: 1.0
**Status**: Draft
**Last Updated**: 2026-01-21

> **See**: prd-questionnaire-approval.md for investigator approval workflow (REQ-p01064)
> **See**: prd-event-sourcing-system.md for versioning model (REQ-p01051, REQ-p01052, REQ-p01053)

---

## Overview

This specification defines the Clinical Questionnaire System, a framework for administering clinically validated data collection instruments in the Diary Platform. A questionnaire's content (questions, response options, scoring, recall period) is a validated artifact authored through formal clinical research; the platform's job is to administer it faithfully, preserve audit traceability, and present it through a quality user experience.

The system supports an extensible set of questionnaire types. Each questionnaire is defined by a bespoke catalog entry and is rendered by a renderer class drawn from a closed, platform-controlled taxonomy. Adding a questionnaire that fits an existing renderer class requires a new catalog entry and a sponsor configuration update. Adding a new renderer class is a platform-level decision.

---

## Questionnaire Model

A questionnaire in this system is:

- A **structured data collection instrument** with defined questions, response options, and scoring algorithms
- Defined by a **bespoke catalog entry** that pins content, scoring, and renderer binding
- Rendered by a **renderer class** drawn from a closed taxonomy; renderer classes may be shared across questionnaires of similar shape
- **Version-controlled** per the questionnaire versioning model (REQ-p01051)
- **Localizable** per the localization tracking model (REQ-p01052)
- **Sponsor-selectable** for trial eligibility (REQ-p01053); content is not sponsor-customizable

Questionnaires are NOT:

- Dynamically definable by end users or third parties
- Generic forms rendered from runtime configuration without a corresponding catalog entry
- Customizable per sponsor at the content level

---

## User Journeys

> **See**: [user-journeys/clinical-trial-enrollment-journeys.md](user-journeys/clinical-trial-enrollment-journeys.md)

---

## Questionnaire Lifecycle

![Questionnaire Lifecycle](images/questionnaire-lifecycle.mmd)

| Status | Description |
| ------ | ----------- |
| Sent | Questionnaire requested, awaiting patient action |
| In Progress | Patient is actively completing the questionnaire |
| Ready to Review | Patient has submitted, awaiting investigator review; patient may still edit |
| Finalized | Permanently locked, score calculated (if applicable) |

---

## Questionnaire Categories

### Initial Set (First Sponsor)

| Questionnaire | Type | Scoring | Approval Required |
| ------------- | ---- | ------- | ----------------- |
| Daily Epistaxis Record | Self-report diary | No | Study Start only |
| NOSE HHT | Validated instrument | Yes | Yes |
| HHT Quality of Life | Validated instrument | Yes | Yes |

### Future Questionnaires

Additional questionnaires are added through platform development as sponsors require them. Each new questionnaire receives its own requirement specification and a corresponding catalog entry. When a new questionnaire's content conforms to an existing renderer class, no renderer code is added. When it does not, a new renderer class is added to the platform taxonomy via the requirement amendment process described in REQ-p01065 (assertions K, L).

---

## Study Start Workflow

The "Study Start" workflow gates patient enrollment in a clinical trial:

1. **Sponsor triggers** initial Study Start questionnaire
2. **Patient completes** the questionnaire on their enrolled device
3. **Investigator reviews** and approves via the approval workflow (REQ-p01064)
4. **Study officially begins** upon investigator approval
5. **Data sync enabled** - patient data begins syncing to Sponsor Portal

Before Study Start approval:

- Patient data stored locally only
- No data synced to Portal
- Patient can continue using app but data remains local

After Study Start approval:

- Daily self-reported data syncs automatically
- No per-entry investigator approval required for ongoing records

---

## Data Storage

All questionnaire data follows the event sourcing model:

- **Immutable events** capture each interaction (answer provided, submission, approval)
- **Audit trail** records all status transitions with timestamps and acting user
- **Version tracking** captures questionnaire definition version used for each response

---

## Requirements

# REQ-p01065: Clinical Questionnaire System

**Level**: prd | **Status**: Active | **Implements**: -
**Refines**: REQ-p00044-C

## Rationale

Clinical trials require structured data collection instruments that ensure data quality, regulatory compliance, and optimal patient experience. Each questionnaire is a clinically validated artifact whose content (questions, response options, scoring algorithms, recall periods) is defined through formal research processes; sponsors select among validated questionnaires but do not customize their content. To preserve this validation guarantee while keeping engineering effort proportionate to clinical work, the platform separates content from presentation: each questionnaire is defined by a bespoke catalog entry, while presentation is delegated to a closed taxonomy of renderer classes that may be shared across questionnaires of similar shape. Adding a new questionnaire that conforms to an existing renderer class requires a new catalog entry but no new renderer code; adding a new renderer class is a platform-level decision.

**Design Choice**: Questionnaires are not definable or configurable by third parties or end users. The set of renderer classes is closed and platform-controlled. These constraints together preserve quality control, regulatory traceability, and validated-instrument fidelity.

## Assertions

A. The system SHALL support multiple questionnaire types, each defined by a bespoke catalog entry.

B. A questionnaire catalog entry SHALL define the questionnaire's content, response options, scoring rules, recall period, and renderer binding.

C. A questionnaire catalog entry SHALL specify the renderer class identifier and minimum compatible renderer class version that the questionnaire requires.

D. Questionnaires SHALL support versioning.

E. Scored questionnaires SHALL support an investigator approval workflow.

F. A configuration file SHALL configure which questionnaires are enabled for a Sponsor.

G. The system SHALL track completion status for each questionnaire instance.

H. The system shall support sponsor configurable study start date.

I. The system SHALL NOT sync patient data to the Sponsor Portal until the Study Start questionnaire has been approved by an investigator.

J. The platform SHALL provide a closed taxonomy of renderer classes.

K. Addition of a new renderer class to the taxonomy SHALL require a platform-level requirement.

L. A single renderer class MAY be referenced by multiple questionnaire catalog entries whose content conforms to its shape.

M. A questionnaire whose content does not conform to any existing renderer class SHALL be served by a renderer class registered specifically for it; a renderer class may have a single member questionnaire.

N. The content of a catalog entry SHALL NOT be customized or overridden per-sponsor at configuration time; modifications to a deployed catalog entry SHALL produce a new catalog entry version.

O. A catalog entry MAY be authored exclusively for a single sponsor's use; sponsor-exclusive catalog entries are subject to the same validation, lock, and immutability requirements as shared catalog entries.

## Changelog

- 2026-05-03 | a475dc2e | - | Developer (dev@example.com) | Auto-fix: update hash
- 2026-04-24 | 0a17515d | - | Developer (dev@example.com) | Auto-fix: add missing changelog section

*End* *Clinical Questionnaire System* | **Hash**: a475dc2e
---

## Child Requirements

The following requirements specify individual questionnaires:

| ID | Questionnaire | File |
| --- | ------------- | ---- |
| REQ-p01066 | Daily Epistaxis Record | prd-questionnaire-epistaxis.md |
| REQ-p01067 | NOSE HHT | prd-questionnaire-nose-hht.md |
| REQ-p01068 | HHT Quality of Life | prd-questionnaire-qol.md |

---

## References

- **Approval Workflow**: prd-questionnaire-approval.md (REQ-p01064)
- **Versioning Model**: prd-event-sourcing-system.md (REQ-p01051)
- **Localization**: prd-event-sourcing-system.md (REQ-p01052)
- **Sponsor Configuration**: prd-event-sourcing-system.md (REQ-p01053)
- **Event Sourcing**: prd-database.md (REQ-p00004)
- **FDA Compliance**: prd-clinical-trials.md (REQ-p00010)
