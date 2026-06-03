# FCM Notification — Implementation Plan

> **📍 Update (2026-05-07):** The package portion of this plan has been revised. The `apps/common-dart/fcm_notifications/` package described in P1.1+ has been **replaced** by a generic `apps/common-dart/comms/` package that hosts an `FcmChannel` today and will grow `EmailChannel` / `SlackChannel` later.
>
> The S1 + S2 stabilize work executed in this document is correct as-is and has shipped on `feature/cur-826-fcm-stabilize`. The Phase 1+ ticket sequencing (P1.1 onward) has been re-planned in [docs/fcm-next-phase-plan.md](./fcm-next-phase-plan.md) with updated package layout, an extra Phase 1A for the package extraction refactor, and Phase 1B for the envelope work.
>
> Whenever this document references `fcm_notifications` paths or the package structure, refer to `fcm-next-phase-plan.md` for the current shape. The phasing/test/rollout intent is otherwise unchanged.

**Companion doc to `docs/fcm-notification-redesign-plan.md`.** That doc describes the architecture and the "what." This doc describes the "how": ticket-by-ticket execution, file changes, testing strategy at every layer, local verification steps, and rollout playbook.

Read the redesign doc first if you haven't — this plan assumes you understand the envelope pattern, status-change matrix, and the `notifications` schema.

## How to use this doc

- Each phase below has: **goals**, **tickets**, **files touched**, **test plan**, **local verification**, **acceptance criteria**, **rollout**.
- **Tickets** are sized for a single PR each. Each gets a CUR-XXX in Linear and follows the project's `[CUR-XXX]` PR-title convention.
- **Files touched** lists exact paths so reviewers can pre-load context.
- **Test plan** distinguishes unit / integration / e2e per ticket.
- **Local verification** is a copy-pasteable checklist a developer runs before opening the PR.
- **Acceptance criteria** is the binary "is this done?" checklist for review.

## Phase summary

| Phase | What | Estimated days | Risk |
|---|---|---|---|
| **0** | IAM grant on `cure-hht-admin` | 5 min | Low — already done in qa |
| **Stabilize** | Critical-bug PR set against current architecture | 2-3 | Medium — touches prod handlers |
| **1** | Envelope architecture in new package | 5-7 | High — biggest refactor |
| **2** | Mobile polling on resume | 1 | Low — mobile only |
| **3** | Terraform + UNREGISTERED + alerting | 1 | Low — infra hardening |

Phases ship in order. Phase 2 cannot start until Phase 1 schema is live, because polling reads from the new `notifications` table.

---

# Phase 0 — IAM grant

**Status**: ✅ Done in callisto4-qa (2026-05-06). Repeat for every other sponsor-env that uses FCM.

**For each remaining sponsor-env**:

1. Identify the Compute SA: `<PROJECT_NUMBER>-compute@developer.gserviceaccount.com`
2. Switch GCP project picker to `cure-hht-admin`
3. IAM → Grant access → role `Firebase Cloud Messaging API Admin`
4. Verify via test send: trigger a notification from portal UI for a test participant, look for `FCM sent` in Cloud Logging.

**See** `docs/cross-project-iam-runbook.md` Section 1 for the full procedure.

---

# Stabilize-current-FCM PR set

**Goal**: ship critical bugs against the current architecture. Don't wait for Phase 1 — the audit gap, missing notifications, and token-sharing bug are FDA-relevant or user-visible **today**.

Three independent PRs. Ship in order; PR S1 is zero-risk and unblocks audit completeness immediately.

## Ticket S1 — Migration: add `'FCM_NOTIFICATION'` to audit constraint

Closes Issue #26 / Fix A.

### Files touched
- `database/migrations/010_add_fcm_notification_action_type.sql` (new)
- `database/migrations/rollback/010_rollback.sql` (new)
- `database/schema.sql` (constraint definition for greenfield deploys)

### Implementation
Follow the exact pattern of `migrations/007_questionnaire_audit_log.sql`:

```sql
BEGIN;
ALTER TABLE admin_action_log
  ADD CONSTRAINT admin_action_log_action_type_check_v3
  CHECK (action_type IN (
    -- ... existing values from v2 ...
    'FCM_NOTIFICATION'
  )) NOT VALID;
ALTER TABLE admin_action_log
  DROP CONSTRAINT admin_action_log_action_type_check_v2;
COMMIT;

ALTER TABLE admin_action_log
  VALIDATE CONSTRAINT admin_action_log_action_type_check_v3;
```

### Test plan
- **Unit (squawk)**: ensure CI passes — Squawk should accept `NOT VALID` + `VALIDATE` pattern.
- **Local**: apply migration to fresh DB; insert a row with `action_type='FCM_NOTIFICATION'`, expect success.
- **Verification SQL**:
  ```sql
  INSERT INTO admin_action_log (admin_id, action_type, target_resource, action_details, justification, requires_review)
  VALUES ('test', 'FCM_NOTIFICATION', 'patient:test', '{}'::jsonb, 'test', false);
  -- expect: INSERT 0 1 (no constraint violation)
  ```

### Local verification

