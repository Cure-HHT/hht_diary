# Notifications Implementation — v2

**Version**: 2.0
**Audience**: Development
**Last Updated**: 2026-05-07
**Status**: Draft
**Supersedes**: dev-notifications.md (v1.0) — once promoted to Active.

> **See**: prd-services.md (REQ-p00049) for the platform notification service obligation.
> **See**: prd-diary-app.md (REQ-p00043, REQ-p00076) for the participant mobile experience obligations refined here.
> **See**: prd-diary-gui.md for the participant-task-list and participant-status-badge GUI obligations refined here.
> **See**: docs/fcm-next-phase-plan.md for the architectural plan this spec implements (envelope pattern, comms package, mobile polling).
> **See**: docs/fcm-notification-redesign-plan.md for the design rationale.

---

## Executive Summary

This specification (v2) defines the dev-level implementation of the Participant Tasks and Notifications feature defined in URS section 6.8 (REQ-p05004, REQ-p05015, REQ-p05016, REQ-p05017, REQ-p05018, REQ-p05019, GUI-p05005, GUI-p00076), refined against the system-wide notification standards in URS section 4.7 (REQ-p20078).

The v2 of this spec re-bases the dev-level requirements onto the v1.0 URS text; it preserves the four-layer engineering decomposition of v1 with tightened assertion language and one explicit cross-reference per layer:

1. **Notification platform foundation** — durable `notifications` table, opaque envelope id, FCM transport via the `comms` package, mobile polling fallback, PHI-safe payload, outbox-write-then-dispatch sequencing.
2. **Mobile UI surfaces** — Task List, Disconnection Notification, Participation Status Badge.
3. **Server-side push triggers** — Portal-Sent Questionnaire notification fired from the send handler.
4. **Time-based reminder schedulers** — Lock Warning, Yesterday Entry, Ongoing Epistaxis, Historical Gap.

A sponsor-scoped section at the bottom captures the concrete configuration values for the Callisto deployment.

**Technology surfaces**:

- **`comms` package** (`apps/common-dart/comms/`) — pure-Dart `FcmChannel` transport, `PayloadGuard`.
- **portal_functions / portal_server** — outbox writer, scheduler workers, send-side triggers.
- **diary_functions / diary_server** — polling endpoints, FCM token registration, timezone capture.
- **clinical_diary** — receiver, polling client, task list, badge, disconnection notice.

**URS → dev-REQ traceability**:

| URS §             | Source         | v2 dev REQs             |
| ----------------- | -------------- | ----------------------- |
| 4.7 (system-wide) | REQ-p20078     | REQ-d00192 → REQ-d00197 |
| 6.8.1             | GUI-p05005     | REQ-d00198 → REQ-d00202 |
| 6.8.2             | REQ-p05004     | REQ-d00203, REQ-d00204  |
| 6.8.3             | GUI-p00076     | REQ-d00205              |
| 6.8.4             | REQ-p05015     | REQ-d00206, REQ-d00207  |
| 6.8.5             | REQ-CAL-p00091 | REQ-CAL-d00004          |
| 6.8.6             | REQ-p05018     | REQ-d00208              |
| 6.8.7             | REQ-p05016     | REQ-d00209, REQ-d00210  |
| 6.8.8             | REQ-p05017     | REQ-d00211 → REQ-d00213 |
| 6.8.9             | REQ-CAL-p00093 | REQ-CAL-d00005          |
| 6.8.10            | REQ-p05019     | REQ-d00214 → REQ-d00217 |
| 6.8.11            | REQ-CAL-p00093 | REQ-CAL-d00006          |

---

## Section 1 — Notification Platform Foundation

# REQ-d00192: Notifications Table Envelope Schema

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01018

## Rationale

The `notifications` table fulfils three roles simultaneously: outbox (persist before dispatch), audit record (immutable history of every notification dispatched), and polling source (the table the Mobile Application reads to recover missed pushes). Conflating these roles into one table is intentional — separate tables would invite consistency drift between them. The schema mirrors the design in `docs/fcm-next-phase-plan.md` § "Schema (P1.1)".

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

L. Once any timestamp column (`sent_at`, `delivered_at`) is non-null, subsequent updates SHALL NOT overwrite it.

