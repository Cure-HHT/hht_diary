# CUR-1311 — FCM Notification Implementation: Handoff Document

> **Audience**: the next agent or engineer continuing this work cold.
>
> **Linear ticket**: CUR-1311.
> **Branch**: `feature/cur-1311-fcm-notification-implementation`.
> **Primary plan**: [`docs/comms-implementation-plan.md`](./comms-implementation-plan.md) — read this first; everything below references it.
> **Primary spec**: [`spec/dev-notifications.md`](../spec/dev-notifications.md) (current) + [`spec/dev-notifications-v2.md`](../spec/dev-notifications-v2.md) (draft v2).

---

## TL;DR

We've shipped **14 commits** that take the FCM notification system from "broken audit trail + direct-FCM only" to "outbox-based envelope pattern fully wired on the server, all 8 handlers migrated behind feature flags, diary_server exposes the polling endpoints."

**What's left**:
- **P1B.5** — mobile polling integration (the biggest remaining chunk)
- **P1B.6** — flag-flip cleanup after production bake-in
- **Phase 1C** (Yesterday Reminder), **Phase 2** (reconciler), **Phase 3** (email + slack channels), **Phase 4** (IaC) — out of scope for this branch but unblocked

**Mobile app currently still uses the legacy direct-FCM dispatch + syncTasks reconciliation path.** It hasn't been told about the new `/api/v1/notifications` endpoints. Until P1B.5 lands, envelope-on patients write rows to the `notifications` table but the mobile never reads them.

---

## Branch state

```
6cbbe4c1  P1B.4    mount /api/v1/notifications endpoints on diary_server
67c4dcbf  P1B.3.4  route questionnaire_sent + questionnaire_deleted (REQ-d00182 suppression)
0ef11fb4  P1B.3.3  route questionnaire_unlocked + questionnaire_finalized
ef4cd7f7  P1B.3.2  route start_trial + reconnect
79a2465c  P1B.3.1  route mark_not_participating + reactivate (extracted helper)
fdaec5d2  P1B.2    route disconnectPatientHandler through OutboxWriter (PoC)
7f3c98a2  P1B.1    notifications table + PgNotificationRepository + UserContext.patient
8df3e823  P1A.4    portal_functions: route FCM through comms.FcmChannel
db76f959  P1A.3    comms: notifications domain protocol
75fc113d  P1A.2    comms: FCM channel + AdcClient + FcmMessage
9e20f494  P1A.1    bootstrap comms package: Channel, DispatchResult, PayloadGuard
f8b73f0d  S3.3     split APNS payload by user-visibility
be3ef0b6  S3.1     route FCM status/questionnaire pushes through syncTasks (mobile)
410c478e  S2       wire FCM senders + capture fcm_message_id in audit
f2f20389  S1       migration 010 — FCM_NOTIFICATION action type
```

**Test count at HEAD**:
| Suite | Tests | Status |
|---|---|---|
| `apps/common-dart/comms` | 60 | ✅ |
| `apps/sponsor-portal/portal_functions` | 650 (1 skipped) | ✅ |
| `apps/daily-diary/diary_functions` | 135 | ✅ |
| `apps/daily-diary/diary_server` | 33 | ✅ |
| `apps/daily-diary/clinical_diary` | 1126 (4 skipped) | ✅ |

---

## What's done by phase

### Stabilize phase (S1, S2, S3.1, S3.3) — runtime FCM works

| Phase | File(s) | Summary |
|---|---|---|
| **S1** `f2f20389` | `database/migrations/010_add_fcm_notification_action_type.sql` | Added `FCM_NOTIFICATION` to `admin_action_log_action_type_check_v3`. Before this, every FCM audit insert was silently dropped via CHECK constraint violation. |
| **S2** `410c478e` | `portal_functions/lib/src/patient_linking.dart`, `questionnaire.dart`, `diary_functions/lib/src/fcm_token.dart` | Wired `sendPatientStatusNotification` into disconnect / mark_not_participating / reactivate / reconnect / start_trial. `fcm_message_id` captured in `action_details` for every action. Cross-patient FCM token deactivation in fcm_token.dart. |
| **S3.1** `be3ef0b6` | `clinical_diary/lib/services/task_service.dart`, `notification_service.dart`, `enrollment_service.dart`, `screens/home_screen.dart` | Mobile dispatcher: new FCM types `patient_status_update`, `questionnaire_unlocked`, `questionnaire_finalized` route through `syncTasks` (envelope-pattern wake-up signal). `notParticipatingNotifier` added to EnrollmentService for reactive UI updates. |
| **S3.3** `f8b73f0d` | `portal_functions/lib/src/notification_service.dart` | APNS payload split — alerts get `priority=10` (no content-available); silent pushes get `priority=5 + content-available=1`. Fixes iOS throttling caused by the previous priority=10 + content-available combo. |