```bash
# 1. Reset local DB
docker compose -f tools/dev-env/docker-compose.db.yml up -d
./apps/sponsor-portal/tool/reset_local_db.sh --force

# 2. Apply the new migration
docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal \
  < database/migrations/010_add_fcm_notification_action_type.sql

# 3. Verify constraint
docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal -c "
  SELECT conname FROM pg_constraint
  WHERE conname LIKE 'admin_action_log_action_type_check%';
"
# Expected: only 'admin_action_log_action_type_check_v3'

# 4. Trigger a test FCM notification (console mode), confirm audit row writes
FCM_CONSOLE_MODE=true ./apps/sponsor-portal/portal_server/tool/run_local.sh
./apps/sponsor-portal/tool/testNotification.sh

docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal -c "
  SELECT action_type, COUNT(*) FROM admin_action_log
  WHERE action_type = 'FCM_NOTIFICATION'
  GROUP BY action_type;
"
# Expected: 1 row with FCM_NOTIFICATION
```

### Acceptance criteria
- [ ] Migration file passes Squawk in CI
- [ ] Rollback file applies cleanly on a DB with the new constraint
- [ ] After applying, a manual INSERT with `action_type='FCM_NOTIFICATION'` succeeds
- [ ] After applying, the existing `notification_service.dart`'s `_logNotificationAudit` no longer logs `FCM failed to log notification audit` errors
- [ ] `database/schema.sql` updated to match (greenfield deploys get the right constraint)

### Rollout
- Deploy to dev → qa → uat → prod in sequence
- Monitor Cloud Logging for `FCM failed to log notification audit` errors after each — should drop to zero
- This migration is **zero-downtime** because of the `NOT VALID` + `VALIDATE` pattern (no row scan, no lock)

---

## Ticket S2 — Server-side: status-change notifications + token deactivation + opaque IDs

Closes Issues #1, #2, #4, #27 (server side), #11, #12.

