# Notifications Implementation

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2026-05-07
**Status**: Draft

> **See**: prd-services.md (REQ-p00049) for the platform notification service obligation.
> **See**: prd-diary-app.md (REQ-p00043, REQ-p00076) for the participant mobile experience obligations refined here.
> **See**: prd-diary-gui.md for participant-status badge obligations.
> **See**: docs/fcm-next-phase-plan.md for the architectural plan this spec implements (envelope pattern, comms package, mobile polling).
> **See**: docs/fcm-notification-redesign-plan.md for the design rationale.

---

## Executive Summary

This specification defines the dev-level implementation of the Participant Tasks and Notifications feature defined in URS section 6.8 (REQ-p05004, REQ-p05015, REQ-p05016, REQ-p05017, REQ-p05018, REQ-p05019, GUI-p05005, GUI-p00076), refined against the system-wide notification standards in URS section 4.7 (REQ-p20078).

The implementation has four engineering layers:

1. **Notification platform foundation** — durable `notifications` table, opaque envelope id, FCM transport via the `comms` package, mobile polling fallback, PHI-safe payload.
2. **Mobile UI surfaces** — Task List, Disconnection Notification, Participation Status Badge.
3. **Server-side push triggers** — Portal-Sent Questionnaire notification fired from the send handler.
4. **Time-based reminder schedulers** — Lock Warning, Yesterday Entry, Ongoing Epistaxis, Historical Gap.

A sponsor-scoped section at the bottom captures the concrete configuration values for the Callisto deployment.

**Technology surfaces**:

- **`comms` package** (`apps/common-dart/comms/`) — pure-Dart `FcmChannel` transport, PHI guard.
- **portal_functions / portal_server** — outbox writer, scheduler workers, send-side triggers.
- **diary_functions / diary_server** — polling endpoints, token registration.
- **clinical_diary** — receiver, polling client, task list, badge, disconnection notice.

---

## Section 1 — Notification Platform Foundation

# REQ-d00166: Notifications Table Envelope Schema

**Level**: dev | **Status**: Draft | **Implements**: REQ-p20078, REQ-p01018

## Rationale

The `notifications` table serves three roles simultaneously: outbox (persist before dispatch), audit record (immutable history of every notification dispatched), and polling source (the table mobile reads to catch up missed pushes). Conflating these roles into one table is intentional — separate tables would invite consistency drift between them. The schema mirrors the design in `docs/fcm-next-phase-plan.md` § "Schema (P1.1)".

## Assertions

A. The system SHALL persist every Push Notification as a row in the `notifications` table prior to FCM dispatch.

B. Each `notifications` row SHALL carry a `notification_id` (UUID, primary key), `patient_id`, `notification_type`, `title`, optional `body`, `payload` (JSONB), `status`, `message_id`, `last_error`, `created_at`, `sent_at`, and `delivered_at` columns.

C. The `notification_id` SHALL be opaque, generated server-side via `gen_random_uuid()`, and SHALL NOT be derived from any business identifier.

D. The `status` column SHALL accept exactly the values: `pending`, `sent`, `delivered`, `failed`.

E. The `notification_type` column SHALL accept exactly the values: `questionnaire_update`, `patient_status_update`, `reminder`.

F. The `notifications.patient_id` foreign key SHALL reference `patients(patient_id)` with `ON DELETE CASCADE`.

G. Row-level security on the `notifications` table SHALL restrict patient-role read access to rows whose `patient_id` matches the authenticated patient.

H. The table SHALL carry a partial index on `(patient_id, created_at DESC) WHERE delivered_at IS NULL` to support the mobile polling query.

I. A row SHALL transition from `pending` to `sent` only after the FCM channel returns a successful dispatch result, and the `sent_at` column SHALL be set to `now()` in the same update.

J. A row SHALL transition from `pending` to `failed` only on an unrecoverable channel dispatch error, and the `last_error` column SHALL be populated with the error string in the same update.