**S3.2 (BG handler outbox) was deferred** — polling makes it deferrable; documented in the plan.

### Phase 1A — `comms` package + portal refactor

`apps/common-dart/comms/` is a new pure-Dart shared library that holds the universal transport contract, FCM transport implementation, PHI guard, and the notifications domain protocol.

| Phase | Files | Summary |
|---|---|---|
| **1A.1** `9e20f494` | `comms/pubspec.yaml`, `lib/comms.dart`, `lib/src/channel.dart`, `dispatch_result.dart`, `compliance/payload_guard.dart` | `Channel<T>` + `ChannelMessage` interface; `DispatchResult` with 3 terminals (success / failure / unregisteredToken). `PayloadGuard` PHI checker (REQ-d00168) — built-in patterns for SubjectKey (with optional letter suffix) and email; sponsor-extensible `commonNamePatterns`; `testOnlyDisable` hard-fails in release builds. 18 tests. |
| **1A.2** `75fc113d` | `lib/src/channels/fcm/fcm_channel.dart`, `fcm_message.dart`, `adc_client.dart` | `FcmChannel` (HTTP v1 POST + 10s timeout + APNS split + UNREGISTERED detection on 404 and 400+errorCode); `FcmMessage` with explicit `userVisible: bool`; `AdcClient` with cached + rotated ADC bearer (1-hour lifetime, 5-min refresh buffer, injectable `authFactory` + `clock` for tests). 13 tests. |
| **1A.3** `db76f959` | `lib/src/notifications/{notification_type,envelope_status,envelope,repository,outbox_writer}.dart`, `server/{envelope_fetch,envelope_since}_handler.dart`, `client/envelope_fetcher.dart` | Envelope domain (3-value `NotificationType` enum, `EnvelopeStatus` state machine, `Envelope` data class with toJson/fromJson/copyWith, `NotificationRepository` interface). `OutboxWriter` (PHI-guard → insertPending → dispatch → markSent/markFailed; onUnregistered callback for dead-token cleanup). Shelf handler factories `envelopeFetchHandler` + `envelopeSinceHandler`. Mobile-side `EnvelopeFetcher` (pure-Dart HTTP client). 29 tests. |
| **1A.4** `8df3e823` | `portal_functions/lib/src/notification_service.dart` | `NotificationService` refactored to dispatch through `FcmChannel`. ~140 LOC of HTTP/ADC plumbing replaced with a `FcmChannel.dispatch` call. Public API (`sendQuestionnaireNotification`, `sendPatientStatusNotification`, etc.) unchanged. Verified end-to-end on local DB for patient 840-001 — same audit rows, byte-for-byte. |

**`comms` package layout**:
```
apps/common-dart/comms/
├── pubspec.yaml          (pure Dart; deps: meta, http, googleapis_auth, shelf, shelf_router)
├── analysis_options.yaml (mirrors trial_data_types)
├── lib/
│   ├── comms.dart        (barrel)
│   └── src/
│       ├── channel.dart
│       ├── dispatch_result.dart
│       ├── compliance/payload_guard.dart
│       ├── channels/fcm/{fcm_channel,fcm_message,adc_client}.dart
│       └── notifications/
│           ├── {notification_type,envelope_status,envelope,repository,outbox_writer}.dart
│           ├── server/{envelope_fetch,envelope_since}_handler.dart
│           └── client/envelope_fetcher.dart
└── test/
    ├── compliance/payload_guard_test.dart
    ├── channels/fcm/{fcm_channel,adc_client}_test.dart
    └── notifications/
        ├── _helpers/in_memory_repository.dart       (test fixture)
        ├── {envelope,outbox_writer}_test.dart
        ├── server/{envelope_fetch,envelope_since}_handler_test.dart
        └── client/envelope_fetcher_test.dart
```

