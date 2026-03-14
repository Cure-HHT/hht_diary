# Questionnaire Session Management Specification

**Version**: 1.0
**Status**: Draft
**Last Updated**: 2026-02-19

> **See**: prd-questionnaire-system.md for parent requirement (REQ-p01065)

---

## User Journeys

> **See**: [user-journeys/questionnaire-session-journeys.md](user-journeys/questionnaire-session-journeys.md)

---

## Overview

This specification defines session management for clinical questionnaires, ensuring patients complete validated instruments in a timely, uninterrupted manner. Session management is configurable per questionnaire, allowing longer instruments like NOSE HHT to enforce completion constraints while shorter instruments may opt out.

---

## Requirements

# REQ-p01073: Questionnaire Session Management

**Level**: PRD | **Status**: Draft | **Refines**: REQ-p01065-G

Addresses: JNY-Questionnaire-Session-01, JNY-Questionnaire-Session-02

## Rationale

Validated clinical instruments require uninterrupted completion to ensure response consistency and data quality. Patients who are interrupted for extended periods may experience changes in context, mood, or recall that compromise the validity of partially-completed responses. A configurable session management framework allows each questionnaire to enforce appropriate completion constraints based on its length and clinical requirements.

## Assertions

### Readiness Gate

A. When a questionnaire is configured with a readiness check, the system SHALL display a readiness screen before the instrument preamble, informing the patient of the estimated completion time.

B. The readiness screen SHALL offer the patient a choice to proceed or defer the questionnaire.

C. If the patient defers, the system SHALL record a session-deferred event with the questionnaire instance UUID.

D. If the patient defers, the system SHALL return the patient to the previous screen.

E. The system SHALL record a session-started event when the patient confirms readiness and proceeds.

### Session Timeout

F. When a questionnaire is configured with a session timeout, the system SHALL track elapsed time from the most recent app-foreground interaction with the questionnaire.

G. The timeout clock SHALL only advance while the app is backgrounded, closed, or the device is locked.

H. When the timeout is exceeded before questionnaire submission, the system SHALL discard the partial responses.

I. When the timeout is exceeded, the system SHALL record a session-expired event with reason "Questionnaire Timeout Limit Exceeded", retaining the questionnaire instance UUID.

J. The expired questionnaire instance SHALL require the patient to complete the readiness gate and all questions again from the beginning.

### In-App Expiry Notification

K. Upon app resume, if a questionnaire session has expired, the system SHALL display an expiry message to the patient.

L. The task notification for an expired questionnaire SHALL change from the standard pending message to an expiry-specific message.

### OS-Level Notifications

M. When configured, the system SHALL deliver an OS-level push notification when the session timeout is approaching (e.g., 5 minutes remaining) to allow the patient to resume.

N. When configured, the system SHALL deliver an OS-level push notification when the session has expired, informing the patient they must restart the questionnaire.

### Configuration

O. Each questionnaire definition SHALL support optional session management configuration including: readiness check enabled/disabled, estimated completion time, and session timeout duration.

P. Questionnaires without session management configuration SHALL preserve and restore state on app resume with no timeout constraint.

### App Resume Behavior

Q. When the app is resumed after being closed by the OS, if a questionnaire is in progress and has not timed out, the app SHALL open to the questionnaire for completion.

*End* *Questionnaire Session Management* | **Hash**: a101e60e

---

## References

- **Parent Requirement**: prd-questionnaire-system.md (REQ-p01065)
- **NOSE HHT Questionnaire**: prd-questionnaire-nose-hht.md (REQ-p01067)
- **HHT Quality of Life**: prd-questionnaire-qol.md (REQ-p01068)
- **Event Sourcing**: prd-database.md (REQ-p00004)
- **Amended by this requirement**: REQ-CAL-p00023-J