*End* *Notifications Table Envelope Schema* | **Hash**: 36d3e0c1

---

# REQ-d00193: Comms FCM Channel Transport

**Level**: dev | **Status**: Draft | **Implements**: REQ-p20078

## Rationale

A single transport implementation means there is exactly one place where FCM authentication, payload framing, response classification, and timeout policy are defined. The `comms` package owns this implementation; consuming services dispatch via the `Channel<T>.dispatch()` interface. Future channels (email, Slack) plug into the same interface.

## Assertions

A. The system SHALL dispatch every Push Notification through a single `FcmChannel` implementation residing in the `comms` package.

B. The `FcmChannel.dispatch()` method SHALL apply a 10-second timeout to the FCM `messages:send` HTTP call.

C. The `FcmChannel` SHALL classify a 404 response with error code `UNREGISTERED` as a permanent failure and SHALL request deactivation of the offending FCM token.

D. The `FcmChannel` SHALL classify any non-200 response that is not 404 `UNREGISTERED` as a transient failure.

E. The `FcmChannel.dispatch()` SHALL NOT perform any retry; recovery from transient failures SHALL be the responsibility of the mobile polling fallback defined in REQ-d00195.

F. The `comms` package and its `FcmChannel` SHALL NOT depend on the Flutter SDK or `firebase_messaging` package.

G. The `FcmChannel` SHALL authenticate to FCM using Application Default Credentials sourced from Workload Identity Federation, refreshing the bearer token at least 5 minutes before expiry.

H. The `FcmChannel` SHALL emit a `comms.fcm.dispatch` metric tagged with `result={success|failed|unregistered}` for every dispatch call.

*End* *Comms FCM Channel Transport* | **Hash**: efe5a3eb

---

# REQ-d00194: PHI-Safe FCM Payload

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00016, REQ-p00017

## Rationale

FCM traffic crosses Google's infrastructure outside the sponsor project boundary. Any identifier in the payload that resolves to a participant — including SubjectKey, name, email, or business IDs that link to patient records — is potentially PHI under HIPAA Safe Harbor and GDPR. The envelope pattern restricts the payload to an opaque, server-issued UUID; the participant-resolvable content stays inside the sponsor's database and is fetched by the mobile via authenticated API.

## Assertions

A. The FCM data payload SHALL contain only the opaque `notification_id` and a generic, sponsor-neutral title key.

B. The FCM data payload SHALL NOT contain any `patient_id`, SubjectKey, participant name, *Email Address*, date of birth, or any other identifier that resolves to a specific participant.

C. The FCM data payload SHALL NOT contain any clinical content including questionnaire titles bound to a specific participant, dates of medical events, or response data.

D. A `PayloadGuard` component SHALL run before the `FcmChannel` dispatches a message and SHALL reject any payload whose serialized form matches a configured PHI pattern.

E. The `PayloadGuard` SHALL match at minimum: SubjectKey format (`\d{3}-\d{3}-\d{3}`), *Email Address* format, and configured common-name patterns.

F. The `PayloadGuard` SHALL also run before insertion into the `notifications` table, applied to `title`, `body`, and the serialized `payload` columns.

G. A `PayloadGuard` rejection SHALL raise an exception that aborts the dispatch and SHALL be logged with severity `ERROR`.

H. The `PayloadGuard` SHALL NOT be bypassable by production code; bypass SHALL be permitted only inside test fixtures via an explicit test-only flag.

*End* *PHI-Safe FCM Payload* | **Hash**: 8e4a991e

---

# REQ-d00195: Mobile Envelope Polling

**Level**: dev | **Status**: Draft | **Implements**: REQ-p20078

## Rationale

REQ-p05018-B and REQ-p20078-C require that an offline notification be delivered when the Mobile Application next establishes connectivity. FCM is a best-effort transport: pushes can be dropped by the OS, throttled by Apple, suppressed by user settings, or simply lost when the device has been offline for an extended period. Mobile polling against the `notifications` table is the authoritative reliability mechanism. Server-side retries are explicitly NOT used — polling subsumes them.

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

*End* *Mobile Envelope Polling* | **Hash**: de792236

---