### Phase 1B — Envelope outbox (parts 1–4)

| Phase | Files | Summary |
|---|---|---|
| **1B.1** `7f3c98a2` | `database/migrations/011_create_notifications_table.sql` (+rollback), `database/schema.sql`, `rls_policies.sql`, `portal_functions/lib/src/database.dart`, `notifications/pg_notification_repository.dart` | Migration 011 forward + rollback applied + verified on local DB. Adds `notification_type` enum, `notifications` table, `notifications_patient_pending_idx` partial index, 3 RLS policies, GRANTs. `UserContext.patient(patientId)` factory sets `app.current_patient_id` session var. `PgNotificationRepository` (writer side) uses `UserContext.service` for inserts/marks and `UserContext.patient` for reads. RLS scope verified end-to-end via psql. 10 unit tests. |
| **1B.2** `fdaec5d2` | `portal_functions/lib/src/notification_service.dart`, `patient_linking.dart`, `pubspec.yaml` | `disconnectPatientHandler` routed through `OutboxWriter` behind `FCM_USE_ENVELOPE_DISCONNECT`. `NotificationService` holds an `OutboxWriter` instance built in `initialize()`; `onUnregistered` callback deactivates `patient_fcm_tokens` rows. `NotificationConfig.fromEnvironmentOverride` for tests. `uuid: ^4.5.1` added. Verified on patient 999-001A-126. |
| **1B.3.1** `79a2465c` | `patient_linking.dart`: extracted helper, added 2 handlers | `_dispatchPatientStatusPush` helper extracted (avoids 3×50-LOC duplication). `markPatientNotParticipatingHandler` + `reactivatePatientHandler` migrated. Flags `FCM_USE_ENVELOPE_NOT_PARTICIPATING` + `FCM_USE_ENVELOPE_REACTIVATE`. Verified on 999-001A-123. |
| **1B.3.2** `ef4cd7f7` | `patient_linking.dart`: helper signature change + 2 handlers | Helper `newStatus` parameter → `extraPayload: Map<String, dynamic>` (so start_trial can pass `trial_started_at` instead of `new_status`). `reconnect` path in `generatePatientLinkingCodeHandler` + `startTrialHandler` migrated. Flags `FCM_USE_ENVELOPE_RECONNECT` + `FCM_USE_ENVELOPE_START_TRIAL`. |
| **1B.3.3** `0ef11fb4` | `questionnaire.dart`: new helper + 2 handlers | `_dispatchQuestionnairePush` helper added (covers all 4 questionnaire actions including silent delete). `_QuestionnaireAction` enum. `unlockQuestionnaireHandler` + `finalizeQuestionnaireHandler` migrated. Flags `FCM_USE_ENVELOPE_QUESTIONNAIRE_UNLOCKED` + `_FINALIZED`. |
| **1B.3.4** `67c4dcbf` | `questionnaire.dart`: last 2 handlers + suppression | `sendQuestionnaireHandler` (with REQ-d00182-B/C suppression check — SELECT submitted_at, deleted_at; skip envelope if either non-null) + `deleteQuestionnaireHandler` (silent push, `userVisible=false`). Flags `FCM_USE_ENVELOPE_QUESTIONNAIRE_SENT` + `_DELETED`. |
| **1B.4** `6cbbe4c1` | `diary_functions/lib/src/notifications/{diary_notification_repository,patient_resolver}.dart`, `database.dart` (test seam), `diary_server/lib/src/routes.dart` | `DiaryNotificationRepository` (read-only — writes throw `UnsupportedError`). `jwtPatientResolver` (auth bridge using existing JWT verification + the `app_users → patient_linking_codes → patients` join). Diary `Database` gains a `databaseQueryOverride` test seam mirroring portal_functions. `GET /api/v1/notifications/<id>` and `GET /api/v1/notifications` mounted via `comms`'s factories. 13 unit tests. |

---

## Architectural decisions worth knowing

1. **Per-handler feature flags** — every handler that fires FCM has its own `FCM_USE_ENVELOPE_*` env var, default `false`. Lets us roll out one handler at a time and revert per-handler without touching code. Once production has baked for 2 weeks (P1B.6), all flags flip to ON and the legacy path is deleted.