### Files touched
- `apps/sponsor-portal/portal_functions/lib/src/notification_service.dart` — new helper for synchronous send + send-then-deactivate ordering; HTTP timeout
- `apps/sponsor-portal/portal_functions/lib/src/patient_linking.dart`
  - `disconnectPatientHandler` — send `patient_disconnected` → deactivate tokens
  - `markPatientNotParticipatingHandler` — send `patient_not_participating` → deactivate
  - `generatePatientLinkingCodeHandler` (reconnect path) — send `patient_reconnected`
  - `reactivatePatientHandler` — send `patient_reactivated`
  - `startTrialHandler` — replace `'trial-$patientId'` with opaque `gen_random_uuid()` (Issue #4)
- `apps/sponsor-portal/portal_functions/lib/src/questionnaire.dart`
  - `finalizeQuestionnaireHandler` — send `questionnaire_finalized` notification, capture `fcm_message_id` in audit
  - `deleteQuestionnaireHandler`, `unlockQuestionnaireHandler` — capture `fcm_message_id` in audit (Issue #12)
- `apps/daily-diary/diary_functions/lib/src/fcm_token.dart` — when registering a token, also `UPDATE patient_fcm_tokens SET is_active=false WHERE fcm_token=$1 AND patient_id != $2` (Issue #1)

### Implementation notes
- Stay on the existing `NotificationService.sendQuestionnaireNotification` API for now. Add new methods: `sendDisconnectNotification`, `sendReconnectNotification`, etc. Phase 1 will collapse all this into the envelope pattern.
- **Send-then-deactivate ordering**: in disconnect/not-participating, `await sendNotification(...)` BEFORE the `UPDATE patient_fcm_tokens SET is_active=false`. If FCM fails, log it but proceed with deactivation — the patient will discover their state on next sync.
- **HTTP timeout**: add `.timeout(Duration(seconds: 10))` to `_httpClient!.post(...)` in `notification_service.dart:330`. On timeout, throw and let the caller handle as a `failed` send.
- **Token uniqueness fix** (Issue #1): in `registerFcmTokenHandler` (`fcm_token.dart`), before insert, deactivate any other participant's row with the same fcm_token:
  ```sql
  UPDATE patient_fcm_tokens
     SET is_active = false, updated_at = now()
   WHERE fcm_token = @fcmToken
     AND patient_id != @patientId
     AND is_active = true;
  ```

### Test plan
- **Unit**: each notification method has a test that mocks the HTTP client and asserts: correct URL, correct payload shape, audit row written.
- **Integration** (server-only, docker-compose): `testNotification.sh`-style script for each new notification trigger:
  - Trigger disconnect on a test patient → verify FCM payload was logged in console mode + audit row created + `patient_fcm_tokens` is_active flipped to false
  - Same for not-participating, reconnect, reactivate, finalize
- **Manual** (qa): trigger from portal UI, verify Cloud Logs show `FCM sent` for each notification type

### Local verification

```bash
# 1. Start local stack
docker compose -f tools/dev-env/docker-compose.db.yml up -d
docker compose -f tools/dev-env/docker-compose.firebase.yml up -d
FCM_CONSOLE_MODE=true ./apps/sponsor-portal/portal_server/tool/run_local.sh --reset

# 2. Seed test data: a participant + a fake FCM token
docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal <<'SQL'
-- assumes seed data ran via --reset
INSERT INTO patient_fcm_tokens (patient_id, fcm_token, platform, is_active)
VALUES ('999-001-001', 'test-token-1', 'android', true);
SQL

# 3. Trigger disconnect via API
./apps/sponsor-portal/tool/testNotification.sh --disconnect 999-001-001

# 4. Verify outcomes
docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal -c "
  SELECT patient_id, is_active, updated_at
  FROM patient_fcm_tokens
  WHERE patient_id = '999-001-001';
"
# Expected: is_active=false (deactivated AFTER notification)

docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal -c "
  SELECT action_type, action_details->>'message_type'
  FROM admin_action_log
  WHERE target_resource = 'patient:999-001-001'
  ORDER BY created_at DESC LIMIT 5;
"
# Expected: rows for FCM_NOTIFICATION (patient_disconnected) AND DISCONNECT_PATIENT
```

You'll need to extend `tool/testNotification.sh` to support `--disconnect`, `--not-participating`, etc. — that extension is part of this ticket.

### Acceptance criteria
- [ ] All 5 participant-status handlers send their respective FCM notification
- [ ] `finalizeQuestionnaireHandler` sends `questionnaire_finalized` with `end_event` in the FCM data when applicable
- [ ] All FCM-sending handlers capture `fcm_message_id` in their `admin_action_log` row
- [ ] Disconnect / not-participating: tokens deactivated AFTER FCM send (verified by sequence in DB)
- [ ] Token registration deactivates any other participant's row with the same fcm_token
- [ ] `'trial-$patientId'` no longer appears in any FCM payload
- [ ] HTTP timeout wraps every FCM call (10s)
- [ ] Unit tests cover each new send method
- [ ] Integration test in `testNotification.sh` covers each new trigger
- [ ] Manual smoke in qa: trigger each from portal UI, verify Cloud Logs

### Rollout
- Deploy to dev → qa, smoke each notification type
- Watch Cloud Logging for `FCM API error` and `FCM exception sending` — rate should not increase
- Promote to uat → prod with a 24h soak between

---

## Ticket S3 — Mobile: handlers for new types + background handler + iOS APS split

Closes Issues #3, #5, #6.

### Files touched
- `apps/daily-diary/clinical_diary/lib/services/task_service.dart` — `handleFcmMessage` adds `case` arms for the new notification types
- `apps/daily-diary/clinical_diary/lib/services/notification_service.dart` — `firebaseMessagingBackgroundHandler` does real work (creates task / clears banner / etc.) instead of `debugPrint` only
- `apps/sponsor-portal/portal_functions/lib/src/notification_service.dart` — split iOS APS payload by notification class:
  - User-visible (questionnaire_sent, etc.): `apns: { headers: { 'apns-priority': '10' }, payload: { aps: { alert: {...}, sound: 'default' } } }`
  - Data-only (questionnaire_deleted, etc.): `apns: { headers: { 'apns-priority': '5' }, payload: { aps: { 'content-available': 1 } } }`

### Implementation notes
- New mobile handlers needed for all the kinds added in S2: `patient_disconnected`, `patient_not_participating`, `patient_reconnected`, `patient_reactivated`, `questionnaire_finalized`. Plus `questionnaire_unlocked` and `trial_started` which were already being sent but not handled.
- **Background handler**: needs same dispatch logic as foreground. Refactor `_handleQuestionnaireSent` etc. into a top-level routing function that both foreground and background can call. Background can't access the `TaskService` instance (different isolate), so the handler reads/writes SharedPreferences directly to queue tasks for the next foreground.
- **iOS APS classification**: maintain a per-kind enum on the server: `userVisible | dataOnly`. Pick the right APS shape at send time.

### Test plan
- **Unit (mobile)**: test `handleFcmMessage` for every type. Assert correct side effects (task added/removed, banner triggered, etc.)
- **Integration (mobile)**: golden tests for full FCM message → task list state. Use the existing `fcmOnMessageStreamFactory` test seam in `clinical_diary_bootstrap.dart`.
- **Manual (qa, real device)**: send each notification type, verify the device behaves correctly in foreground / background / terminated states. iOS specifically — verify both user-visible (tray) and data-only (no tray, but processed) flows.

### Local verification

Mobile testing requires real Firebase + a connected device or emulator. Console-mode FCM doesn't work for the mobile side.

```bash
# Easiest: run mobile against deployed dev environment, trigger via deployed portal
cd apps/daily-diary/clinical_diary
flutter run --flavor dev -d <device-id>

# Then in another terminal, trigger via deployed-dev portal (browser).
# Watch the device's logcat / Console.app for FCM message handling.
```

### Acceptance criteria
- [ ] `TaskService.handleFcmMessage` has `case` arms for: `questionnaire_sent`, `questionnaire_deleted`, `questionnaire_unlocked`, `questionnaire_finalized`, `trial_started`, `patient_disconnected`, `patient_not_participating`, `patient_reconnected`, `patient_reactivated`
- [ ] Background handler creates tasks (via shared prefs queue) instead of just `debugPrint`
- [ ] iOS APS payload uses priority 10 for user-visible kinds, priority 5 + content-available for data-only
- [ ] Per-kind dedup: receiving the same FCM twice doesn't create two tasks
- [ ] Manual qa: every kind verified on iOS and Android

### Rollout
- Mobile changes go via app store. Coordinate with sponsor release cadence.
- Server APS split is backward-compatible; can ship in S2's deploy.

---

# Phase 1 — Envelope architecture in new package

**Goal**: introduce `notifications` table, opaque envelope IDs, and a compliance-safe sender. Establish the new architecture and migrate every callsite to use it.

This phase is the largest in the project. We split it across **6 PRs** to keep each reviewable.

## Ticket P1.1 — Bootstrap `apps/common-dart/fcm_notifications` package

### Files touched (all new)
- `apps/common-dart/fcm_notifications/pubspec.yaml`
- `apps/common-dart/fcm_notifications/analysis_options.yaml`
- `apps/common-dart/fcm_notifications/README.md`
- `apps/common-dart/fcm_notifications/lib/fcm_notifications.dart` — exports
- `apps/common-dart/fcm_notifications/lib/src/types/notification_type.dart` — enum
- `apps/common-dart/fcm_notifications/lib/src/types/envelope.dart` — Envelope class
- `apps/common-dart/fcm_notifications/lib/src/types/envelope_status.dart` — enum
- `apps/common-dart/fcm_notifications/lib/src/types/send_result.dart`
- `apps/common-dart/fcm_notifications/lib/src/repository/notification_repository.dart` — interface
- `apps/common-dart/fcm_notifications/lib/src/repository/fcm_token_repository.dart` — interface
- `apps/common-dart/fcm_notifications/lib/src/compliance/payload_guard.dart`
- `apps/common-dart/fcm_notifications/test/payload_guard_test.dart`

### Implementation notes
- No behavior yet beyond `PayloadGuard`. This PR is just the structural skeleton.
- `PayloadGuard.assertNoPhi(envelope)` — regex checks on `title`, `body`, and serialized `payload`. Reject patterns matching: SubjectKey format (`\d{3}-\d{3}-\d{3}`), email, common name patterns. Throw `PhiLeakException` if any match.
- Add to root workspace per the project's monorepo convention.

### Test plan
- **Unit**: `PayloadGuard` tests for accept and reject cases. Cover SubjectKey, email, names, dates of birth.
- **Build**: `dart analyze` on the package passes; `dart test` runs the suite.

### Local verification

```bash
cd apps/common-dart/fcm_notifications
dart pub get
dart analyze
dart test
```

### Acceptance criteria
- [ ] Package builds standalone
- [ ] Exports include all public types
- [ ] `PayloadGuard` tests cover the project's PHI patterns (SubjectKey is the most important)
- [ ] No imports from `apps/sponsor-portal/...` or `apps/daily-diary/...` (the package must not depend on consumers)

---

## Ticket P1.2 — Schema migration: `notifications` table + `patient_fcm_tokens` rework

### Files touched
- `database/migrations/011_notifications_and_token_rework.sql` (new)
- `database/migrations/rollback/011_rollback.sql` (new)
- `database/schema.sql` (sync the new objects for greenfield deploys)
- `database/rls_policies.sql` (RLS on `notifications`)

### Implementation
```sql
-- New enum type
CREATE TYPE notification_type AS ENUM (
  'questionnaire_update',
  'patient_status_update',
  'reminder'
);

-- New notifications table
CREATE TABLE notifications (
  notification_id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        text NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
  notification_type notification_type NOT NULL,
  title             text NOT NULL,
  body              text,
  payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  status            text NOT NULL DEFAULT 'pending',
  message_id        text,
  last_error        text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  sent_at           timestamptz,
  delivered_at      timestamptz
);

CREATE INDEX notifications_patient_created_idx
  ON notifications (patient_id, created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY notifications_service_all ON notifications
  FOR ALL TO service_role USING (true) WITH CHECK (true);
GRANT ALL ON notifications TO service_role;

-- patient_fcm_tokens rework: add device_id, fix CASCADE, drop old unique index
ALTER TABLE patient_fcm_tokens
  ADD COLUMN device_id text;

-- Backfill device_id for existing rows
UPDATE patient_fcm_tokens SET device_id = patient_id || '-' || platform
  WHERE device_id IS NULL;

ALTER TABLE patient_fcm_tokens
  ALTER COLUMN device_id SET NOT NULL;

-- Drop old unique index, add new one keyed on (patient_id, device_id)
DROP INDEX IF EXISTS idx_fcm_patient_platform_active;
CREATE UNIQUE INDEX CONCURRENTLY idx_fcm_patient_device_active
  ON patient_fcm_tokens (patient_id, device_id) WHERE is_active = true;

-- ON DELETE CASCADE on FK (drop and recreate)
ALTER TABLE patient_fcm_tokens
  DROP CONSTRAINT patient_fcm_tokens_patient_id_fkey,
  ADD CONSTRAINT patient_fcm_tokens_patient_id_fkey
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE;
```

### Test plan
- **Unit**: Squawk passes (uses `CONCURRENTLY` for index, `NOT VALID`/`VALIDATE` pattern where applicable).
- **Local**: apply migration on a DB with seeded `patient_fcm_tokens` rows; verify backfill didn't break anything.
- **Migration smoke**: insert a notification row with each `notification_type` enum value; verify constraints.

### Local verification
```bash
docker compose -f tools/dev-env/docker-compose.db.yml up -d
./apps/sponsor-portal/tool/reset_local_db.sh --force

# Apply migration
docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal \
  < database/migrations/011_notifications_and_token_rework.sql

# Smoke: each enum value
docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal <<'SQL'
INSERT INTO notifications (patient_id, notification_type, title, body, payload)
VALUES
  ('999-001-001', 'questionnaire_update', 'New', 'body', '{"action":"sent"}'::jsonb),
  ('999-001-001', 'patient_status_update', 'Disc', 'body', '{"action":"disconnected"}'::jsonb),
  ('999-001-001', 'reminder', 'Test', 'body', '{}'::jsonb);
SELECT notification_id, notification_type FROM notifications;
SQL
```

### Acceptance criteria
- [ ] Migration applies on fresh DB and on existing DB with rows
- [ ] Backfill correctly populates `device_id` for legacy rows
- [ ] Squawk passes
- [ ] Rollback script verified on a post-migration DB
- [ ] `database/schema.sql` updated to match

### Rollout
- Apply via the deploy-db job. The migration is **mostly backward compatible**: app code that reads `patient_fcm_tokens` continues to work because we kept all columns. The new `notifications` table is unused by old code.
- ON DELETE CASCADE change: small lock during constraint swap. Schedule for a low-traffic window.

---

## Ticket P1.3 — Sender + handlers in package

### Files touched (all new under the package)
- `apps/common-dart/fcm_notifications/lib/src/sender/fcm_sender.dart` — port `NotificationService` send logic, rebuilt around `Envelope`
- `apps/common-dart/fcm_notifications/lib/src/sender/adc_client.dart`
- `apps/common-dart/fcm_notifications/lib/src/handlers/envelope_fetch_handler.dart` — `GET /notifications/{id}`
- `apps/common-dart/fcm_notifications/lib/src/handlers/envelope_since_handler.dart` — `GET /notifications?since=`
- `apps/common-dart/fcm_notifications/lib/src/handlers/token_registration_handler.dart` — `POST /fcm-token`
- `apps/common-dart/fcm_notifications/lib/src/handlers/token_delete_handler.dart` — `DELETE /fcm-token` (Issue #8)
- `apps/common-dart/fcm_notifications/test/sender/fcm_sender_test.dart`
- `apps/common-dart/fcm_notifications/test/handlers/*_test.dart`

### Implementation notes
- `FcmSender.send(envelope, tokens)` — synchronous, no retry. On UNREGISTERED, calls back into `FcmTokenRepository.deactivate(token)`. Returns per-token result.
- Handlers return `shelf.Handler` parameterized by `(NotificationRepository, FcmTokenRepository, PatientResolver)`. The PatientResolver callback maps a JWT → patient_id, owned by the calling app.
- All four handlers are sponsor/server-agnostic.
- `delivered_at` update inside the fetch and since handlers — see redesign doc's "Delivery semantics" section.

### Test plan
- **Unit**: every handler has tests with a fake repo and fake patient resolver. Cover happy path, auth failure, cross-participant access attempt, idempotent `delivered_at`.
- **Unit**: `FcmSender` tests with mocked HTTP — happy path, 4xx, 5xx, UNREGISTERED → deactivation called, payload guard rejects PHI.

### Local verification
```bash
cd apps/common-dart/fcm_notifications
dart test
```

### Acceptance criteria
- [ ] Sender + 4 handlers implemented and unit-tested
- [ ] `PayloadGuard` is invoked before every send
- [ ] UNREGISTERED handling deactivates the offending token via repo
- [ ] HTTP timeout (10s) on FCM call
- [ ] No imports from sponsor-portal / daily-diary

---

## Ticket P1.4 — Postgres repositories + wire in to portal_functions and diary_functions

### Files touched
- `apps/sponsor-portal/portal_functions/lib/src/notification_repo_pg.dart` (new) — implements `NotificationRepository`
- `apps/sponsor-portal/portal_functions/lib/src/fcm_token_repo_pg.dart` (new) — implements `FcmTokenRepository`
- `apps/daily-diary/diary_functions/lib/src/notification_repo_pg.dart` (new) — same impl, used by diary's envelope-fetch handler
- `apps/daily-diary/diary_functions/lib/src/fcm_token_repo_pg.dart` (new)
- `apps/sponsor-portal/portal_server/lib/src/routes.dart` — register handlers from package
- `apps/daily-diary/diary_server/lib/src/routes.dart` — register handlers from package

### Implementation notes
- Repos are thin Postgres adapters. ~50 lines each. The bulk of the logic lives in the package.
- Routes register the new endpoints alongside existing ones. **Don't delete the old `/api/v1/user/fcm-token` route yet** — it stays until P1.6.
- New endpoints exposed by diary_server:
  - `GET /api/v1/notifications/{id}`
  - `GET /api/v1/notifications?since=`
  - `DELETE /api/v1/user/fcm-token`

### Test plan
- **Integration**: spin up the package handlers behind shelf, hit the new endpoints with curl, verify DB state.

### Local verification
```bash
# Build server with new package dep
cd apps/daily-diary/diary_server
dart pub get
./tool/run_local.sh

# Smoke each new endpoint with curl
TOKEN=$(./tool/get_test_jwt.sh)
PATIENT=999-001-001

# Insert a fake envelope directly
docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal <<SQL
INSERT INTO notifications (patient_id, notification_type, title, body, payload, status)
VALUES ('$PATIENT', 'questionnaire_update', 'Test', 'body',
        '{"action":"sent","questionnaire_instance_id":"abc"}'::jsonb, 'sent');
SQL

# Fetch the envelope
curl -H "Authorization: Bearer $TOKEN" http://localhost:8083/api/v1/notifications?since=2025-01-01

# Verify delivered_at populated
docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal -c "
  SELECT notification_id, delivered_at FROM notifications;
"
```

### Acceptance criteria
- [ ] Postgres repos implement the package interfaces correctly
- [ ] All four new endpoints respond correctly under the test JWT
- [ ] `delivered_at` is set idempotently
- [ ] Cross-participant fetch returns 403/404 (defense in depth)

---

## Ticket P1.5 — Migrate every send callsite to envelope pattern

### Files touched
- `apps/sponsor-portal/portal_functions/lib/src/questionnaire.dart` — 4 sites
- `apps/sponsor-portal/portal_functions/lib/src/patient_linking.dart` — 5 sites
- Helper: `apps/sponsor-portal/portal_functions/lib/src/notification_helpers.dart` (new) — convenience builders for each notification kind, e.g. `buildQuestionnaireSentEnvelope(patientId, instanceId, type)`

### Implementation notes
- Each callsite changes from:
  ```dart
  await NotificationService.instance.sendQuestionnaireNotification(
    fcmToken: fcmToken,
    questionnaireType: type,
    questionnaireInstanceId: id,
    patientId: patientId,
  );
  ```
  to:
  ```dart
  final envelope = buildQuestionnaireSentEnvelope(patientId, id, type);
  await notificationRepo.insert(envelope);
  final tokens = await tokenRepo.findActiveTokens(patientId);
  await fcmSender.send(envelope, tokens);
  ```
- For disconnect / not-participating: send first, then deactivate (already in S2, but now via the new repo).
- **Feature flag**: `USE_ENVELOPE_NOTIFICATIONS` env var. When false, use the old code path. Lets us deploy and test in dev/qa with the flag flipped, while prod stays on old code briefly.

### Test plan
- **Integration**: each handler test now exercises both old and new paths via the feature flag.
- **Manual**: deploy to dev with flag on, trigger every handler, verify envelope rows + FCM messages.

### Acceptance criteria
- [ ] All 9 send sites use the envelope pattern under the flag
- [ ] Feature flag works in both states
- [ ] Existing tests pass under both flag states
- [ ] One golden integration test per handler exercises the envelope path end-to-end

---

## Ticket P1.6 — Mobile receiver in package + FcmReceiver swap

### Files touched
- `apps/common-dart/fcm_notifications/lib/src/receiver/fcm_receiver.dart` (new)
- `apps/common-dart/fcm_notifications/lib/src/receiver/envelope_fetcher.dart` (new) — calls `GET /notifications/{id}`
- `apps/common-dart/fcm_notifications/lib/src/receiver/local_notifications.dart` (new) — wraps `flutter_local_notifications`
- `apps/daily-diary/clinical_diary/lib/services/notification_service.dart` — replace `MobileNotificationService` body with thin wrapper around package's `FcmReceiver`
- `apps/daily-diary/clinical_diary/lib/main.dart` — wire `FcmReceiver` instead of `MobileNotificationService`
- `apps/daily-diary/clinical_diary/lib/services/task_service.dart` — `handleEnvelope(Envelope envelope)` replaces `handleFcmMessage(Map data)`

### Implementation notes
- FcmReceiver subscribes to FCM, on each message extracts `notification_id`, calls `EnvelopeFetcher.fetch(id)`, routes by envelope's `notification_type` and `payload['action']`.
- Foreground / background / terminated all funnel through the same dispatch.
- `EnvelopeFetcher` uses the same JWT/baseURL pattern as existing API calls.
- **Coexistence period**: receiver also keeps the old data-key dispatch as a fallback if envelope fetch fails. Remove after P1.7.

### Test plan
- **Unit (mobile)**: `FcmReceiver` dispatch tests with fake fetcher, fake local notifications.
- **Manual (real device)**: send test FCM (via portal UI in deployed dev), verify the device fetches the envelope and shows the local notification.

### Acceptance criteria
- [ ] FcmReceiver in package, used by clinical_diary
- [ ] Foreground / background / terminated all fetch the envelope
- [ ] Local notification rendered with title/body from envelope
- [ ] Dispatch routes to correct handler based on envelope type + action

---

## Ticket P1.7 — Cutover and cleanup

### Files touched (mostly deletions)
- Delete `apps/sponsor-portal/portal_functions/lib/src/notification_service.dart` (logic moved to package)
- Delete `apps/daily-diary/diary_functions/lib/src/fcm_token.dart` (logic moved to package)
- Delete inline FCM call paths in `questionnaire.dart` / `patient_linking.dart` — only envelope path remains
- Remove the `_logNotificationAudit` write entirely (Issue #26 / Fix B) — `notifications` table now serves as audit
- Drop `'FCM_NOTIFICATION'` from `admin_action_log` constraint (new migration)
- Remove `USE_ENVELOPE_NOTIFICATIONS` feature flag from all callsites

### Implementation notes
- Only run this **after** P1.5 and P1.6 have been live in prod for at least a week with the flag on.
- Verify no callers reference the old API. CI search: `grep -r 'NotificationService.instance' apps/`.

### Acceptance criteria
- [ ] Old notification_service.dart deleted
- [ ] Old fcm_token.dart deleted
- [ ] No more `_logNotificationAudit` calls
- [ ] Feature flag removed
- [ ] Migration removes `FCM_NOTIFICATION` from constraint (no longer used)

---

# Phase 2 — Mobile polling

**Goal**: implement the `?since=` polling on the mobile so missed pushes are caught on app resume. This is now the **primary** reliability mechanism (no backend retries).

Single PR.

## Ticket P2.1 — Polling on resume + while-foregrounded

### Files touched
- `apps/daily-diary/clinical_diary/lib/services/notification_polling_service.dart` (new)
- `apps/daily-diary/clinical_diary/lib/main.dart` — register lifecycle observer to call poll on resume
- `apps/daily-diary/clinical_diary/lib/services/task_service.dart` — handle envelopes from polling identical to push

### Implementation notes
- Persist `lastSeen` (timestamptz) per-participant in `SharedPreferences`. Reset on logout.
- On resume: `GET /api/v1/notifications?since=<lastSeen>`. Update `lastSeen` to `max(lastSeen, max(envelopes.created_at))`.
- While foregrounded: `Timer.periodic(Duration(minutes: 1), poll)` — sponsor-configurable.
- Dedup by `notification_id` (a Set in memory of recently-rendered ids).
- Skip poll if `connectivity_plus` reports offline.
- Tests use the same trigger-factories pattern as existing `clinical_diary_bootstrap.dart`.

### Test plan
- **Unit**: PollingService with fake clock and fake API
- **Integration (mobile)**: resume lifecycle event triggers a poll
- **Manual (real device)**:
  1. Foreground app, deny FCM permission
  2. Trigger a notification from portal UI
  3. Open app — verify the notification appears via polling

### Local verification
Run mobile against deployed dev. Same approach as Ticket S3.

### Acceptance criteria
- [ ] Polls on app resume
- [ ] Polls every 60s while foregrounded (sponsor-configurable)
- [ ] No background timer (Apple/Android throttling concern)
- [ ] Dedup prevents duplicate task creation when push and poll deliver the same envelope
- [ ] `lastSeen` correctly resets on logout

### Rollout
- Mobile-only, app store update.

---

# Phase 3 — Terraform IAM + UNREGISTERED + alerting

**Goal**: codify the FCM IAM grant in Terraform, self-heal stale tokens, alert on FCM failure rate.

Single PR.

## Ticket P3.1 — Terraform IAM + UNREGISTERED handling + alerting

### Files touched
- `infrastructure/terraform/sponsor-envs/main.tf` — add `google_project_iam_member.run_sa_fcm_sender`:
  ```hcl
  resource "google_project_iam_member" "run_sa_fcm_sender" {
    project = "cure-hht-admin"
    role    = "roles/cloudmessaging.admin"
    member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
  }
  ```
- `apps/common-dart/fcm_notifications/lib/src/sender/fcm_sender.dart` — on FCM 404 with `UNREGISTERED`, call `tokenRepo.deactivate(fcmToken)`. Already in P1.3, but tighten and test.
- `infrastructure/terraform/modules/monitoring-alerts/main.tf` — alerting policy:
  - Metric: `custom.googleapis.com/fcm_notifications_total` filtered by `status=failed`
  - Condition: rate > 5% over 1h
  - Notification channel: existing on-call channel

### Test plan
- **Terraform plan**: verify the IAM resource shows up in plan output
- **Manual**: apply Terraform to one dev env, confirm IAM grant is in place via gcloud
- **UNREGISTERED test**: insert a known-bad token, trigger send, verify token is deactivated post-failure
- **Alerting test**: inject failed metric, verify alert fires (use Cloud Monitoring's "test alert" feature)

### Acceptance criteria
- [ ] Terraform applies cleanly to all sponsor-envs
- [ ] Existing manual IAM grants can be `terraform import`-ed
- [ ] UNREGISTERED handling has a test
- [ ] Alerting policy live in at least uat and prod

### Rollout
- Terraform apply per sponsor-env via `terraform apply -target=google_project_iam_member.run_sa_fcm_sender`
- For sponsors that already have manual grants: `terraform import` first, then apply (otherwise Terraform will error on "resource already exists")

---

# Cross-cutting — Testing infrastructure

## Test pyramid

```
                  ╱╲
                 ╱e2╲          Manual qa, real device
                ╱────╲
               ╱ Integ╲        Local stack: portal + diary + db + emulator
              ╱────────╲
             ╱   Unit   ╲      Per-package, per-handler
            ╱────────────╲
```

## Unit tests — package and per-server

- Package unit tests (`apps/common-dart/fcm_notifications/test/`) cover types, sender, handlers, payload guard, in isolation.
- Server unit tests cover the Postgres repo implementations and the wiring of handlers into routes.
- Mobile unit tests cover the receiver dispatch logic.

CI runs all on every PR.

## Integration tests — local docker stack

We have most of this already (`tools/dev-env/docker-compose.db.yml`, Firebase emulator). Extensions needed for this work:

- **Notification injection helper**: `tools/dev-env/inject_envelope.sh` — utility to insert a `notifications` row with given type/action/payload, used by tests.
- **`testNotification.sh` extensions**: add `--disconnect`, `--not-participating`, `--reconnect`, `--reactivate`, `--finalize` flags so each handler can be triggered locally.
- **Curl-driven endpoint tests**: small bash script `tools/test_notification_api.sh` that walks through token registration, envelope fetch, since-poll, and delete.

## E2E — manual qa with real device

For each phase, qa runs:
1. **Cold start**: device app freshly installed. Token registration works.
2. **Each notification kind in foreground**: notification renders, task state updates as expected.
3. **Each notification kind in background**: tray notification appears (if user-visible) or processed silently (if data-only); on tap, app opens to correct screen.
4. **Each notification kind from terminated**: app launches via tap, deep-links correctly.
5. **Polling fallback**: turn off FCM permission. Trigger notifications from portal UI. Open app — polled envelopes appear.
6. **Disconnect flow**: trigger disconnect. Verify push received, banner shown, tasks cleared, future pushes blocked.

## Local testing setup — quick reference

```bash
# Full local stack
docker compose -f tools/dev-env/docker-compose.db.yml up -d
docker compose -f tools/dev-env/docker-compose.firebase.yml up -d

# Reset DB and apply migrations including the new ones
./apps/sponsor-portal/tool/reset_local_db.sh --force

# Start servers in console mode (no real FCM, just logs payload)
FCM_CONSOLE_MODE=true ./apps/sponsor-portal/portal_server/tool/run_local.sh &
./apps/daily-diary/diary_server/tool/run_local.sh &

# Trigger a notification end-to-end (uses Firebase emulator for auth)
./apps/sponsor-portal/tool/testNotification.sh

# Verify in DB
docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal -c "
  SELECT notification_type, payload->>'action', status, created_at, sent_at
  FROM notifications
  ORDER BY created_at DESC LIMIT 10;
"
```

For testing **real FCM** (against `cure-hht-admin`, no emulator):
- Get gcloud ADC: `gcloud auth application-default login`
- Account needs `roles/cloudmessaging.admin` on `cure-hht-admin`
- Insert a real FCM token (from a real device) into `patient_fcm_tokens` for a test patient
- Run servers without `FCM_CONSOLE_MODE`
- Trigger from `testNotification.sh` — should see real push on device

For testing **mobile receiver** end-to-end:
- Mobile app must build against deployed dev environment (server URL, Firebase config)
- `flutter run --flavor dev`
- Use the deployed-dev portal UI (browser) to trigger notifications

# Cross-cutting — Rollout playbook

For every phase:

1. **Dev** — feature flag on (where applicable), watch logs for errors, verify smoke tests pass
2. **QA** — run the qa manual test plan; product validates UX
3. **UAT** — soak for 48h; watch FCM failure rate metric
4. **Prod** — deploy with feature flag off (where applicable). Flip flag on for one sponsor at a time. Soak 24h between sponsors. Watch alerts.

For **schema migrations specifically**:
- Apply via deploy-db job (NOT via app deploy)
- Pre-migration: snapshot the DB
- Post-migration: verify constraint / index / table state via the verification SQL embedded in each migration's `DO $$ ... $$` block

For **mobile** rollouts:
- Server changes ship first. Mobile changes ship in the next app store release. The package's coexistence period (P1.6) ensures old mobile clients still work after server cutover.

# Decisions still to make

- [ ] **Feature flag location**: env var (Doppler-managed) or DB-backed sponsor config? Env var is simpler; DB-backed allows per-sponsor flipping. Recommendation: env var; the cutover is a one-time event, not a permanent toggle.
- [ ] **Notification inbox UI**: do we surface `?since=` results as an in-app inbox? Out of scope for this work but informs whether we add `read_at` and badge counts in P1.2's schema. Recommendation: design schema with future inbox in mind (already done — the table supports it).
- [ ] **Per-sponsor FCM project isolation**: today, all sponsors share `cure-hht-admin` for FCM. If product wants stronger isolation, this becomes a much bigger project (separate Firebase projects per sponsor). Out of scope; tracked under Issue #21.
- [ ] **`reminder` enum value rollout**: included in the enum from day one but no triggers exist. Decide whether to ship the enum value pre-emptively (recommended — adding values later is `ALTER TYPE ADD VALUE`, but easier to ship now) or wait until the first reminder feature.
- [ ] **App version targeting**: does `app_version` in `patient_fcm_tokens` get used for anything (e.g. only send rich notifications to v ≥ X)? If not, decide explicitly that it's informational-only and document in the column comment. Else design the targeting now.

# Linear ticket structure

Per CLAUDE.md, every PR title needs `[CUR-XXX]`. Linear team: `ce8e0f87-a7d0-4c8b-9fce-86a63363d8fe`. Create one parent epic plus one ticket per ticket above:

- **Epic**: FCM Notification Redesign
  - **CUR-XXX**: Stabilize S1 — audit constraint migration
  - **CUR-XXX**: Stabilize S2 — server-side status notifications
  - **CUR-XXX**: Stabilize S3 — mobile handlers + iOS APS split
  - **CUR-XXX**: P1.1 — bootstrap fcm_notifications package
  - **CUR-XXX**: P1.2 — notifications schema migration
  - **CUR-XXX**: P1.3 — sender + handlers in package
  - **CUR-XXX**: P1.4 — postgres repos + wiring
  - **CUR-XXX**: P1.5 — migrate callsites (feature-flagged)
  - **CUR-XXX**: P1.6 — mobile receiver in package
  - **CUR-XXX**: P1.7 — cutover and cleanup
  - **CUR-XXX**: P2.1 — mobile polling
  - **CUR-XXX**: P3.1 — Terraform + UNREGISTERED + alerting

Each ticket links to the relevant **REQ-d** in `spec/dev-fcm-notifications.md` (to be written in P1.1; for now, S1–S3 reference existing REQ-CAL-p00082 and REQ-p00049).

# Related docs

- `docs/fcm-notification-redesign-plan.md` — architecture and design rationale
- `docs/fcm-notification-architecture.md` — current architecture as documented before redesign
- `docs/fcm-notification-backend-explained.md` — walkthrough of the current backend code
- `docs/cross-project-iam-runbook.md` — IAM grants for cure-hht-admin