# REQ-d00196: Notification Tap Routes To Main Screen

**Level**: dev | **Status**: Draft | **Implements**: REQ-p20078

## Rationale

REQ-p20078-A and REQ-p20078-B mandate a uniform tap behavior: the participant always lands on the Main Screen, and no in-notification quick-actions exist. This keeps notifications strictly as nudges and keeps the action context inside the application where it can be authenticated and audited.

## Assertions

A. When the Participant taps a Push Notification while the Mobile Application is terminated, the System SHALL launch the application and present the Main Screen.

B. When the Participant taps a Push Notification while the Mobile Application is in the background, the System SHALL bring the application to the foreground and present the Main Screen.

C. The System SHALL NOT navigate the Participant to any destination other than the Main Screen on notification tap.

D. The Push Notification SHALL NOT include any inline response actions, quick-reply buttons, or tap-target deep links other than the application launch itself.

*End* *Notification Tap Routes To Main Screen* | **Hash**: 0788d843

---

# REQ-d00197: Outbox-Write-Then-Dispatch Sequencing

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01018

## Rationale

The notification row is durable; the FCM dispatch is best-effort. By committing the row inside the same transaction as the action that triggers it, the system guarantees that if the action commits, the notification is recoverable — even if the server crashes before the FCM call returns. Polling closes the loop. This is the standard transactional outbox pattern.

## Assertions

A. Every server-originated Push Notification SHALL be persisted to the `notifications` table with `status='pending'` before any FCM dispatch is attempted.

B. The `notifications` row SHALL be inserted within the same database transaction as the action that triggers it (status change, questionnaire send, scheduled fire).

C. After the triggering transaction commits, the server SHALL invoke the FCM channel and SHALL update the row to `status='sent'` with the FCM `message_id` on success.

D. After the triggering transaction commits, the server SHALL invoke the FCM channel and SHALL update the row to `status='failed'` with the error string on unrecoverable channel error.

E. A process crash between row commit and FCM dispatch completion SHALL leave the row in `status='pending'`; the polling endpoint defined in REQ-d00195 SHALL still return the row, allowing the Mobile Application to surface the notification.

F. The `notifications` row SHALL serve as the audit record for the dispatch attempt; no parallel `admin_action_log` row SHALL be required for FCM-send audit.

G. The outbox dispatch invocation SHALL NOT be attempted from inside the triggering transaction.

*End* *Outbox-Write-Then-Dispatch Sequencing* | **Hash**: e4d9296f

---

## Section 2 — Participant Task List (refines GUI-p05005, URS §6.8.1)

# REQ-d00198: Task Domain Model And Priority Ordering

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00043
**Refines**: GUI-p05005

## Rationale

The Task List is a derived view over local state — incomplete diary entries, the local cache of Portal-Sent Questionnaires, and the da/exiily-status history. It is not a server-managed list. This keeps the UI offline-first and keeps removal logic deterministic from device state.

## Assertions

A. The Mobile Application SHALL maintain a Task List composed of three task kinds: `IncompleteRecordsTask`, `QuestionnaireTask`, `YesterdayReminderTask`.

B. The Task List SHALL be ordered by task kind in this fixed priority: `IncompleteRecordsTask` first, `QuestionnaireTask` second, `YesterdayReminderTask` third.

C. Within the `QuestionnaireTask` kind, the Task List SHALL display at most one task per Questionnaire Type.

D. Each task SHALL expose at minimum a kind, a primary action, and a removal predicate evaluated against the application's reactive state.

E. A task SHALL be removed from the Task List when its removal predicate evaluates true.

F. The Task List SHALL be derived from local state only and SHALL NOT depend on a network round-trip for its render.

*End* *Task Domain Model And Priority Ordering* | **Hash**: 58099754

---

# REQ-d00199: Incomplete Records Task Source

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00043
**Refines**: GUI-p05005

## Assertions

A. The `IncompleteRecordsTask` SHALL be present whenever the Participant has one or more saved entries with missing required data.

B. The `IncompleteRecordsTask` SHALL display the count of incomplete entries.

C. Selection of the `IncompleteRecordsTask` SHALL navigate to a screen listing all incomplete entries.