2. **One `OutboxWriter` per channel** — today there's only `OutboxWriter` for FCM. When email + Slack channels land in Phase 3, they'll be sibling writers (`EmailOutboxWriter`, `SlackOutboxWriter`) rather than one polymorphic writer. The `channel` field on `OutboxWriter` is typed `Channel<FcmMessage>` for this reason.

3. **`comms` is pure Dart** — no Flutter SDK dep. Server libraries (`portal_functions`, `diary_functions`) and the mobile app (`clinical_diary` — once P1B.5 wires it) can all depend on it. CI lint should enforce: `dart pub deps --style=tree | grep flutter` must not appear under `comms`.

4. **PHI guard fires at two layers** — once at the envelope level inside `OutboxWriter.send` (before `insertPending`), and once at the message level inside `FcmChannel.dispatch` (before the HTTP POST). Belt + suspenders; a tripped guard at either layer rejects the dispatch and never persists a row.

5. **Defense in depth on the read path** — every read query has `WHERE patient_id = @patientId` explicitly. RLS at the table level is an additional layer (portal-side reads run with `UserContext.patient` which sets `app.current_patient_id`; the `notifications_patient_select` policy enforces). On the diary side, the explicit predicate is currently the only active layer (diary's Database doesn't yet plumb UserContext) — documented in `diary_notification_repository.dart`'s class header.

6. **`message_id` in `notifications` carries the FCM resource name** (e.g. `projects/cure-hht-admin/messages/0:1700000000000000000`), or `'console-mode'` when FCM_CONSOLE_MODE is true. The `admin_action_log` audit rows surface the same value as `action_details.fcm_message_id` for back-compat, plus a new `action_details.notification_id` field linking to the `notifications` row.

7. **Silent vs. alert pushes** — driven by `Envelope.userVisible` (mirrored on `FcmMessage.userVisible`). The OutboxWriter strips title/body from the FcmMessage when `userVisible: false` so FcmChannel emits the priority-5 + content-available APNS payload. Only `questionnaire_deleted` is silent today.

8. **REQ-d00182 suppression in `sendQuestionnaireHandler`** is defensive — for a freshly INSERTed `questionnaire_instances` row, `submitted_at` and `deleted_at` are always NULL. The check is in place so a future cron-based resender that reaches this code with an existing instance id cannot dispatch a stale push.

---

## Important deviations from the plan worth flagging

### 1. `FCM_NOTIFICATION` audit row is skipped on the envelope path

The plan said P1B.2 should write BOTH `notifications` row AND a legacy `FCM_NOTIFICATION` admin_action_log row, with P1B.3 cleanup removing the legacy audit later. **In practice the envelope path never writes the `FCM_NOTIFICATION` audit row** — because it doesn't go through `NotificationService._sendFcmMessage` where `_logNotificationAudit` lives. The `notifications` table IS the send audit.

The action's primary audit row (e.g. `DISCONNECT_PATIENT`, `QUESTIONNAIRE_FINALIZED`) still fires and carries a `notification_id` field linking to the new table.

**Net effect**: P1B.3's planned "drop the FCM_NOTIFICATION audit writes" cleanup happened implicitly per-handler as each one migrated. P1B.6 doesn't need to revisit it.

### 2. `FcmMessage.userVisible` is explicit, not inferred from title

S3.3 inferred `userVisible` from `notificationTitle != null`. Phase 1A.2 made it an explicit constructor parameter on `FcmMessage` (matches the plan). The legacy `_sendFcmMessage` orchestrator still infers from title presence; once the legacy path is deleted in P1B.6, every call site explicitly chooses.

### 3. `payload.action` retains the legacy verbs

The spec (REQ-d00182-D) says `payload.action` should be `'sent'` for `questionnaire_sent`. The current implementation uses the legacy verbs `'new_task'`, `'remove_task'`, `'unlock_task'`, `'lock_task'` to keep the mobile dispatcher cases unchanged during rollout. Aligning to the spec is a follow-up coordinated with the P1B.5 mobile dispatcher work.

### 4. Diary side's `Database` doesn't yet have UserContext / RLS plumbing

Portal's `Database.executeWithContext` sets `app.current_patient_id` per call. Diary's `Database.execute` doesn't — the connection's PG role is whatever DB_USER is configured to. `DiaryNotificationRepository` relies on the explicit `WHERE patient_id` predicate. Documented in the class header; can be tightened later when diary needs UserContext for other features.

