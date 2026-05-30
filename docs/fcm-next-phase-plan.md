# FCM Next-Phase Implementation Plan

**Status:** Stabilize PR set in progress on `feature/cur-826-fcm-stabilize` (S1 + S2 done). This document plans S3 (close-out Stabilize), Phase 1A (extract `comms` package), and Phase 1B (envelope pattern + polling).

**Linear:** CUR-826 (Stabilize), CUR-???? (Phase 1A), CUR-???? (Phase 1B) — to be claimed

## Architectural Decision: Unified `comms` package

`apps/common-dart/comms/` is a generic outbound-communications library that owns the **protocol**: how messages are shaped, how channels send them, how envelopes are stored on the wire, how mobile fetches them, and how PHI is guarded. It does NOT own database connections, JWT auth models, or sponsor-specific business logic.

- **Name:** `comms` (chosen over `messaging` to avoid colliding with "Firebase Cloud Messaging", and over `notifications` to avoid colliding with the DB table)
- **Today (Phase 1A):** ships with `FcmChannel` and the `notifications/` domain layer — handlers, repository interface, outbox writer, envelope types, PHI guard
- **Tomorrow (Phase 3):** `EmailChannel` + `SlackChannel` join `channels/`
- **Pure Dart:** no `firebase_messaging` or any other Flutter dependency, so server services can consume it without dragging the Flutter SDK along. Mobile FCM reception (the `firebase_messaging` subscriber) stays in `clinical_diary/`; the **dispatch logic** lives in the package as `client/envelope_fetcher.dart` so any future mobile app reuses it.

### Why this scope (the contract test)

> Anything that defines the contract goes in `comms`. Anything that wires the contract to a specific database, auth model, or sponsor stays in the app.

Concretely: if a future app (new sponsor portal, admin tool, secondary diary variant) wants to send or receive notifications, it should NOT have to redefine `NotificationType`, re-shape `Envelope`, or re-implement the `GET /notifications` handler. It should just:
1. Implement `NotificationRepository` against its DB
2. Provide a JWT-to-patient resolver
3. Mount the package's handler factories on its router
4. Call `OutboxWriter.send(envelope)` from its business logic

### Package layout (initial — Phase 1A bootstraps everything below)

```
apps/common-dart/comms/
├── pubspec.yaml
├── analysis_options.yaml
├── lib/
│   ├── comms.dart                              # public barrel
│   └── src/
│       ├── channel.dart                        # abstract Channel<T> + ChannelMessage
│       ├── dispatch_result.dart                # DispatchResult { success, messageId?, error? }
│       ├── compliance/
│       │   └── payload_guard.dart              # PHI checker, channel-agnostic
│       ├── channels/
│       │   └── fcm/
│       │       ├── fcm_channel.dart            # Channel<FcmMessage> impl
│       │       ├── fcm_message.dart            # FcmMessage data class
│       │       └── adc_client.dart             # ADC bearer rotation
│       └── notifications/                      # the domain protocol
│           ├── notification_type.dart          # 3-value enum: questionnaire_update | patient_status_update | reminder
│           ├── envelope.dart                   # Envelope data class with toJson/fromJson
│           ├── envelope_status.dart            # pending | sent | failed | delivered
│           ├── repository.dart                 # NotificationRepository INTERFACE
│           ├── outbox_writer.dart              # persist → dispatch → mark helper
│           ├── server/
│           │   ├── envelope_fetch_handler.dart # GET /notifications/{id} factory
│           │   └── envelope_since_handler.dart # GET /notifications?since= factory
│           └── client/
│               └── envelope_fetcher.dart       # pure-Dart HTTP fetcher for any consumer
└── test/
    ├── compliance/payload_guard_test.dart
    ├── channels/fcm/
    │   ├── fcm_channel_test.dart
    │   └── adc_client_test.dart
    └── notifications/
        ├── envelope_test.dart
        ├── outbox_writer_test.dart
        └── server/envelope_fetch_handler_test.dart
```

### Package layout (future — Phase 3, when email/slack join)

```
└── channels/
    ├── fcm/
    │   ├── fcm_channel.dart
    │   ├── fcm_message.dart
    │   └── adc_client.dart
    ├── email/
    │   ├── email_channel.dart
    │   ├── email_message.dart
    │   └── dwd_client.dart                     # domain-wide delegation auth
    └── slack/
        ├── slack_channel.dart
        ├── slack_message.dart
        └── slack_webhook_client.dart
```

### What goes IN `comms` (the contract)