D. The incomplete entries screen SHALL allow the Participant to complete or delete each entry.

E. The `IncompleteRecordsTask` SHALL persist regardless of the age of the contained incomplete entries.

F. The `IncompleteRecordsTask` SHALL be removed from the Task List only when the count of incomplete entries reaches zero.

*End* *Incomplete Records Task Source* | **Hash**: ea5b2e53

---

# REQ-d00200: Portal Questionnaire Task Source And State

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00043
**Refines**: GUI-p05005

## Rationale

The Questionnaire Task has two visual states with distinct removal conditions. The pre-submission state is a call to action; the submitted state is a hold-open until sponsor finalization, during which the Participant retains the ability to revise their answers. Modeling both in one task kind keeps the priority slot stable and avoids duplicate rendering.

## Assertions

A. A `QuestionnaireTask` SHALL exist for every Portal-Sent Questionnaire delivered to the Mobile Application that has not yet been finalized by the Sponsor.

B. The Mobile Application SHALL display at most one `QuestionnaireTask` per Questionnaire Type.

C. Selection of a `QuestionnaireTask` in its pre-submission state SHALL navigate to the questionnaire flow for the corresponding Portal-Sent Questionnaire.

D. After the Participant submits a Portal-Sent Questionnaire, the questionnaire SHALL remain accessible as a record on the day of submission via the Calendar.

E. After Sponsor finalization, the `QuestionnaireTask` SHALL be removed from the Task List.

F. After submission and before finalization, the `QuestionnaireTask` SHALL render in a completed visual state distinct from its pre-submission state, indicating the questionnaire has been submitted and is awaiting sponsor review.

G. While in the completed visual state, selection of the `QuestionnaireTask` SHALL allow the Participant to review and edit submitted answers.

*End* *Portal Questionnaire Task Source And State* | **Hash**: 068c8ebf

---

# REQ-d00201: Yesterday Reminder Task Source And Actions

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00043, REQ-p00050
**Refines**: GUI-p05005

## Assertions

A. The `YesterdayReminderTask` SHALL be present when a new day begins and the Participant has not recorded a Daily Status for the previous day.

B. The `YesterdayReminderTask` SHALL present three response actions: Yes, No, Don't Remember.

C. Selection of `No` SHALL record a Daily Status of "No Nosebleed" for the previous day and SHALL remove the task from the Task List.

D. Selection of `Don't Remember` SHALL record a Daily Status of "Don't Remember" for the previous day and SHALL remove the task from the Task List.

E. Selection of `Yes` SHALL navigate the Participant to the nosebleed recording flow with the date set to the previous day.

F. The `YesterdayReminderTask` SHALL NOT be displayed when a Daily Status has already been recorded for the previous day.

*End* *Yesterday Reminder Task Source And Actions* | **Hash**: 87727808

---

# REQ-d00202: Reactive Task List Updates

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00043
**Refines**: GUI-p05005

## Assertions

A. The Task List SHALL update in response to changes in the underlying state without requiring the Participant to perform a manual refresh.

B. Tasks SHALL be added to or removed from the Task List when their respective trigger or removal predicates change value.

C. Updates to the Task List SHALL be applied within one second of the underlying state change becoming visible to the Mobile Application.

*End* *Reactive Task List Updates* | **Hash**: 62ae725c

---

## Section 3 — Disconnection Notification (refines REQ-p05004, URS §6.8.2)

# REQ-d00203: Disconnected State Notice Rendering

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05004

## Rationale

The Disconnection Notification is an in-app surface, not an OS-level push. It is bound to the participant's status field; the rendering layer reads the status and produces the notice. Persistence and non-dismissibility are enforced by the rendering layer, not by data attributes on the row.

## Assertions

A. When the Participant's status is `Disconnected`, the Mobile Application SHALL display a Disconnection Notification on the Main Screen.

B. The Disconnection Notification SHALL persist on the Main Screen for the entire duration the Participant's status is `Disconnected`.

C. The Disconnection Notification SHALL NOT expose any user action that dismisses or hides it.

D. The Disconnection Notification SHALL be removed from the Main Screen when the Participant's status transitions out of `Disconnected`.

E. The Disconnection Notification SHALL re-render reactively from the participant-status state without requiring a navigation event or manual refresh.