---

## What's left

### P1B.5 — Mobile polling integration (the big one)

**Goal**: replace the mobile's "trust FCM payload → mutate state" pattern with "FCM is a wake-up → fetch envelopes via /api/v1/notifications → apply each to local state."

**Per the plan** (`docs/comms-implementation-plan.md` lines 826–878):

**New file**: `apps/daily-diary/clinical_diary/lib/services/notification_poll_service.dart`

Uses `comms.EnvelopeFetcher`. Triggered by (REQ-d00169-F/G):
1. App startup / cold start (after auth init)
2. App resume from background (lifecycle observer)
3. FCM arrival in foreground or via background-handler outbox replay — treats `notification_id` in the FCM payload as a *hint to poll*, not as a navigation target
4. Periodic background poll while app foregrounded (every 60s; sponsor-configurable)
5. Pull-to-refresh on the main task list

**Cold-start sequence** (REQ-d00170 — always Main Screen, no deep-link):
```
1. Flutter init
2. Hive open + read auth state
3. If authenticated:
   a. Fetch patient context
   b. POLL /api/v1/notifications?since=<lastSeen>
   c. Apply incoming envelopes (mutate local state — task list, disconnection notice, badge)
4. Render Main Screen — always
```

`FirebaseMessaging.getInitialMessage()` is consumed only to confirm a poll is needed. `notification_id` is NEVER used for navigation. `payload.action` is used to mutate local state (e.g. `lock_task` for `questionnaire_finalized`).

**Cursor storage in Hive**:
| Key | Written | Read |
|---|---|---|
| `notification_lastSeen` | After each successful poll → set to `server_time` (or `next_cursor` from the response) | Each poll → sent as `since=` query param |
| `notification_recent_ids` | When an envelope is applied to local state — rolling 500-entry Set | Before applying — if id already present, skip (dedupe across FCM + polling, REQ-d00169-J) |

**Bootstrap** (first launch ever): `notification_lastSeen` is null → poll uses `since = now() - 30 days`. Bounded fetch; older notifications are stale in clinical-trial context.

**Lifecycle reset** (REQ-d00169-K): clear both Hive keys on:
- `AuthService.signOut()` — explicit logout
- `PatientLinkingService.unlink()` — patient unlinked (covered by `disconnect` and `mark_not_participating`)

**Dispatch on arrival** — map `Envelope.type` to existing services:
- `questionnaireUpdate` → `task_service.handleEnvelope(envelope)`
- `patientStatusUpdate` → `enrollment_service.handleEnvelope(envelope)`
- `reminder` → reminder service (TBD)

**Reactivity** (REQ-d00172): the existing reactive store in clinical_diary MUST propagate state changes within 1 second. No artificial debounce.

**Test plan**:
- Integration test on emulator — start app, insert a notifications row server-side, verify it appears within 60s without any FCM
- Dedupe test — deliver the same `notification_id` via both FCM and polling; verify the apply-handler runs exactly once
- Logout test — sign out + sign back in as a different patient; verify no leakage
- Cold-start test — tap a push from terminated state; verify app lands on Main Screen, NOT the questionnaire / disconnection screen

**Estimated effort**: 1–2 days.

### P1B.6 — Cleanup + retire legacy direct-FCM path

After 2 weeks of envelope-on in production with no incidents:
1. Flip every `FCM_USE_ENVELOPE_*` flag default to ON.
2. Delete the legacy direct-FCM branch in `_sendFcmMessage` (the `if (notificationTitle != null)` block).
3. Delete `NotificationService.sendQuestionnaireNotification` / `sendPatientStatusNotification` / `sendQuestionnaireDeletedNotification` / `sendQuestionnaireUnlockedNotification` / `sendQuestionnaireFinalizedNotification` — no callers after the flag flip since handlers go through `OutboxWriter`.
4. Delete the per-handler `useEnvelope*` flags on `NotificationConfig`.
5. Delete the `_dispatchPatientStatusPush` / `_dispatchQuestionnairePush` helpers' legacy branches.

**Estimated effort**: a few hours, gated on production observation.

### Phase 1C — Yesterday Reminder scheduler