K. A row SHALL transition to `delivered` only when the polling endpoint returns the row to the patient's mobile, and the `delivered_at` column SHALL be set to `now()` in the same update.

_End_ _Notifications Table Envelope Schema_ | **Hash**: 00000000

---

# REQ-d00167: Comms FCM Channel Transport

**Level**: dev | **Status**: Draft | **Implements**: REQ-p20078

## Rationale

A single transport implementation means there is exactly one place where FCM authentication, payload framing, response classification, and timeout policy are defined. The `comms` package owns this implementation; consuming services dispatch via the `Channel<T>.dispatch()` interface. Future channels (email, Slack) will plug into the same interface.

## Assertions

A. The system SHALL dispatch every Push Notification through a single `FcmChannel` implementation residing in the `comms` package.

B. The `FcmChannel.dispatch()` method SHALL apply a 10-second timeout to the FCM `messages:send` HTTP call.

C. The `FcmChannel` SHALL classify a 404 response with error code `UNREGISTERED` as a permanent failure and SHALL request deactivation of the offending FCM token.

D. The `FcmChannel` SHALL classify any non-200 response that is not 404 `UNREGISTERED` as a transient failure.

E. The `FcmChannel.dispatch()` SHALL NOT perform any retry; recovery from transient failures SHALL be the responsibility of the mobile polling fallback defined in REQ-d00169.

F. The `comms` package and its `FcmChannel` SHALL NOT depend on the Flutter SDK or `firebase_messaging` package.

G. The `FcmChannel` SHALL authenticate to FCM using Application Default Credentials sourced from Workload Identity Federation.

H. The `FcmChannel` SHALL emit a `comms.fcm.dispatch` metric tagged with `result={success|failed|unregistered}` for every dispatch call.

_End_ _Comms FCM Channel Transport_ | **Hash**: 00000000

---

# REQ-d00168: PHI-Safe FCM Payload

**Level**: dev | **Status**: Draft | **Implements**: REQ-p20078, REQ-p00016, REQ-p00017

## Rationale

FCM traffic crosses Google's infrastructure outside the sponsor project boundary. Any identifier in the payload that resolves to a participant — including SubjectKey, name, email, or business IDs that link to patient records — is potentially PHI under HIPAA Safe Harbor and GDPR. The envelope pattern restricts the payload to an opaque, server-issued UUID; the participant-resolvable content stays inside the sponsor's database and is fetched by the mobile via authenticated API.

## Assertions

A. The FCM data payload SHALL contain only the opaque `notification_id` and a generic, sponsor-neutral title key.

B. The FCM data payload SHALL NOT contain any `patient_id`, SubjectKey, participant name, email address, date of birth, or any other identifier that resolves to a specific participant.

C. The FCM data payload SHALL NOT contain any clinical content including questionnaire titles bound to a specific participant, dates of medical events, or response data.

D. A `PayloadGuard` component SHALL run before the `FcmChannel` dispatches a message and SHALL reject any payload whose serialized form matches a configured PHI pattern.

E. The `PayloadGuard` SHALL match at minimum: SubjectKey format (`\d{3}-\d{3}-\d{3}`), email address format, and configured common-name patterns.

F. The `PayloadGuard` SHALL also run before insertion into the `notifications` table, applied to `title`, `body`, and the serialized `payload` columns.

G. A `PayloadGuard` rejection SHALL raise an exception that aborts the dispatch and SHALL be logged with severity `ERROR`.

H. The `PayloadGuard` SHALL NOT be bypassable by production code; bypass SHALL be permitted only inside test fixtures via an explicit test-only flag.

_End_ _PHI-Safe FCM Payload_ | **Hash**: 00000000

---

# REQ-d00169: Mobile Envelope Polling

**Level**: dev | **Status**: Draft | **Implements**: REQ-p20078

## Rationale