*End* *Disconnected State Notice Rendering* | **Hash**: 9fa6e086

---

# REQ-d00204: Sponsor-Configurable Disconnection Copy

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05004

## Assertions

A. The Disconnection Notification message text SHALL be loaded from the active sponsor's configuration at render time.

B. When no sponsor-specific message text is configured, the Mobile Application SHALL display the platform default text: "Your connection with the study has been interrupted. Please contact your study site for assistance."

C. The sponsor-configured message text SHALL be applied without requiring a Mobile Application code change.

*End* *Sponsor-Configurable Disconnection Copy* | **Hash**: 194894cf

---

## Section 4 — Participation Status Badge (refines GUI-p00076, URS §6.8.3)

# REQ-d00205: Badge State Machine And Variant Rendering

**Level**: dev | **Status**: Draft | **Implements**: REQ-p00076
**Refines**: GUI-p00076

## Rationale

The badge is a single component that selects a render variant based on the participant's status field. Centralizing variant selection in one component keeps the user profile screen free of conditional rendering chains and ensures every status transition produces a deterministic visual result.

## Assertions

A. The Participation Status Badge SHALL appear in the Clinical Trial section of the user profile screen.

B. When the Participant's status is `Linked - Awaiting Start` or `Trial Active`, the badge SHALL display the sponsor logo, the Participant's linking code, and the participant's join date and time.

C. When the Participant's status is `Disconnected`, the badge SHALL display a warning indicator, the current linking code, a connection-interrupted message, and an "Enter New Linking Code" action that navigates to the linking code entry screen.

D. When the Participant's status is `Not Participating`, the badge SHALL render in an inactive visual style and SHALL display the participation end date.

E. The badge SHALL include a link to the Clinical Trial Privacy Policy from the moment the Participant first links to the study, and the link SHALL remain available regardless of subsequent status changes.

F. The badge SHALL re-render automatically when the Participant's status changes, without requiring a navigation event or manual refresh.

G. The display of the sponsor logo when the Participant's status is `Not Participating` SHALL be controlled by a sponsor configuration parameter.

*End* *Badge State Machine And Variant Rendering* | **Hash**: 3e8edf40

---

## Section 5 — Incomplete Record Lock Warning (refines REQ-p05015, URS §6.8.4)

# REQ-d00206: Lock Warning Scheduling Job And Idempotency

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05015

## Rationale

The lock warning is fired once per record at a precise offset before the lock fires. Idempotency is essential — multiple notifications for the same record would be a defect. Per-record dispatch state is held in the `notifications` table itself: a row with `notification_type='reminder'`, `payload->>'reminder_kind'='lock_warning'`, and the originating `incomplete_record_id` in the payload acts as the proof that the warning has been emitted for that record.

## Assertions

A. A server-side scheduled job SHALL evaluate every Incomplete Record at least once per minute against the configured Lock Warning Offset.

B. When the elapsed time since the entry's last interaction reaches `Lock Threshold − Lock Warning Offset`, the job SHALL enqueue a Push Notification for the Participant.

C. The job SHALL NOT enqueue more than one lock-warning notification per Incomplete Record across all evaluations.

D. When the Participant completes or deletes an Incomplete Record before the Lock Warning Offset is reached, the job SHALL NOT enqueue the notification for that record.

E. The notification SHALL be persisted via the outbox sequencing defined in REQ-d00197.

F. Per-record dispatch state SHALL survive process restarts; the absence of the dispatched row in the `notifications` table SHALL be the sole criterion for "not yet dispatched".

G. The notification's `payload.action` SHALL be `lock_warning` and the `payload` SHALL contain the originating `incomplete_record_id`.

*End* *Lock Warning Scheduling Job And Idempotency* | **Hash**: 4da1fb77

---

# REQ-d00207: Lock Warning Configuration Slot

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05015, REQ-p70020

## Assertions

A. The platform SHALL expose a `Lock Warning Offset` configuration parameter per deployment.

B. The platform SHALL expose a `Lock Warning Notification Text` configuration parameter per deployment.

C. When the `Lock Warning Offset` is not configured, the scheduled job SHALL NOT dispatch any lock-warning notification.