Per plan lines 902–965. Cloud Scheduler → OIDC-authenticated cron route on portal_server. Schedule reminders for patients in their local timezone. Migration 012. Mobile-side timezone handling for the patient profile.

**Estimated effort**: 1–2 days. Independent of P1B.5/6.

### Phase 2 — Reconciler & observability

Per plan lines 967–977. Background job that re-attempts `pending` rows >5 min old. Dashboards for outbox lag, delivery rate, UNREGISTERED count.

### Phase 3 — `EmailChannel` + `SlackChannel`

Per plan lines 978–989. Reuse the `Channel<T>` abstraction; `comms` already has the per-channel folder structure.

### Phase 4 — Terraform / IaC

Per plan lines 990–998. The new GCP resources (FCM project bindings, Cloud Scheduler) need IaC.

---

## How to test what's there today

### Local Postgres for migrations
```bash
psql -h localhost -p 5432 -U muhammadumair -d postgres \
  -f database/migrations/011_create_notifications_table.sql
# Verify with:
psql -h localhost -p 5432 -U muhammadumair -d postgres -c "\d notifications"
```

### Run the server-side suites
```bash
# comms package
cd apps/common-dart/comms && dart test
# Expect: 60 tests passing

# portal_functions
cd apps/sponsor-portal/portal_functions && dart test
# Expect: 650 tests passing (1 skipped)

# diary_functions
cd apps/daily-diary/diary_functions && dart test
# Expect: 135 tests passing
```

### Run portal_server locally with all envelope flags ON
```bash
cd apps/sponsor-portal/portal_server
FCM_CONSOLE_MODE=true \
FCM_USE_ENVELOPE_DISCONNECT=true \
FCM_USE_ENVELOPE_NOT_PARTICIPATING=true \
FCM_USE_ENVELOPE_REACTIVATE=true \
FCM_USE_ENVELOPE_RECONNECT=true \
FCM_USE_ENVELOPE_START_TRIAL=true \
FCM_USE_ENVELOPE_QUESTIONNAIRE_SENT=true \
FCM_USE_ENVELOPE_QUESTIONNAIRE_DELETED=true \
FCM_USE_ENVELOPE_QUESTIONNAIRE_UNLOCKED=true \
FCM_USE_ENVELOPE_QUESTIONNAIRE_FINALIZED=true \
tool/run_local.sh
```

Trigger any action from portal-ui (disconnect / mark_not_participating / reactivate / finalize / unlock / delete / send questionnaire / start_trial / reconnect via new linking code). Then check:

```sql
-- envelope rows for a patient
SELECT notification_id, notification_type, status, user_visible,
       message_id, jsonb_pretty(payload) AS payload, created_at, sent_at
FROM notifications
WHERE patient_id = '<patient_id>'
ORDER BY created_at DESC LIMIT 10;

-- action audit rows now carry notification_id
SELECT created_at, action_type,
       action_details->'fcm_message_id' AS fcm_id,
       action_details->'notification_id' AS env_id
FROM admin_action_log
WHERE target_resource LIKE '%<patient_id>%'
ORDER BY created_at DESC LIMIT 10;
```

### Run diary_server locally and hit the new endpoints
```bash
cd apps/daily-diary/diary_server
tool/run_local.sh
```

```bash
# Need a JWT for a linked patient — pull from the local diary_server's link flow

# Poll since beginning of today
curl -s -H "Authorization: Bearer <jwt>" \
  "http://localhost:8080/api/v1/notifications?since=2026-05-08T00:00:00Z&limit=50" | jq

# Fetch a single envelope (and idempotently mark it delivered)
curl -s -H "Authorization: Bearer <jwt>" \
  "http://localhost:8080/api/v1/notifications/<env-id>" | jq
# Run twice → check that notifications.delivered_at is set on the FIRST call
# but NOT bumped on the second
```

### RLS sanity check (psql, no app code)
```sql
-- Insert a test row (superuser bypasses RLS for setup)
INSERT INTO notifications (
  patient_id, notification_type, title, body, user_visible, payload, status
) VALUES (
  '840-001', 'patient_status_update', 'Account Disconnected',
  'Your account has been disconnected.', true,
  '{"action": "disconnect"}'::jsonb, 'pending'
);

-- As authenticated role with correct patient context → see 1 row
SET ROLE authenticated;
SELECT set_config('app.current_patient_id', '840-001', false);
SELECT count(*) FROM notifications WHERE patient_id = '840-001';
-- Expect: 1

-- Wrong patient context → see 0 rows (RLS strips it)
SELECT set_config('app.current_patient_id', '999-999-999', false);
SELECT count(*) FROM notifications WHERE patient_id = '840-001';
-- Expect: 0

-- Cleanup
RESET ROLE;
DELETE FROM notifications WHERE patient_id = '840-001';
```