REQ-p20078-C requires that an offline notification be delivered when the Mobile Application next establishes connectivity. FCM is a best-effort transport: pushes can be dropped by the OS, throttled by Apple, suppressed by user settings, or simply lost when the device has been offline for an extended period. Mobile polling against the `notifications` table is the authoritative reliability mechanism. Backend retries are explicitly NOT used — polling subsumes them.

## Assertions

A. The diary_server SHALL expose `GET /api/v1/notifications?since=<timestamp>` returning every `notifications` row for the authenticated patient with `created_at` strictly greater than the supplied timestamp.

B. The endpoint SHALL authenticate via the patient JWT and SHALL return only rows whose `patient_id` equals the resolved patient.

C. The endpoint response SHALL include the server's current time as `server_time` to allow the client to advance its polling cursor without local clock skew.

D. For every row returned, the endpoint SHALL set `delivered_at = now()` if currently `NULL` within the same response transaction.

E. Setting `delivered_at` SHALL be idempotent: once non-null, the value SHALL NOT be overwritten by subsequent fetches.

F. The Mobile Application SHALL invoke the polling endpoint on app foreground resume.

G. The Mobile Application SHALL invoke the polling endpoint while foregrounded at a configurable interval whose default value SHALL be 60 seconds.

H. The Mobile Application SHALL persist a per-patient `lastSeen` timestamp and SHALL pass that timestamp as the `since` parameter on every poll.

I. The Mobile Application SHALL update `lastSeen` to the `server_time` returned by the polling endpoint after every successful poll.

J. The Mobile Application SHALL deduplicate envelopes by `notification_id` across the FCM and polling delivery paths.

K. The Mobile Application SHALL clear the `lastSeen` cursor on logout and on patient unlink.

_End_ _Mobile Envelope Polling_ | **Hash**: 00000000

---

# REQ-d00170: Notification Tap Routes To Main Screen

**Level**: dev | **Status**: Draft | **Implements**: REQ-p20078

## Rationale

REQ-p20078-A and REQ-p20078-B mandate a uniform tap behavior: the participant always lands on the Main Screen, and no in-notification quick-actions exist. This keeps notifications strictly as nudges and keeps the action context inside the app where it can be authenticated and audited.

## Assertions

A. When the Participant taps a Push Notification while the Mobile Application is terminated, the System SHALL launch the application and present the Main Screen.

B. When the Participant taps a Push Notification while the Mobile Application is in the background, the System SHALL bring the application to the foreground and present the Main Screen.

C. The System SHALL NOT navigate the Participant to any destination other than the Main Screen on notification tap.

D. The Push Notification SHALL NOT include any inline response actions, quick-reply buttons, or tap-target deep links other than the application launch itself.

_End_ _Notification Tap Routes To Main Screen_ | **Hash**: 00000000

---

# REQ-d00171: Outbox-Write-Then-Dispatch Sequencing

**Level**: dev | **Status**: Draft | **Implements**: REQ-p20078, REQ-p01018

## Rationale

The notification row is durable; the FCM dispatch is best-effort. By committing the row inside the same transaction as the action that triggers it, we guarantee that if the action commits, the notification is recoverable — even if the server crashes before the FCM call returns. Polling closes the loop. This is the standard transactional outbox pattern.

## Assertions

A. Every server-originated Push Notification SHALL be persisted to the `notifications` table with `status='pending'` before any FCM dispatch is attempted.

B. The `notifications` row SHALL be inserted within the same database transaction as the action that triggers it (status change, questionnaire send, scheduled fire).

C. After the triggering transaction commits, the server SHALL invoke the FCM channel and SHALL update the row to `status='sent'` with the FCM `message_id` on success.

D. After the triggering transaction commits, the server SHALL invoke the FCM channel and SHALL update the row to `status='failed'` with the error string on unrecoverable channel error.

E. A process crash between row commit and FCM dispatch completion SHALL leave the row in `status='pending'`; the polling endpoint SHALL still return the row, allowing the Mobile Application to surface the notification.