D. When the configured `Lock Warning Offset` is greater than or equal to the configured Lock Threshold, the platform SHALL log a configuration error at startup and SHALL NOT dispatch any lock-warning notification.

E. The `Lock Warning Notification Text` SHALL be applied to the `title`/`body` of the notification at outbox-write time.

*End* *Lock Warning Configuration Slot* | **Hash**: b4d5ea6c

---

## Section 6 — Portal-Sent Questionnaire Notification (refines REQ-p05018, URS §6.8.6)

# REQ-d00208: Send Handler Trigger And Suppression

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05018

## Rationale

The send handler is the single trigger point for the Portal-Sent Questionnaire push. Suppression rules (already-submitted, called-back) are evaluated server-side at trigger time, not on the device. The notification carries only the opaque envelope id; the questionnaire content is fetched via the existing diary_server API.

## Assertions

A. When the Sponsor Portal successfully delivers a Portal-Sent Questionnaire to the Mobile Application, the System SHALL enqueue a Push Notification for the Participant via the outbox defined in REQ-d00197.

B. The System SHALL NOT enqueue a Push Notification for a Portal-Sent Questionnaire that has already been submitted by the Participant.

C. The System SHALL NOT enqueue a Push Notification for a Portal-Sent Questionnaire that has been called back by the Study Coordinator.

D. The notification's `notification_type` SHALL be `questionnaire_update` and the `payload.action` SHALL be `sent`.

E. The notification's `payload` SHALL contain the `questionnaire_instance_id` and `questionnaire_type`.

F. The Mobile Application SHALL receive the notification on next connectivity if it is offline at dispatch time, via the polling endpoint defined in REQ-d00195.

*End* *Send Handler Trigger And Suppression* | **Hash**: b0408dab

---

## Section 7 — Yesterday Entry Reminder (refines REQ-p05016, URS §6.8.7)

# REQ-d00209: Yesterday Reminder Daily Scheduling, Timezone-Aware

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05016

## Rationale

The Yesterday Entry Reminder fires at a sponsor-configured local time of day. "Local" means the participant's device timezone, not the server's. The server therefore needs the device timezone for every active participant. FCM token registration is the natural pickup point; the timezone travels with the registration call and is updated on subsequent registrations and on device timezone changes.

## Assertions

A. A server-side scheduled job SHALL evaluate every Participant once per calendar day at the configured Reminder Time.

B. The Reminder Time SHALL be evaluated against the Participant's device local timezone.

C. The "previous calendar day" SHALL be determined against the Participant's device local timezone.

D. The job SHALL enqueue at most one Yesterday Entry Reminder Notification per Participant per calendar day.

E. The Mobile Application SHALL communicate its device timezone to the diary_server during FCM token registration and on every subsequent timezone change.

F. The platform SHALL expose a `Yesterday Reminder Time` configuration parameter per deployment.

G. The notification's `notification_type` SHALL be `reminder` and `payload.action` SHALL be `yesterday_entry`.

H. The notification SHALL be persisted via the outbox sequencing defined in REQ-d00197.

*End* *Yesterday Reminder Daily Scheduling, Timezone-Aware* | **Hash**: 76700618

---

# REQ-d00210: Yesterday Reminder Suppression

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05016

## Assertions

A. The Yesterday Entry Reminder job SHALL skip any Participant for whom a Daily Status has been recorded for the previous calendar day.

B. The skip evaluation SHALL be performed at the moment the job evaluates the Participant, immediately before the outbox write.

*End* *Yesterday Reminder Suppression* | **Hash**: 2a548f43

---

## Section 8 — Ongoing Epistaxis Event Reminder (refines REQ-p05017, URS §6.8.8)

# REQ-d00211: Reminder Schedule Engine

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05017

## Rationale

Each interval in the Reminder Schedule is measured from the previous notification, not from a fixed start. The first interval is measured from the participant's most recent interaction. The engine tracks per-record state; the `notifications` table records each fire, and the schedule cursor advances by counting notifications already emitted for that record.

## Assertions

A. For each Incomplete Record of type Epistaxis Event, the System SHALL track the elapsed time since the Participant's most recent interaction with that record.