---

## Files map — where things live

### New code

| File | Phase | Purpose |
|---|---|---|
| `database/migrations/011_create_notifications_table.sql` | 1B.1 | Forward migration |
| `database/migrations/rollback/011_rollback.sql` | 1B.1 | Rollback |
| `apps/common-dart/comms/**` | 1A.1–3 | Shared transport + domain library |
| `apps/sponsor-portal/portal_functions/lib/src/notifications/pg_notification_repository.dart` | 1B.1 | Writer-side repo (Postgres) |
| `apps/daily-diary/diary_functions/lib/src/notifications/diary_notification_repository.dart` | 1B.4 | Read-only repo for diary |
| `apps/daily-diary/diary_functions/lib/src/notifications/patient_resolver.dart` | 1B.4 | JWT → patient_id bridge |
| `docs/comms-implementation-plan.md` | (pre-existing) | Source of truth plan |
| `spec/dev-notifications.md` | (pre-existing) | Requirements spec |
| `spec/dev-notifications-v2.md` | (pre-existing) | Draft v2 spec |

### Modified code

| File | Phase | Change |
|---|---|---|
| `database/schema.sql` | 1B.1 | Greenfield: `notifications` table + index + RLS enable |
| `database/rls_policies.sql` | 1B.1 | Greenfield: 3 RLS policies + GRANTs |
| `apps/sponsor-portal/portal_functions/lib/src/database.dart` | 1B.1 | +`UserContext.patient` + `app.current_patient_id` wiring |
| `apps/sponsor-portal/portal_functions/lib/src/notification_service.dart` | 1A.4, 1B.2–3 | FcmChannel refactor + OutboxWriter holder + 10 per-handler flags + onUnregistered |
| `apps/sponsor-portal/portal_functions/lib/src/patient_linking.dart` | 1B.2–3 | `_dispatchPatientStatusPush` helper + 5 handler retrofits (disconnect, not_participating, reactivate, reconnect, start_trial) |
| `apps/sponsor-portal/portal_functions/lib/src/questionnaire.dart` | 1B.3 | `_dispatchQuestionnairePush` helper + `_QuestionnaireAction` enum + 4 handler retrofits + REQ-d00182 suppression |
| `apps/sponsor-portal/portal_functions/pubspec.yaml` | 1A.4, 1B.2 | +comms, +uuid |
| `apps/daily-diary/diary_functions/lib/src/database.dart` | 1B.4 | +`databaseQueryOverride` test seam |
| `apps/daily-diary/diary_functions/lib/diary_functions.dart` | 1B.4 | Exports new symbols |
| `apps/daily-diary/diary_functions/pubspec.yaml` | 1B.4 | +comms, +meta |
| `apps/daily-diary/diary_server/lib/src/routes.dart` | 1B.4 | Mount `/api/v1/notifications/<id>` + `/api/v1/notifications` |
| `apps/daily-diary/diary_server/pubspec.yaml` | 1B.4 | +comms |
| `apps/daily-diary/clinical_diary/lib/services/task_service.dart` | S3.1 | Dispatcher routes new FCM types through syncTasks |
| `apps/daily-diary/clinical_diary/lib/services/notification_service.dart` | S3.1 | (mobile-side dispatcher — DO NOT confuse with portal-side) |
| `apps/daily-diary/clinical_diary/lib/services/enrollment_service.dart` | S3.1 | +`notParticipatingNotifier` |
| `apps/daily-diary/clinical_diary/lib/screens/home_screen.dart` | S3.1 | Listens to `notParticipatingNotifier`; resets feature flags reactively |
| `apps/daily-diary/clinical_diary/lib/main.dart` | S3.1 | Passes `_enrollmentService` to TaskService |
| `database/migrations/010_add_fcm_notification_action_type.sql` | S1 | (already committed at branch start) |
| `database/migrations/rollback/010_rollback.sql` | S1 | (already committed) |

