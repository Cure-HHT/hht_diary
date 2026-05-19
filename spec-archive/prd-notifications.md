# Notifications and Participant Task System

**Version**: 1.0
**Audience**: Product
**Last Updated**: 2026-05-11
**Status**: Draft

> PRD requirements referenced by dev-notifications-v2.md.
> These capture the URS-level obligations that the dev specs implement.

---

## Section 1 — System-Wide Notification Standards (URS §4.7)

# REQ-p20078: Push Notification Platform

**Level**: prd | **Status**: Draft | **Implements**: -

## Rationale

The platform SHALL provide a push notification capability to deliver time-sensitive information to participants' mobile devices. The notification system must be reliable, PHI-safe, and auditable.

## Assertions

A. The System SHALL support sending Push Notifications to enrolled Participants' mobile devices.

*End* *Push Notification Platform* | **Hash**: 574f1f8d

---

## Section 2 — Lock Warning Notification (URS §6.8.4)

# REQ-p05015: Lock Warning Notification

**Level**: prd | **Status**: Draft | **Implements**: -

## Rationale

Participants SHALL be reminded before their diary entry window closes so they have the opportunity to complete or amend entries before they become read-only.

## Assertions

A. The System SHALL send a Push Notification to the Participant before the diary entry window for a given day closes.

*End* *Lock Warning Notification* | **Hash**: d3ac3f6a

---

## Section 3 — Yesterday Entry Reminder (URS §6.8.7)

# REQ-p05016: Yesterday Entry Reminder Notification

**Level**: prd | **Status**: Draft | **Implements**: -

## Rationale

Participants SHALL be reminded to record their daily status for the previous day if no entry has been made, supporting data completeness.

## Assertions

A. The System SHALL send a daily Push Notification reminding the Participant to record yesterday's diary entry if none has been recorded.

*End* *Yesterday Entry Reminder Notification* | **Hash**: 58983ef7

---

## Section 4 — Ongoing Epistaxis Reminder (URS §6.8.8)

# REQ-p05017: Ongoing Epistaxis Reminder Notification

**Level**: prd | **Status**: Draft | **Implements**: -

## Rationale

Participants with an active nosebleed recording SHALL be reminded to close the recording, supporting accurate duration capture.

## Assertions

A. The System SHALL send a Push Notification to the Participant when an epistaxis recording has been active beyond a configured threshold.

*End* *Ongoing Epistaxis Reminder Notification* | **Hash**: 048fc945

---

## Section 5 — Portal-Sent Questionnaire Notification (URS §6.8.6)

# REQ-p05018: Portal-Sent Questionnaire Notification

**Level**: prd | **Status**: Draft | **Implements**: -

## Rationale

When a Study Coordinator sends a questionnaire to a Participant, the Participant SHALL be notified via push notification so they can complete it promptly.

## Assertions

A. The System SHALL send a Push Notification to the Participant when a Study Coordinator sends them a questionnaire.

*End* *Portal-Sent Questionnaire Notification* | **Hash**: 18d22171

---

## Section 6 — Historical Gap Reminder (URS §6.8.10)

# REQ-p05019: Historical Gap Reminder Notification

**Level**: prd | **Status**: Draft | **Implements**: -

## Rationale

Participants SHALL be reminded about missing diary entries for past days within the editable window, supporting data completeness across the study period.

## Assertions

A. The System SHALL send a Push Notification to the Participant when there are missing diary entries for past days within the editable window.

*End* *Historical Gap Reminder Notification* | **Hash**: 72097d72

---

## Section 7 — Sponsor Notification Configuration

# REQ-p70020: Sponsor Notification Configuration

**Level**: prd | **Status**: Draft | **Implements**: -

## Rationale

Each sponsor deployment SHALL be able to configure notification timing, copy, and enablement to match their study protocol requirements.

## Assertions

A. The System SHALL allow per-sponsor configuration of notification timing and content.

*End* *Sponsor Notification Configuration* | **Hash**: b77b800b

---