B. At each interval defined in the active Reminder Schedule, the System SHALL enqueue a Push Notification to the Participant via the outbox defined in REQ-d00197.

C. After the final interval in the active Reminder Schedule has elapsed, the System SHALL NOT enqueue further reminders for that record.

D. Each interval SHALL be measured from the time of the previous notification dispatch, with the first interval measured from the most recent Participant interaction.

E. Per-record dispatch state SHALL survive process restarts; the count of `reminder` notifications already emitted for the record SHALL be the cursor.

F. The notification's `notification_type` SHALL be `reminder` and `payload.action` SHALL be `epistaxis_ongoing`, with the originating `incomplete_record_id` in the payload.

*End* *Reminder Schedule Engine* | **Hash**: 073b9613

---

# REQ-d00212: Reset On Interaction And Termination

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05017

## Assertions

A. When the Participant interacts with an Incomplete Epistaxis Event record, the System SHALL reset the reminder schedule to the first interval for that record.

B. When an Incomplete Epistaxis Event record is completed, the System SHALL stop enqueueing reminders for that record.

C. When an Incomplete Epistaxis Event record is deleted, the System SHALL stop enqueueing reminders for that record.

D. Reset and termination SHALL take effect within one minute of the triggering action committing.

E. A reset SHALL be implemented as a marker that subsequent interval evaluations measure their offset from the reset time, not from the most recent prior dispatch.

*End* *Reset On Interaction And Termination* | **Hash**: baa702f5

---

# REQ-d00213: Sponsor Overrides Personal Schedule

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05017, REQ-p70020

## Assertions

A. The platform default Reminder Schedule SHALL be empty, resulting in no reminders being delivered.

B. The Mobile Application SHALL allow the Participant to configure a personal Reminder Schedule from application settings.

C. The platform SHALL expose a sponsor-configured Reminder Schedule per deployment.

D. When a sponsor-configured Reminder Schedule is in effect, the System SHALL apply the sponsor-configured schedule.

E. When a sponsor-configured Reminder Schedule is in effect, the System SHALL NOT apply the Participant's personal Reminder Schedule.

F. When no sponsor-configured Reminder Schedule is in effect, the System SHALL apply the Participant's personal Reminder Schedule.

G. When no sponsor-configured Reminder Schedule is in effect and the Participant has not configured a personal schedule, the System SHALL apply the empty default and no reminders SHALL fire.

*End* *Sponsor Overrides Personal Schedule* | **Hash**: e17d8a7a

---

## Section 9 — Historical Gap Reminder (refines REQ-p05019, URS §6.8.10)

# REQ-d00214: Gap Evaluation And Once-Per-Day Delivery

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05019

## Rationale

The Historical Gap Reminder addresses missing Daily Status entries on days older than yesterday. It runs at the configured Reminder Time once per day per participant; its existence is independent of the Yesterday Reminder.

## Assertions

A. A server-side scheduled job SHALL evaluate, once per calendar day at the configured Reminder Time, whether each Participant has any Historical Gap.

B. The evaluation SHALL be performed against the Participant's device local timezone.

C. When a Participant has at least one Historical Gap within the editable window, the System SHALL enqueue a Historical Gap Reminder via the outbox defined in REQ-d00197.

D. The System SHALL enqueue at most one Historical Gap Reminder per Participant per calendar day.

E. The notification's `notification_type` SHALL be `reminder` and `payload.action` SHALL be `historical_gap`.

*End* *Gap Evaluation And Once-Per-Day Delivery* | **Hash**: 24d69742

---

# REQ-d00215: Editable Window Exclusion

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05019

## Assertions

A. The Historical Gap evaluation SHALL exclude any calendar day for which the elapsed time since that day has exceeded the Lock Threshold.

B. In linked use mode, the Historical Gap evaluation SHALL exclude any calendar day before the trial start date.

C. The Historical Gap evaluation SHALL exclude the current calendar day and the previous calendar day from the gap set.

*End* *Editable Window Exclusion* | **Hash**: f113dd46

---

# REQ-d00216: Mode-Dependent Default And User Override

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05019

## Assertions

A. In personal use mode, the Historical Gap Reminder SHALL be disabled by default.