### Env flag matrix (current state — all flags default `false`)

```
FCM_CONSOLE_MODE                       (existing — logs intent without dispatching)
FCM_ENABLED                            (existing)
FCM_PROJECT_ID                         (existing — default 'cure-hht-admin')
FCM_USE_ENVELOPE_DISCONNECT            (1B.2)
FCM_USE_ENVELOPE_NOT_PARTICIPATING     (1B.3.1)
FCM_USE_ENVELOPE_REACTIVATE            (1B.3.1)
FCM_USE_ENVELOPE_RECONNECT             (1B.3.2)
FCM_USE_ENVELOPE_START_TRIAL           (1B.3.2)
FCM_USE_ENVELOPE_QUESTIONNAIRE_SENT    (1B.3.4)
FCM_USE_ENVELOPE_QUESTIONNAIRE_DELETED (1B.3.4)
FCM_USE_ENVELOPE_QUESTIONNAIRE_UNLOCKED (1B.3.3)
FCM_USE_ENVELOPE_QUESTIONNAIRE_FINALIZED (1B.3.3)
```

---

## Key things the next agent should NOT do

1. **Don't push to production** without coordinating per-flag rollout. The flags exist precisely so each handler can be flipped independently and observed before the next.

2. **Don't delete the legacy direct-FCM path yet** — that's P1B.6 after production bake-in.

3. **Don't change `payload.action` values** without coordinating with the mobile dispatcher (S3.1 cases in `task_service.dart`). The current values (`new_task`, `remove_task`, etc.) are what S3.1's mobile dispatcher expects. Changing them to spec-compliant (`sent`, `deleted`, etc.) needs to happen alongside the mobile dispatcher update in P1B.5.

4. **Don't bypass `PayloadGuard.testOnlyDisable` in production code** — it hard-fails with `StateError` in `--release` builds (REQ-d00168-H), and is `@visibleForTesting`. If a real notification trips the guard, the title/body/payload contents need to be fixed, not the guard.

5. **Don't add new envelope writers without a feature flag** — the per-handler flag pattern is the safety net. New handlers should follow the existing helper pattern (`_dispatchPatientStatusPush` or `_dispatchQuestionnairePush`).

6. **Don't change `notifications.notification_type` enum values** — they're the wire vocabulary in `comms.NotificationType.wire`. A rename requires a migration + a mobile rollout coordinated with the server.

---

## Reading order for getting up to speed

1. **This document** (you are here).
2. [`docs/comms-implementation-plan.md`](./comms-implementation-plan.md) — the master plan. Particularly the "Architectural decisions", "The `comms` package", and "Phase 1B" sections.
3. [`spec/dev-notifications.md`](../spec/dev-notifications.md) — the REQs the implementation implements (especially REQ-d00167, REQ-d00168, REQ-d00169, REQ-d00170, REQ-d00172, REQ-d00182).
4. Walk the commits in order — each commit message is self-contained and explains what changed and why.
5. Skim `apps/common-dart/comms/lib/comms.dart` (the barrel) to see the public API surface.
6. Open `apps/sponsor-portal/portal_functions/lib/src/patient_linking.dart` and find `_dispatchPatientStatusPush` — that's the pattern every status handler uses.
7. Open `apps/sponsor-portal/portal_functions/lib/src/questionnaire.dart` and find `_dispatchQuestionnairePush` — that's the pattern every questionnaire handler uses.
8. Open `apps/daily-diary/diary_server/lib/src/routes.dart` to see how the diary endpoints are mounted.
9. For P1B.5: open `apps/daily-diary/clinical_diary/lib/services/task_service.dart` to see the current FCM dispatcher (`handleFcmMessage`), and `apps/daily-diary/clinical_diary/lib/main.dart` around `_initializeNotifications` to see where the new poll service would be wired.

---

## Suggested next step

**Start P1B.5.** It's the natural continuation, the biggest remaining piece, and the one that lights up the mobile-side payoff of everything we built. The plan doc has the detailed spec; the section above summarizes it.

The branch is in a good state to push and open a draft PR for the work shipped so far (Phase 1A + Phase 1B.1–4), or to keep going on the same branch until 1B.5 lands and ship one big PR. Either is reasonable.