| Component | Why it's in the package |
|-----------|-------------------------|
| `Channel<T>` + `DispatchResult` | Universal transport interface |
| `channels/fcm/`, future `channels/email/`, `channels/slack/` | Per-channel implementations — write once, every consumer dispatches the same way |
| `compliance/payload_guard.dart` | PHI safety must run identically everywhere — centralize it |
| `notifications/notification_type.dart` | The 3-value enum is the protocol vocabulary. If a new app uses a different enum, the polling API breaks. |
| `notifications/envelope.dart` + `envelope_status.dart` | The wire format that server stores and mobile consumes — `toJson` / `fromJson` lives in one place |
| `notifications/repository.dart` (interface only) | Defines what every consumer's notification storage must support |
| `notifications/outbox_writer.dart` | The "persist row → dispatch via channel → mark sent/failed" sequence. Same logic everywhere. |
| `notifications/server/*_handler.dart` | Shelf handler factories. Each takes `(repo, patientResolver)` and returns a mountable handler. New apps just mount them. |
| `notifications/client/envelope_fetcher.dart` | Pure-Dart HTTP fetcher (uses caller's `http.Client`). Reusable in any Dart/Flutter app. |

### What stays OUT of `comms` (genuinely app-specific)

| Component | Why it's app-specific |
|-----------|----------------------|
| Postgres impl of `NotificationRepository` | App owns its connection pool, RLS context, sponsor-specific schema decisions |
| JWT-to-patient resolver | Each sponsor's auth model differs (Identity Platform claims shape, role mapping) |
| Route registration / middleware | `router.get('/notifications/:id', envelopeFetchHandler(...))` — only the app knows its router and what middleware to apply |
| Mobile FCM **reception** (subscribes to `firebase_messaging`) | Depends on Flutter SDK; `comms` stays pure-Dart so server services can use it |
| Per-handler business logic ("when a questionnaire arrives, update the task list") | Sponsor-specific behavior |

### Key API

```dart
// === Channels ===

abstract class Channel<T extends ChannelMessage> {
  String get name;
  Future<DispatchResult> dispatch(T message);
}

class DispatchResult {
  final bool success;
  final String? messageId;
  final String? error;
  DispatchResult.success(this.messageId) : success = true, error = null;
  DispatchResult.failure(this.error) : success = false, messageId = null;
}

class FcmChannel implements Channel<FcmMessage> {
  FcmChannel({required this.projectId, this.consoleMode = false});
  Future<void> initialize();        // one-time ADC client setup
  @override
  Future<DispatchResult> dispatch(FcmMessage message);
}

class FcmMessage extends ChannelMessage {
  final String fcmToken;
  final Map<String, String> data;
  final String? notificationTitle;
  final String? notificationBody;
  final bool userVisible;           // splits APNS priority
}

// === Notifications domain ===

enum NotificationType { questionnaireUpdate, patientStatusUpdate, reminder }

class Envelope {
  final String notificationId;
  final String patientId;
  final NotificationType type;
  final String title;
  final String? body;
  final Map<String, dynamic> payload;
  final EnvelopeStatus status;
  final String? messageId;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? deliveredAt;

  Map<String, dynamic> toJson();
  factory Envelope.fromJson(Map<String, dynamic> json);
}

abstract class NotificationRepository {
  Future<void> insertPending(Envelope envelope);
  Future<Envelope?> findById(String id, {required String patientId});
  Future<List<Envelope>> findSince(DateTime since, {required String patientId});
  Future<void> markSent(String id, String messageId);
  Future<void> markFailed(String id, String error);
  Future<void> markDeliveredIfNull(List<String> ids, {required String patientId});
}

class OutboxWriter {
  OutboxWriter({required this.repo, required this.channel, this.guard});

  /// Write pending row, dispatch via channel, mark sent/failed.
  /// Returns the persisted notification_id even on dispatch failure.
  Future<String> send(Envelope envelope, {required String fcmToken});
}

// === Server-side handler factory (shelf) ===

Handler envelopeFetchHandler({
  required NotificationRepository repo,
  required Future<String> Function(Request) patientResolver,
});

// === Client-side fetcher (pure Dart) ===

class EnvelopeFetcher {
  EnvelopeFetcher({required this.httpClient, required this.baseUrl});
  Future<Envelope> fetchById(String id, {required String authHeader});
  Future<List<Envelope>> fetchSince(DateTime since, {required String authHeader});
}
```

**Each channel has its own message type** — `FcmMessage`, `EmailMessage`, `SlackMessage` are genuinely different shapes (you can't send an email to an FCM token). The unification is the `Channel<T>.dispatch()` interface, not a one-size-fits-all message format.

---

## Quick Status

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 0 — IAM grant on cure-hht-admin | ✅ Done | `roles/cloudmessaging.admin` granted to sponsor compute SA |
| S1 — Migration 010 (admin_action_log constraint) | ✅ Done | Applied locally + committed |
| S2 — Server senders for all status transitions | ✅ Done | 5 participant handlers + finalize wired; fcm_message_id captured in audit; cross-participant token uniqueness in diary_functions |
| S3 — Mobile dispatcher + BG handler | ⏳ Pending | This document |
| Phase 1A — Extract `comms` package (FCM only) | ⏳ Pending | Pure refactor, no behavior change |
| Phase 1B — Envelope pattern + polling | ⏳ Pending | Builds on Phase 1A |
| Phase 2 — Reconciler / observability | Future | Background re-attempt of pending rows older than 5 min |
| Phase 3 — `EmailChannel` + `SlackChannel` in `comms` | Future | Move email_service.dart into the package; add Slack |
| Phase 4 — Terraform / IaC | Future | Codify cross-project IAM grants |

---

## S3 — Mobile Stabilize (close-out the Stabilize PR set)

### Goal
Mobile app correctly handles every notification type the server now sends post-S2. Without this, Phase 1 is theoretical — the dispatcher will receive `patient_status_update` and `questionnaire_finalized` and ignore them.

### Three changes, single mobile PR

#### S3.1 — New cases in `task_service.dart` dispatcher

**File:** `apps/daily-diary/clinical_diary/lib/services/task_service.dart`
**Current:** `handleFcmMessage` switches on `type` and handles only `questionnaire_sent` and `questionnaire_deleted`. Anything else returns silently.

**Add cases:**

| `type` | `payload['action']` | Mobile behavior |
|--------|---------------------|-----------------|
| `questionnaire_unlocked` | `unlock_task` | Mark local task editable, show in-app banner |
| `questionnaire_finalized` | `lock_task` | Mark local task locked, hide edit button |
| `patient_status_update` | `disconnect` | Clear local data, force logout, "account closed" screen |
| `patient_status_update` | `mark_not_participating` | Same as disconnect with copy variant |
| `patient_status_update` | `reactivate` | Show "please re-link" screen |
| `patient_status_update` | `reconnect` | Show "please re-link" screen |
| `patient_status_update` | `start_trial` | Set local `trial_started=true`, show welcome screen |

**Test plan:**
- Unit-test the dispatcher with a fake FCM message map per `(type, action)` pair
- Integration test: emulator + fake FCM push (`adb shell am broadcast -a com.google.firebase.MESSAGING_EVENT --es type ...`)

#### S3.2 — Make `firebaseMessagingBackgroundHandler` actually do work

**File:** `apps/daily-diary/clinical_diary/lib/services/notification_service.dart:17`
**Current:** Top-level `@pragma('vm:entry-point')` handler only `debugPrint`s. So when the app is backgrounded/terminated and a data-only push arrives, nothing happens until the user opens the app.

**Change:** The handler must:
1. Initialize a minimal Hive box (background isolate has no shared state)
2. Persist the message to a local outbox (`pending_fcm_messages` Hive box)
3. Schedule a foreground sync when app resumes

**Why an outbox vs direct task creation:** the background isolate doesn't have full DI/auth state. We persist and let the foreground isolate process on resume. This also matches Phase 1 polling semantics (eventual reconciliation).

**Test plan:** Background the app, send a push via console-mode, foreground the app, verify task appears.

#### S3.3 — Split iOS APNS payload by user-visible vs data-only

**File:** `apps/sponsor-portal/portal_functions/lib/src/notification_service.dart` (server-side, but conceptually part of S3)
**Current:** All sends use `apns-priority: 10` + `content-available: 1` + an alert body. iOS treats this as user-visible AND wakes the app — fine for `questionnaire_sent`, but technically wrong for pure data-only updates.

**Change:** Add a `userVisible: bool` parameter to `_sendFcmMessage`:
- `true` (questionnaire_sent, finalized, patient_status_update): keep current shape — `priority: 10`, alert + `content-available: 1`
- `false` (future silent state-sync pushes): `priority: 5`, no alert, only `content-available: 1`. Avoids iOS background-wake throttling that priority-10 silent pushes hit.

**For Stabilize:** all existing sends are user-visible, so this is a no-op behavior-wise — we're just future-proofing the API.

### S3 PR shape
- Single PR on branch `feature/cur-826-fcm-stabilize` (same branch we're on — keep S1/S2/S3 together)
- Roll forward: server already on this branch; app store release after merge
- Roll back: revert PR. No DB damage — pure code

---

## Phase 1A — Bootstrap `comms` package + extract FCM transport

### Goal
Stand up the full `comms` package — channels, compliance, and the `notifications/` domain protocol — and migrate the existing FCM transport into it. After Phase 1A, Phase 1B is mostly app-side wiring: implement Postgres repo, write the migration, mount the package's handler factories.

### Why this scope
Bootstrapping the full protocol now (not just FCM transport) means Phase 1B doesn't have to touch the package — it just consumes it. It also means future apps that adopt notifications get the package's full surface from day one, with no "we'll move it next sprint" drift.

### Scope (single PR or 3 sub-PRs if review is heavy)

#### 1A.1 — Package skeleton + transport core

**Files (NEW):**
- `apps/common-dart/comms/pubspec.yaml`
- `apps/common-dart/comms/analysis_options.yaml`
- `apps/common-dart/comms/lib/comms.dart` (barrel — re-exports public API)
- `apps/common-dart/comms/lib/src/channel.dart` — `Channel<T>` + `ChannelMessage` base
- `apps/common-dart/comms/lib/src/dispatch_result.dart` — `DispatchResult`
- `apps/common-dart/comms/lib/src/compliance/payload_guard.dart` — full impl (regex against title/body/serialized payload for SubjectKey, email, common name patterns; throws `PhiLeakException`)
- `apps/common-dart/comms/test/compliance/payload_guard_test.dart`

**Workspace registration:** add `comms` to the root `pubspec.yaml` workspace list (mirror how `trial_data_types` is registered).

**Test plan:** `dart analyze` clean. `payload_guard_test.dart` covers known PHI patterns and known-safe strings.

#### 1A.2 — `channels/fcm/` — move FCM transport

**Files (NEW):**
- `apps/common-dart/comms/lib/src/channels/fcm/fcm_channel.dart` — `Channel<FcmMessage>` impl
- `apps/common-dart/comms/lib/src/channels/fcm/fcm_message.dart` — `FcmMessage` data class
- `apps/common-dart/comms/lib/src/channels/fcm/adc_client.dart` — ADC bearer rotation
- `apps/common-dart/comms/test/channels/fcm/fcm_channel_test.dart`
- `apps/common-dart/comms/test/channels/fcm/adc_client_test.dart`

**Moves from `portal_functions/lib/src/notification_service.dart`:**
- `_createAdcClient` → `AdcClient.create()`
- `_needsTokenRefresh` / `_refreshIfNeeded` → `AdcClient.refreshIfNeeded()`
- HTTP POST + 10s timeout + response parsing → `FcmChannel.dispatch(FcmMessage)`

**`FcmChannel` calls `PayloadGuard.assertSafe(message)` before the network call** — fail-closed PHI check.

**Stays in `notification_service.dart` (for now — Phase 1B sweeps it):**
- The public `sendQuestionnaireNotification` / `sendPatientStatusNotification` methods (thin orchestrators that build `FcmMessage` and call `fcmChannel.dispatch`)
- Audit logging (`_logNotificationAudit`)
- Metrics emission (`fcmNotificationSent`)
- The `NotificationService` singleton (now holds an `FcmChannel` instance)

#### 1A.3 — `notifications/` domain protocol

**Files (NEW):**
- `apps/common-dart/comms/lib/src/notifications/notification_type.dart` — enum + JSON helpers
- `apps/common-dart/comms/lib/src/notifications/envelope.dart` — data class with `toJson`/`fromJson`
- `apps/common-dart/comms/lib/src/notifications/envelope_status.dart` — enum
- `apps/common-dart/comms/lib/src/notifications/repository.dart` — `NotificationRepository` interface
- `apps/common-dart/comms/lib/src/notifications/outbox_writer.dart` — `OutboxWriter` impl (persist → dispatch → mark)
- `apps/common-dart/comms/lib/src/notifications/server/envelope_fetch_handler.dart` — shelf handler factory
- `apps/common-dart/comms/lib/src/notifications/server/envelope_since_handler.dart` — shelf handler factory
- `apps/common-dart/comms/lib/src/notifications/client/envelope_fetcher.dart` — pure-Dart HTTP fetcher
- `apps/common-dart/comms/test/notifications/envelope_test.dart`
- `apps/common-dart/comms/test/notifications/outbox_writer_test.dart`
- `apps/common-dart/comms/test/notifications/server/envelope_fetch_handler_test.dart`

**`OutboxWriter` shape:**
```dart
class OutboxWriter {
  OutboxWriter({required this.repo, required this.channel, this.guard});

  Future<String> send(Envelope envelope, {required String fcmToken}) async {
    guard?.assertSafe(envelope);                   // PHI guard once
    await repo.insertPending(envelope);            // durability first
    final message = _toFcmMessage(envelope, fcmToken);
    final result = await channel.dispatch(message);  // PayloadGuard runs again here
    if (result.success) {
      await repo.markSent(envelope.notificationId, result.messageId!);
    } else {
      await repo.markFailed(envelope.notificationId, result.error ?? 'unknown');
    }
    return envelope.notificationId;
  }
}
```

**Handler factory shape:**
```dart
Handler envelopeFetchHandler({
  required NotificationRepository repo,
  required Future<String> Function(Request) patientResolver,
}) {
  return (Request request) async {
    final patientId = await patientResolver(request);
    final id = request.params['id']!;
    final envelope = await repo.findById(id, patientId: patientId);
    if (envelope == null) return Response.notFound('...');
    if (envelope.deliveredAt == null) {
      await repo.markDeliveredIfNull([id], patientId: patientId);
    }
    return Response.ok(jsonEncode(envelope.toJson()),
      headers: {'content-type': 'application/json'});
  };
}
```

**Test plan:**
- `envelope_test.dart` — round-trip toJson/fromJson, payload immutability
- `outbox_writer_test.dart` — uses fake repo + fake channel, verifies pending → sent / pending → failed sequences
- `envelope_fetch_handler_test.dart` — fake repo + fake resolver, verifies cross-participant access is rejected

#### 1A.4 — Wire `portal_functions` to depend on `comms`

**File:** `apps/sponsor-portal/portal_functions/pubspec.yaml`
**Change:** add `comms: ^0.1.0` to dependencies (workspace-resolved).

**File:** `apps/sponsor-portal/portal_functions/lib/src/notification_service.dart`
**Change:** import `package:comms/comms.dart`. Hold an `FcmChannel` instance. Build `FcmMessage` objects in the orchestrator methods. Audit logging stays — it'll be moved into `OutboxWriter`-adjacent code in Phase 1B.

### Phase 1A behavior contract

After Phase 1A, the runtime behavior of S2 (every participant/questionnaire status change writes both a status-change audit row AND an `FCM_NOTIFICATION` audit row, sends FCM, captures `fcm_message_id`) is **unchanged**. This is a pure refactor — the domain protocol files are present but not yet wired into the request flow. They light up in Phase 1B when:
- The Postgres `NotificationRepository` impl lands
- The `notifications` table migration applies
- Handlers are mounted on `diary_server` / `portal_server`

### Phase 1A risks & mitigations

| Risk | Mitigation |
|------|------------|
| Workspace package not picked up by build / IDE | Mirror `trial_data_types` setup exactly. Verify with `dart pub get` and `dart analyze` from root. |
| `comms` accidentally pulls in Flutter SDK | CI lint: `dart pub deps --style=tree` must not list `flutter` under `comms`. Add as a check in `tools/`. |
| `notifications/` domain code unused → bitrot | Phase 1B is the immediate consumer. If 1B slips, the package still has unit-test coverage. |
| `OutboxWriter` over-prescribes the dispatch sequence | Keep it small (one method). If a future channel needs different sequencing (e.g., email needs synchronous DB transaction), introduce a sibling writer rather than overload this one. |
| `PayloadGuard` false positives blocking legit sends | Allow per-call opt-out only in tests; production code never bypasses. Tune regex against known-safe strings before merging. |

### Phase 1A PR shape
- Single PR recommended (1A.1 → 1A.4 as commits in one branch). Sub-PR split is fine if review is heavy; the dep order is 1A.1 → 1A.2 → 1A.3 → 1A.4
- Roll forward: deploy to qa, smoke-test that disconnect/finalize/etc. still produce both audit rows
- Roll back: revert PR. No DB or runtime state to clean up — `notifications` table doesn't exist yet

---

## Phase 1B — Envelope Pattern + Polling Fallback

### Goals & invariants

- **Compliance:** zero PHI in FCM payload — only opaque IDs + categorical type
- **Durability:** every notification written to a `notifications` row **before** FCM dispatch. If FCM fails, row stays `status='pending'` and mobile discovers it via polling
- **Truth:** mobile polling is source of truth. FCM is a nice-to-have wakeup. `delivered_at` is updated when mobile fetches — that is our delivery confirmation, not the FCM ack

### Schema (P1.1)

```sql
CREATE TYPE notification_type AS ENUM (
  'questionnaire_update',
  'patient_status_update',
  'reminder'
);

CREATE TABLE notifications (
  notification_id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        text NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
  notification_type notification_type NOT NULL,
  title             text NOT NULL,
  body              text,
  payload           jsonb NOT NULL DEFAULT '{}'::jsonb,
  status            text NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','sent','delivered','failed')),
  message_id        text,        -- FCM message_id when status='sent'
  last_error        text,        -- populated when status='failed'
  created_at        timestamptz NOT NULL DEFAULT now(),
  sent_at           timestamptz,
  delivered_at      timestamptz
);

CREATE INDEX notifications_patient_pending_idx
  ON notifications (patient_id, created_at DESC)
  WHERE delivered_at IS NULL;
```

**Why this index:** mobile polling query is "give me everything for this participant since X that I haven't ack'd". The partial index on `delivered_at IS NULL` keeps it tight.

**Migration:** `database/migrations/011_create_notifications_table.sql` + rollback. NOT VALID + VALIDATE pattern not needed (CREATE TABLE doesn't lock anything pre-existing).

### API contract (P1.4)

#### `GET /api/v1/notifications?since=<iso8601>&limit=50`
Authorization: Bearer <participant JWT>

```json
Response 200:
{
  "notifications": [
    {
      "notification_id": "uuid",
      "type": "questionnaire_update",
      "title": "New Questionnaire Available",
      "body": "You have a new questionnaire to complete.",
      "payload": {"action": "new_task", "questionnaire_instance_id": "uuid"},
      "created_at": "...",
      "delivered_at": null
    }
  ],
  "server_time": "2026-05-07T..."
}
```

#### `POST /api/v1/notifications/<id>/ack`
Authorization: Bearer <participant JWT>

```json
Response 200: { "delivered_at": "..." }
```

**Why two endpoints not one:** GET is idempotent and cacheable; ack is a state mutation. Conflating them means a network retry of GET re-acks already-delivered notifications, mangling timestamps.

**Decision to revisit:** batched ack via `POST /notifications/ack-batch` — probably yes for performance, not blocker for P1.

### PR sequence

(Numbering uses `P1B.x` for clarity — Phase 1A's PR is a separate, earlier PR. After Phase 1A, the package owns the outbox writer, repository interface, handler factories, and envelope types. Phase 1B is mostly app-side: schema, Postgres repo impl, route mounting, and mobile wiring.)

#### P1B.1 — Schema + Postgres repo impl

**Files:**
- `database/migrations/011_create_notifications_table.sql` (forward + rollback)
- `database/schema.sql` (greenfield)
- `apps/sponsor-portal/portal_functions/lib/src/notifications/pg_notification_repository.dart` (NEW) — Postgres impl of `comms` `NotificationRepository`

**Postgres repo shape:**

```dart
class PgNotificationRepository implements NotificationRepository {
  final Database db;
  final UserContext context;
  PgNotificationRepository({required this.db, required this.context});

  @override
  Future<void> insertPending(Envelope envelope) async {
    await db.executeWithContext('''
      INSERT INTO notifications (
        notification_id, patient_id, notification_type,
        title, body, payload, status
      ) VALUES (
        @id::uuid, @patientId, @type::notification_type,
        @title, @body, @payload::jsonb, 'pending'
      )
    ''', parameters: {...}, context: context);
  }

  // markSent, markFailed, findById, findSince, markDeliveredIfNull...
}
```

**Test plan:**
- Schema migration applies + rolls back cleanly on local DB
- `PgNotificationRepository` integration-tested against the local docker postgres
- Index exists and is used by EXPLAIN of the polling query

**Rollback:** drop notifications table, drop type. Safe — table is new.

#### P1B.2 — Route ONE handler through `OutboxWriter` (proof of concept)

**Choice:** `disconnectPatientHandler` (just wired in S2, simplest, smallest blast radius).

**Behavior:** the handler builds an `Envelope` and calls `outboxWriter.send(envelope, fcmToken: ...)`. The package handles persist → dispatch → mark — the handler doesn't see those steps. Audit log row (`DISCONNECT_PATIENT`) keeps including `fcm_message_id` (taken from the returned `notificationId` lookup or from the outbox's mark step).

```dart
final envelope = Envelope.patientStatusUpdate(
  patientId: patientId,
  title: 'Account Disconnected',
  body: 'Your study account has been disconnected. ...',
  payload: {'action': 'disconnect', 'new_status': 'disconnected'},
);
final notificationId = await outboxWriter.send(envelope, fcmToken: fcmToken);
```

**Feature flag:** `FCM_USE_ENVELOPE_DISCONNECT=true` — server-side env. Default OFF until cutover.

**Test plan:** local console-mode test:
- Flag off: behavior identical to S2 (`DISCONNECT_PATIENT` row + `FCM_NOTIFICATION` audit row)
- Flag on: same audit rows + new `notifications` row (status=pending → sent)

**Rollback:** flag off. No schema rollback needed.

#### P1B.3 — Migrate remaining server senders

Per-handler env flag (e.g., `FCM_USE_ENVELOPE_QUESTIONNAIRE_SENT=true`) so we flip incrementally.

Same call-site shape as P1B.2 for: `questionnaire_sent`, `questionnaire_deleted`, `questionnaire_unlocked`, `questionnaire_finalized`, `mark_not_participating`, `reactivate`, `reconnect`, `start_trial`. Each handler is a ~10-line change because the heavy lifting lives in `OutboxWriter`.

**Cleanup at end of P1B.3:** remove the `_logNotificationAudit` writes from `notification_service.dart`. With the outbox in place, the `notifications` table IS the audit trail for sends — the parallel `admin_action_log` row with `action_type='FCM_NOTIFICATION'` is redundant.

**Important:** keep the **action** audit row (e.g., `DISCONNECT_PATIENT`). Just stop writing the `FCM_NOTIFICATION` row. Migration 010 stays — the constraint still allows the value, we just stop emitting it.

#### P1B.4 — Mount notifications API on `diary_server`

**File:** `apps/daily-diary/diary_server/lib/server.dart` (or wherever routes are registered)

**Change:** mount the package-provided handler factories on the diary_server router.

```dart
import 'package:comms/comms.dart';

final notificationRepo = PgNotificationRepository(db: db, context: UserContext.patient);
final patientResolver = (Request req) async {
  final auth = verifyAuthHeader(req.headers['authorization']);
  return await lookupPatientByAuth(auth);
};

router.get('/api/v1/notifications/<id>',
  envelopeFetchHandler(repo: notificationRepo, patientResolver: patientResolver));
router.get('/api/v1/notifications',
  envelopeSinceHandler(repo: notificationRepo, patientResolver: patientResolver));
```

**Auth:** participant JWT (same as the existing diary_server token registration). RLS policy: participant can only see/ack their own notifications.

**RLS test:** participant A's token cannot fetch participant B's notifications.

#### P1B.5 — Mobile polling integration

**Files (NEW):**
- `apps/daily-diary/clinical_diary/lib/services/notification_poll_service.dart`

**Uses package's `EnvelopeFetcher`** for the actual HTTP calls — mobile doesn't reimplement the wire format or the URL paths.

**Triggers:**
1. App resume (lifecycle observer) — always poll
2. FCM envelope arrival (FCM payload containing only `notification_id`) — trigger immediate poll for that ID
3. Periodic background poll while app foregrounded (every 60s) — for missed pushes
4. Pull-to-refresh on the main task list

**Storage:** persist `last_polled_at` in Hive. Poll uses `since=last_polled_at`; on success updates to `server_time` from the response.

**delivered_at update:** for each notification fetched, the package's `EnvelopeFetcher` already idempotently sets `delivered_at` server-side (via `findById` → `markDeliveredIfNull`). Mobile gets the freshly-marked envelope back.

**Dispatch on arrival:** mobile maps `Envelope.type` to existing handler: `questionnaireUpdate` → `task_service.handleQuestionnaireUpdate`, `patientStatusUpdate` → `enrollment_service.handlePatientStatusUpdate`, `reminder` → reminder service.

**Test plan:** integration test on emulator — start app, no notifications visible. Server-side: insert a row directly. Mobile: verify it appears within 60s without any FCM.

#### P1B.6 — Cleanup + retire old direct-FCM path

- After 2 weeks of envelope on in production with no incidents, flip default for all flags to ON
- Remove the direct-FCM code paths (the `if (notificationTitle != null)` branch that sets a notification block on the FCM payload — Phase 1 sends data-only with envelope `notification_id`)
- Remove the orchestrator methods on `NotificationService` that aren't used by `OutboxWriter` (`sendQuestionnaireNotification`, `sendPatientStatusNotification`, etc.)
- Remove feature flags

### Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Outbox row commits but FCM dispatch crashes process before `markDispatched` | Row stays `pending`. Mobile polling discovers it. Add background reconciler that re-attempts pending rows >5min old (Phase 2, not P1). |
| Mobile fetches notification but crashes before ack | `delivered_at IS NULL` → next poll re-fetches. Idempotent UI consumes by `notification_id`. |
| Cutover double-fires (old path + envelope) | Per-handler feature flag. Default OFF. Validate per-handler before flipping. |
| `delivered_at` race: server INSERT not yet committed when mobile polls | Outbox INSERT is in same transaction as the action. Mobile won't see uncommitted rows. |
| Participant with multiple devices: which device's `delivered_at` wins? | First device to ack wins. Other devices fetch but skip ack if `delivered_at` already set. |
| Schema migration rolling forward but P1.2 not deployed | Safe — empty table sits unused. |
| RLS misconfigured → participant sees other participants' notifications | RLS test in CI: spin up two participant JWTs, attempt cross-participant read, expect 0 rows. |

### Estimate

| Item | Days | PRs |
|------|------|-----|
| S3 | 1 | 1 |
| **Phase 1A** (bootstrap full `comms` package) | **3** | **1** (or 1A.1+1A.2 / 1A.3 / 1A.4 split if review heavy) |
| P1B.1 (schema + Postgres repo impl) | 1 | 1 |
| P1B.2 (route 1 handler through outbox) | 0.5 | 1 |
| P1B.3 (migrate remaining handlers) | 1.5 | 1–3 (per batching) |
| P1B.4 (mount handlers on diary_server) | 0.5 | 1 |
| P1B.5 (mobile polling) | 2 | 1 |
| P1B.6 (cleanup) | 0.5 | 1 |
| **Total** | **~10** | **~8–10** |

Plus 2 weeks of soak time before P1B.6.

**Why P1B got smaller:** `OutboxWriter`, handler factories, and `EnvelopeFetcher` now live in the package, so each P1B PR is mostly wiring (1–2 file changes per handler in P1B.3, ~10-line route mounts in P1B.4). The complexity moved into Phase 1A where it's covered by package-level unit tests.

---

## Decision Points

1. **Package name and location.** Proposing `apps/common-dart/comms/`. Open to `messaging`, `comms_common`, or another suggestion before we land the PR.
2. **S3 first, or Phase 1A in parallel?** Both are independent of each other and of the deployed S2 server. Recommendation: land S3 first to close out Stabilize, then do Phase 1A.
3. **Phase 1A as one PR or three?** Single PR is reviewable but heavy (~12 new files + tests). Three sub-PRs (1A.1+1A.2 transport, 1A.3 notifications/, 1A.4 wire portal) trade reviewer load for sequencing overhead. Recommendation: start as one; split only if reviewer asks.
4. **Schema (P1B.1) before, after, or alongside Phase 1A?** Schema is independent of Phase 1A — `notifications` table is greenfield. Recommendation: land Phase 1A first so 1B.1 can include the Postgres repo impl alongside the migration; otherwise we'd land migration twice (once empty, once wired).
5. **Per-handler flag granularity in P1B.3?** One flag per handler (8 flags) is safer but verbose. Could also do one flag per `notification_type` (3 flags). Recommendation: one per handler — most rollback granularity at low cost.
6. **Ack-on-fetch vs ack-on-display in P1B.5?** Ack-on-fetch is simpler. Ack-on-display gives a more accurate "user actually saw this" timestamp. Defer ack-on-display to a follow-up if FDA auditor asks for it.
7. **Reconciler in Phase 1B or Phase 2?** Phase 2. P1B covers the happy path + polling-as-fallback. Reconciler is belt-and-suspenders for pathological FCM-dispatch failures.
8. **When does `email_service.dart` move into `comms`?** Recommendation: Phase 3, not Phase 1A. Email currently uses domain-wide delegation (signJwt) — different auth model from FCM's straight ADC. Conflating both auth models in one package PR adds risk for no Phase-1B benefit. Keep email in `portal_functions/` until the Slack work forces a unification.
9. **Should `OutboxWriter` be channel-agnostic?** Today it's coupled to FCM (takes `fcmToken`). For email/slack, the addressing model differs (no per-recipient token; group recipients per channel). Recommendation: keep `OutboxWriter` as `FcmOutboxWriter` for now and introduce sibling writers per channel in Phase 3, rather than over-generalizing now. Same package, different writer per channel.

---

## Open Questions

- Should the `notifications` table have an `expires_at` column? Some notifications (questionnaire_sent for an expired questionnaire) become stale. Defer for now; mobile UI can hide based on the underlying questionnaire state.
- Do we need per-sponsor isolation in `notifications`? Currently the table sits in the shared schema; patient_id naturally scopes by sponsor. Verify with RLS testing.
- Cloud Tasks for outbox retry (Phase 2) vs cron-based reconciler? Cloud Tasks is more accurate but adds infra. Cron is simpler. Decide when we get to Phase 2.
- Does `comms` need to depend on `otel_common`, or should observability be injected by the consumer? Initial proposal: depend directly (matches what `notification_service.dart` does today). Revisit if `comms` becomes consumed by code outside the GCP/OTel-instrumented services.
- Should `FcmChannel` be a singleton or instance-per-call? Today's `NotificationService` is a singleton. Recommendation: instance-per-app (one per server boot) but not singleton in the package itself — let the consumer manage lifecycle.