B. In personal use mode, the Mobile Application SHALL provide a setting that enables or disables the Historical Gap Reminder, persisted per-user.

C. In linked use mode, the Historical Gap Reminder SHALL be enabled by default.

D. In linked use mode, the personal-use enable/disable setting SHALL NOT apply.

*End* *Mode-Dependent Default And User Override* | **Hash**: e0f8501d

---

# REQ-d00217: Sponsor-Configurable Time And Text

**Level**: dev | **Status**: Draft | **Implements**: REQ-p05019, REQ-p70020

## Assertions

A. The platform SHALL expose a `Historical Gap Reminder Time` configuration parameter per deployment.

B. The platform SHALL expose a `Historical Gap Reminder Text` configuration parameter per deployment.

C. When no `Historical Gap Reminder Time` is configured, the System SHALL default to 09:00 in the Participant's local timezone.

D. When no `Historical Gap Reminder Text` is configured, the Mobile Application SHALL render a platform-default text supplied at compile time.

*End* *Sponsor-Configurable Time And Text* | **Hash**: c7a12215

---

# Sponsor Configuration — Callisto Deployment

> **Scope note**: The requirements in this section are sponsor-scoped to the Callisto deployment and are inserted in this platform spec as a temporary convenience. They MUST be lifted into a sponsor-isolated spec (`sponsor-content/callisto/spec/dev-notifications.md` or equivalent) when the sponsor-isolation convention is formalized for dev specs. They refine the Callisto-specific PRDs (`REQ-CAL-p00091`, `REQ-CAL-p00093`) authored in URS sections 6.8.5, 6.8.9, and 6.8.11.

---

# REQ-CAL-d00004: Callisto Lock Warning Notification Configuration

**Level**: dev | **Status**: Draft | **Implements**: REQ-CAL-p00091
**Refines**: REQ-d00207

## Assertions

A. The Callisto sponsor configuration SHALL set the `Lock Warning Offset` to 24 hours.

B. The Callisto sponsor configuration SHALL set the `Lock Warning Notification Text` to: "You have an incomplete nosebleed record from [date]. Complete or delete it within the next 24 hours, otherwise it will be permanently locked and you will not be able to change or remove it."

C. The configuration values SHALL be loaded by the platform mechanism defined in REQ-d00207.

*End* *Callisto Lock Warning Notification Configuration* | **Hash**: 00000000

---

# REQ-CAL-d00005: Callisto Yesterday Entry And Epistaxis Reminder Configuration

**Level**: dev | **Status**: Draft | **Implements**: REQ-CAL-p00093
**Refines**: REQ-d00209, REQ-d00213

## Assertions

A. The Callisto sponsor configuration SHALL set the `Yesterday Reminder Time` to 09:00 (24-hour format) in the Participant's local timezone.

B. The Callisto sponsor configuration SHALL set the sponsor-configured Reminder Schedule for the Ongoing Epistaxis Event Reminder to the ordered intervals: 5 minutes, 10 minutes, 15 minutes, 30 minutes.

C. The configuration values SHALL be loaded by the platform mechanisms defined in REQ-d00209 and REQ-d00213.

*End* *Callisto Yesterday Entry And Epistaxis Reminder Configuration* | **Hash**: 00000000

---

# REQ-CAL-d00006: Callisto Historical Gap Reminder Configuration

**Level**: dev | **Status**: Draft | **Implements**: REQ-CAL-p00093
**Refines**: REQ-d00217

## Rationale

The URS reuses the identifier `REQ-CAL-p00093` for both the Yesterday/Epistaxis configuration (URS §6.8.9) and the Historical Gap configuration (URS §6.8.11). This dev requirement refines the §6.8.11 scope of that PRD.

## Assertions

A. The Callisto sponsor configuration SHALL set the `Historical Gap Reminder Time` to 09:00 (24-hour format) in the Participant's local timezone.

B. The Callisto sponsor configuration SHALL set the `Historical Gap Reminder Text` to: "You have one or more days without a recorded entry. Tap to review and complete your diary."

C. The configuration values SHALL be loaded by the platform mechanism defined in REQ-d00217.

*End* *Callisto Historical Gap Reminder Configuration* | **Hash**: 00000000