F. The `notifications` row SHALL serve as the audit record for the dispatch attempt; no parallel `admin_action_log` row SHALL be required for FCM-send audit.

G. The outbox dispatch invocation SHALL NOT be attempted from inside the triggering transaction.

_End_ _Outbox-Write-Then-Dispatch Sequencing_ | **Hash**: 00000000

---

## Section 2 — Participant Task List (refines GUI-p05005)

# REQ-d00172: Reactive Task List Updates

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00043
**Refines**: GUI-p05005

## Assertions

A. The Task List SHALL update in response to changes in the underlying state without requiring the Participant to perform a manual refresh.

B. Tasks SHALL be added to or removed from the Task List when their respective trigger or removal predicates change value.

C. Updates to the Task List SHALL be applied within one second of the underlying state change becoming visible to the Mobile Application.

_End_ _Reactive Task List Updates_ | **Hash**: 00000000

---

## Section 6 — Portal-Sent Questionnaire Notification (refines REQ-p05018)

# REQ-d00173: Send Handler Trigger And Suppression

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05018

## Rationale

The send-handler is the single trigger point for the Portal-Sent Questionnaire push. Suppression rules (already-submitted, called-back) are evaluated server-side at trigger time, not on the device. The notification carries only the opaque envelope id; the questionnaire content is fetched via the existing diary_server API.

## Assertions

A. When the Sponsor Portal successfully delivers a Portal-Sent Questionnaire to the Mobile Application, the System SHALL enqueue a Push Notification for the Participant via the outbox defined in REQ-d00171.

B. The System SHALL NOT enqueue a Push Notification for a Portal-Sent Questionnaire that has already been submitted by the Participant.

C. The System SHALL NOT enqueue a Push Notification for a Portal-Sent Questionnaire that has been called back by the Study Coordinator.

D. The notification's `notification_type` SHALL be `questionnaire_update` and the `payload.action` SHALL be `sent`.

E. The Mobile Application SHALL receive the notification on next connectivity if it is offline at dispatch time, via the polling endpoint defined in REQ-d00169.

_End_ _Send Handler Trigger And Suppression_ | **Hash**: 00000000

---

## Section 7 — Yesterday Entry Reminder Notification (refines REQ-p05016)

# REQ-d00174: Yesterday Reminder Daily Scheduling, Timezone-Aware

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05016

## Rationale

The Yesterday Entry Reminder fires at a sponsor-configured local time of day. "Local" means the participant's device timezone, not the server's. The server therefore needs the device timezone for every active participant. Token registration is the natural pickup point; the timezone travels with the FCM-token registration call and is updated on subsequent registrations.

## Assertions

A. A server-side scheduled job SHALL evaluate every Participant once per calendar day at the configured Reminder Time.

B. The Reminder Time SHALL be evaluated against the Participant's device local timezone.

C. The "previous calendar day" SHALL be determined against the Participant's device local timezone.

D. The job SHALL enqueue at most one Yesterday Entry Reminder Notification per Participant per calendar day.

E. The Mobile Application SHALL communicate its device timezone to the diary_server during FCM token registration and on every subsequent timezone change.

F. The platform SHALL expose a `Yesterday Reminder Time` configuration parameter per deployment.

G. The notification's `notification_type` SHALL be `reminder` and `payload.action` SHALL be `yesterday_entry`.

_End_ _Yesterday Reminder Daily Scheduling, Timezone-Aware_ | **Hash**: 00000000

---

# REQ-d00175: Yesterday Reminder Suppression

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05016

## Assertions

A. The Yesterday Entry Reminder job SHALL skip any Participant for whom a Daily Status has been recorded for the previous calendar day.

B. The skip evaluation SHALL be performed at the moment the job evaluates the Participant, immediately before the outbox write.

_End_ _Yesterday Reminder Suppression_ | **Hash**: 00000000

---
