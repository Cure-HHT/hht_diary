# `comms` Package & Notifications Implementation Plan (v2)

> **⚠️ Setup steps stale (2026-06, EVS cutover, CUR-1170):** Any local-DB setup commands in this
> plan (e.g. `docker-compose.db.yml`) no longer work — the local raw-Postgres DB stack and the
> `database/` SQL schema/migrations were deleted. The platform is now EVS-only: the event store
> schema is created at runtime by the `event_sourcing` library (`portal_server_evs`), and
> notifications data is modeled as events, not relational migrations. Plan substance below is
> unchanged; ignore the removed local-DB steps.

**Document status:** Draft for review — supersedes `docs/fcm-next-phase-plan.md` once approved. The current document is intentionally detailed so we can iterate on it before any code lands.

**Linear:** CUR-826 (Stabilize), Phase 1A/1B tickets to be claimed when the plan is locked.

**Branch in flight:** `feature/cur-826-fcm-stabilize` (S1 + S2 already shipped on this branch).

---

## Table of contents

1. [Status snapshot](#status-snapshot)
2. [Plan provenance — pre-spec baseline vs spec-driven additions](#plan-provenance--pre-spec-baseline-vs-spec-driven-additions)
3. [Architectural decisions](#architectural-decisions)
4. [The `comms` package](#the-comms-package)
5. [Phase 0 — IAM grant (DONE)](#phase-0--iam-grant-done)
6. [Stabilize: S1 (DONE), S2 (DONE), S3 (pending)](#stabilize-phase)
7. [Phase 1A — Bootstrap `comms` package](#phase-1a--bootstrap-comms-package)
8. [Phase 1B — Envelope pattern + polling](#phase-1b--envelope-pattern--polling)
9. [Phase 1C — Yesterday Reminder scheduler](#phase-1c--yesterday-reminder-scheduler)
10. [Phase 2 — Reconciler & observability](#phase-2--reconciler--observability)
11. [Phase 3 — `EmailChannel` + `SlackChannel`](#phase-3--emailchannel--slackchannel)
12. [Phase 4 — Terraform / IaC](#phase-4--terraform--iac)
13. [Cross-cutting concerns](#cross-cutting-concerns)
14. [Risks & mitigations](#risks--mitigations)
15. [Estimate](#estimate)
16. [Decision points / open questions](#decision-points--open-questions)
17. [Glossary](#glossary)

---

## Status snapshot

| Phase | Status | Branch / PR | Notes |
|-------|--------|-------------|-------|
| **Phase 0** — IAM grant on `cure-hht-admin` | ✅ **DONE** | n/a (gcloud op) | `roles/cloudmessaging.admin` granted to sponsor compute SA `421945483876-compute@developer.gserviceaccount.com`. Verified live in callisto4-qa with successful `messages:send` returning a `message_id`. |
| **S1** — Migration 010 (admin_action_log constraint) | ✅ **DONE** | `feature/cur-826-fcm-stabilize` (commit `d5dab52c`) | Adds `'FCM_NOTIFICATION'` to `admin_action_log_action_type_check_v3`. Pre-fix: every FCM send produced a silent CHECK violation; FDA audit trail had no FCM rows. Post-fix: every send writes one row. |
| **S2** — Server senders for all status transitions | ✅ **DONE** | `feature/cur-826-fcm-stabilize` (commit `159af9c1`) | All 5 patient handlers (disconnect, mark_not_participating, reactivate, reconnect, start_trial) + finalizeQuestionnaireHandler send FCM. `fcm_message_id` captured in audit. 10 s HTTP timeout. Cross-patient token uniqueness in `diary_functions`. Replaced leaky `'trial-$patientId'` literal. |
| **S3** — Mobile dispatcher + BG handler | ⏳ **PENDING** | TBD | Mobile companion to S2. Closes out the Stabilize PR set. |
| **Phase 1A** — Bootstrap `comms` package | ⏳ **PENDING** | TBD | New workspace package: channels (FCM today), compliance (PHI guard), notifications domain (types, repo interface, outbox writer, server handler factories, client envelope fetcher). Pure Dart, zero Flutter dependencies. |
| **Phase 1B** — Envelope pattern + polling | ⏳ **PENDING** | TBD | Schema migration 011, Postgres repo impl, wire handlers to `OutboxWriter`, mount API on `diary_server`, mobile polling. |
| **Phase 1C** — Yesterday Reminder scheduler | ⏳ **PENDING** | TBD | One server-side scheduled job (Yesterday Entry Reminder). Builds on Phase 1B outbox. Requires mobile timezone in token registration (migration 012). Includes the lone `Yesterday Reminder Time` sponsor config slot. |
| **Phase 2** — Reconciler & observability | Future | — | Background re-attempt of pending rows >5 min old; metrics dashboards. |
| **Phase 3** — `EmailChannel` + `SlackChannel` | Future | — | Move `email_service.dart` into the package; add Slack. |
| **Phase 4** — Terraform / IaC | Future | — | Codify cross-project IAM grants for new sponsors. |

---

## Plan provenance — pre-spec baseline vs spec-driven additions

This plan started from the FCM redesign work in `docs/fcm-notification-redesign-plan.md` and `docs/fcm-notification-implementation-plan.md` (the **pre-spec baseline**). After cross-checking against `spec/dev-notifications-v2.md`, gaps were identified and the plan was extended (the **spec-driven additions**). This section surfaces that diff so reviewers know which decisions came from where, and ties the additions to a unified implementation order.

### Pre-spec baseline (what was already planned before `dev-notifications-v2.md` was reviewed)

| Item | Source | Scope |
|------|--------|-------|
| Phase 0 — IAM grant on `cure-hht-admin` (DONE) | redesign + implementation plans | Cross-project grant of `cloudmessaging.admin` to sponsor compute SA |
| S1 — Migration 010 (DONE) | implementation plan | Add `'FCM_NOTIFICATION'` to admin_action_log constraint |
| S2 — Server senders (DONE) | implementation plan | Wire FCM into all 5 participant-status handlers + finalize; capture `fcm_message_id`; cross-participant token uniqueness; 10s timeout |
| S3 — Mobile dispatcher + BG handler | implementation plan | Dispatcher cases for new types, real BG handler, APNS user-visible vs data-only split |
| Phase 1A — Bootstrap `comms` package | redesign plan + CEO directive | Package skeleton, FCM channel, notifications domain protocol, wire portal_functions |
| Phase 1B — Envelope pattern + polling | redesign plan | Schema, Postgres repo, outbox-routed handlers, mount API on diary_server, mobile polling, cleanup |
| Phase 2 — Reconciler & observability (future) | redesign plan | Background re-attempt of pending rows; metrics dashboards |
| Phase 3 — `EmailChannel` + `SlackChannel` (future) | architectural decision in this plan | Move `email_service.dart` into `comms`; add Slack |
| Phase 4 — Terraform / IaC (future) | implementation plan | Codify IAM grants |

### Spec-driven additions (what got added after `dev-notifications-v2.md` review)

#### A) Patches inside baseline phases (small changes, no new phase)

| # | Patch | REQ source | Where it lands |
|---|-------|------------|----------------|
| 1 | Cold-start: no deep-link on tap; always Main Screen | REQ-d00196 | Phase 1B.5 |
| 2 | `comms.fcm.dispatch` metric with `result` + `notification_type` tags | REQ-d00193-H | Phase 1A.2 |
| 3 | Hive `lastSeen` + `recent_ids` cleared on logout / unlink; 30-day bootstrap | REQ-d00195-K | Phase 1B.5 |
| 4 | `DispatchResult.unregisteredToken()` + `OutboxWriter.onUnregistered` callback | REQ-d00193-C | Phase 1A.2 + 1A.3 |
| 5 | Explicit `PayloadGuard` regex set (strict + extended SubjectKey, email, configurable name list) | REQ-d00194-E | Phase 1A.1 |
| 6 | Dedupe by `notification_id` across FCM + polling (Hive 500-cap FIFO set) | REQ-d00195-J | Phase 1B.5 |
| 7 | Send-handler suppression (already-submitted, called-back) | REQ-d00182-B,C | Phase 1B.3 |

These add roughly +0.5 days to Phase 1A (regex set + UNREGISTERED handling + metric), +0.5 days to P1B.3 (suppression), and +0.5 days to P1B.5 (cold-start rewrite + dedupe + lifecycle reset). They are all in the patched Phase 1A and Phase 1B sections of this doc.

#### B) New phase (scope absent from the baseline)

| Phase | REQs covered | Why it wasn't in the baseline |
|-------|-------------|-------------------------------|
| **Phase 1C — Yesterday Reminder scheduler** | REQ-d00200 (Yesterday Reminder timezone-aware scheduling, A–G); REQ-d00201 (suppression, A–B); plus `device_timezone` migration 012 and the `Yesterday Reminder Time` sponsor config slot | The redesign focused on transport + envelope + polling. The Yesterday Reminder is a server-side scheduled job that depends on participant timezone — not part of the FCM-redesign scope. |

This adds ~3 days of work — the baseline estimate was ~10 days remaining, the post-spec estimate is ~13 days remaining.

#### C) Previously planned, now out of current spec scope

The spec was narrowed since the previous gap analysis. The following phases were planned and have been **dropped from the live plan** to track scope honestly. They may return if the spec re-expands; design notes are preserved in git history (`docs/comms-implementation-plan.md` revisions before this edit).

| Previously | Reqs that drove it | Status now |
|-----------|---------------------|-----------|
| Lock Warning scheduler | REQ-d00180, d00181 | Removed from `spec/dev-notifications-v2.md` |
| Epistaxis Reminder scheduler | REQ-d00185, d00186, d00187 | Removed from spec |
| Historical Gap Reminder scheduler | REQ-d00188–d00191 | Removed from spec |
| Task List domain model + rendering (3 task kinds, priority order) | REQ-d00198–d00175 (old numbering) | Removed from spec; only the reactivity assertion (new REQ-d00198) remains, satisfied by P1B.5 |
| Disconnection Notification mobile surface | REQ-d00177, d00178 | Removed from spec |
| Participation Status Badge | REQ-d00179 | Removed from spec |
| Sponsor config slots (full set) and Callisto values | REQ-CAL-d00001 / d00002 / d00003 | Removed from spec; only one slot (`Yesterday Reminder Time`) remains, folded into Phase 1C |

### Unified implementation order

Listed in **dependency order**, with each item tagged for provenance.

```
S3 (Stabilize close-out)                                       [baseline]
└─ Phase 1A — Bootstrap `comms` package                        [baseline + patches A.2, A.4, A.5]
   └─ Phase 1B — Envelope pattern + polling                    [baseline + patches A.1, A.3, A.6, A.7]
      └─ Phase 1C — Yesterday Reminder scheduler               [B — spec-driven]
Phase 2 — Reconciler & observability                            [baseline, future]
Phase 3 — `EmailChannel` + `SlackChannel`                       [baseline, future]
Phase 4 — Terraform / IaC                                       [baseline, future]
```

**Critical path:** S3 → Phase 1A → Phase 1B → Phase 1C is the only ordered sequence. Every spec-driven addition either patches inside one of these or depends on Phase 1B's outbox + polling.

**Single PR-by-PR sequence:**

| Order | Item | Provenance | Depends on |
|-------|------|------------|------------|
| 1 | S3 — Mobile stabilize | baseline | S2 (DONE) |
| 2 | Phase 1A — `comms` package bootstrap (one PR or three sub-PRs) | baseline + patches | S3 |
| 3 | P1B.1 — Schema migration 011 + `PgNotificationRepository` | baseline | Phase 1A |
| 4 | P1B.2 — Route `disconnectPatientHandler` through `OutboxWriter` (proof of concept) | baseline | P1B.1 |
| 5 | P1B.3 — Migrate remaining 7 senders + suppression rules | baseline + patch A.7 | P1B.2 |
| 6 | P1B.4 — Mount API on `diary_server` | baseline | P1B.1 |
| 7 | P1B.5 — Mobile polling client (dedupe, lifecycle reset, no deep-link, reactive within 1s per REQ-d00198) | baseline + patches A.1, A.3, A.6 | P1B.4 |
| 8 | P1C — Yesterday Reminder (cron infra + job + migration 012 + mobile timezone + config slot) | spec-driven | P1B.1, P1B.5 |
| 9 | P1B.6 — Cleanup + retire old direct-FCM path | baseline | 2 weeks soak after P1B.3 |

Item 9 (cleanup) is gated on operational soak time, not engineering work.

---

## Architectural decisions

### Why a generic `comms` package, not FCM-only

An FCM-only package would force every future communication channel (email, Slack, SMS, etc.) to either ride on top of an awkward FCM-shaped abstraction or duplicate concerns (auth, retry, audit, compliance). The package is named for the **shared concern** ("outbound communications"), not the first channel that arrives.

### Scope rule: **contract goes in, configuration stays out**

> Anything that defines the protocol — types, wire format, channel transport, PHI guard, server handler factories, client fetchers — lives in `comms`. Anything that wires the protocol to a specific database, auth model, or sponsor lives in the consuming app.

If a future app (new sponsor portal, secondary diary variant, admin tool) wants to send or receive notifications, it should NOT redefine `NotificationType`, re-shape `Envelope`, or re-implement `GET /notifications`. It should just:

1. Implement `NotificationRepository` against its DB.
2. Provide a JWT-to-patient resolver.
3. Mount the package's handler factories on its router.
4. Call `OutboxWriter.send(envelope)` from its business logic.

### Pure Dart, no Flutter SDK

`comms` does not depend on `firebase_messaging` or any other Flutter package. This means:

- Server services (`portal_functions`, `diary_functions`) can consume it without dragging the Flutter SDK into their build.
- Mobile FCM **reception** (the `firebase_messaging.onMessage` subscriber) stays in `clinical_diary/`.
- The **dispatch logic** (given an envelope, route to handler by type) and the **fetcher** (HTTP client to `GET /notifications`) live in `comms` as pure Dart, so any future mobile app reuses them.

CI will enforce this rule (`dart pub deps --style=tree` must not list Flutter under `comms`).

### Per-channel folders

Each channel grows a message data class, an auth helper, and the channel impl plus tests. Flat layout doesn't scale; per-channel folders do. Adding a channel = adding a sibling folder under `channels/`.

### One `OutboxWriter` per channel for now

`OutboxWriter` today is FCM-coupled (takes an `fcmToken`). Email and Slack address recipients differently (no per-token model; group/list addressing). Rather than over-generalize, Phase 3 will introduce sibling writers (`EmailOutboxWriter`, `SlackOutboxWriter`) in the same package, sharing the persist → dispatch → mark sequence as a small base class if useful.

---

## The `comms` package

### Layout (initial — bootstrapped in Phase 1A)

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
│       │   └── payload_guard.dart              # PHI checker (channel-agnostic)
│       ├── channels/
│       │   └── fcm/
│       │       ├── fcm_channel.dart            # Channel<FcmMessage> impl
│       │       ├── fcm_message.dart            # FcmMessage data class
│       │       └── adc_client.dart             # ADC bearer token rotation
│       └── notifications/
│           ├── notification_type.dart          # 3-value enum
│           ├── envelope.dart                   # Envelope data class with toJson/fromJson
│           ├── envelope_status.dart            # pending | sent | failed | delivered
│           ├── repository.dart                 # NotificationRepository interface
│           ├── outbox_writer.dart              # persist → dispatch → mark helper
│           ├── server/
│           │   ├── envelope_fetch_handler.dart # GET /notifications/{id} factory
│           │   └── envelope_since_handler.dart # GET /notifications?since= factory
│           └── client/
│               └── envelope_fetcher.dart       # pure-Dart HTTP fetcher
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

### Layout (future — Phase 3 adds email + slack)

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

### What goes IN `comms`

| Component | Why |
|-----------|-----|
| `Channel<T>` + `DispatchResult` | Universal transport interface |
| `channels/fcm/` (today); `channels/email/`, `channels/slack/` (Phase 3) | Per-channel implementations — write once, every consumer dispatches the same way |
| `compliance/payload_guard.dart` | PHI safety must run identically everywhere — centralize it |
| `notifications/notification_type.dart` | 3-value enum is the protocol vocabulary |
| `notifications/envelope.dart` + `envelope_status.dart` | Wire format that server stores and mobile consumes — `toJson`/`fromJson` lives in one place |
| `notifications/repository.dart` | Defines what every consumer's notification storage must support |
| `notifications/outbox_writer.dart` | The "persist → dispatch → mark" sequence — same logic everywhere |
| `notifications/server/*.dart` | Shelf handler factories. Each takes `(repo, patientResolver)` and returns a mountable handler. |
| `notifications/client/envelope_fetcher.dart` | Pure-Dart HTTP fetcher (uses caller's `http.Client`) |

### What stays OUT of `comms`

| Component | Why |
|-----------|-----|
| Postgres impl of `NotificationRepository` | App owns its connection pool, RLS context, sponsor schema |
| JWT-to-patient resolver | Each sponsor's auth model differs (Identity Platform claims, role mapping) |
| Route registration / middleware | Only the app knows its router and middleware |
| Mobile FCM **reception** (subscribes to `firebase_messaging`) | Depends on Flutter SDK; `comms` is pure Dart |
| Per-handler business logic ("when a questionnaire arrives, update task list") | Sponsor-specific |

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
  final bool unregistered;          // true only for FCM 404 UNREGISTERED — token is permanently invalid
  DispatchResult.success(this.messageId) : success = true, error = null, unregistered = false;
  DispatchResult.failure(this.error) : success = false, messageId = null, unregistered = false;
  DispatchResult.unregisteredToken() : success = false, messageId = null, error = 'UNREGISTERED', unregistered = true;
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

// === Compliance ===
class PhiLeakException implements Exception {
  final String field;
  final String matchedPattern;
  PhiLeakException(this.field, this.matchedPattern);
}

class PayloadGuard {
  /// Throws PhiLeakException if title/body/payload contains:
  /// - SubjectKey pattern (\d{3}-\d{3}-\d{3} or sponsor-prefixed variant)
  /// - email-like patterns
  /// - common name patterns
  static void assertSafe(Envelope envelope);
  static void assertSafeFcm(FcmMessage message);
}

// === Notifications domain ===
enum NotificationType { questionnaireUpdate, patientStatusUpdate, reminder }
enum EnvelopeStatus { pending, sent, delivered, failed }

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

  // Convenience constructors that set type + populate payload conventions
  factory Envelope.questionnaireSent({...});
  factory Envelope.questionnaireFinalized({...});
  factory Envelope.patientStatusUpdate({...});
  factory Envelope.reminder({...});
}

abstract class NotificationRepository {
  Future<void> insertPending(Envelope envelope);
  Future<Envelope?> findById(String id, {required String patientId});
  Future<List<Envelope>> findSince(DateTime since, {required String patientId, int limit});
  Future<void> markSent(String id, String messageId);
  Future<void> markFailed(String id, String error);
  Future<void> markDeliveredIfNull(List<String> ids, {required String patientId});
}

class OutboxWriter {
  OutboxWriter({
    required this.repo,
    required this.channel,
    this.onUnregistered,            // optional: app wires a callback that deactivates the token in patient_fcm_tokens
  });
  final Future<void> Function(String fcmToken)? onUnregistered;

  /// Write pending row, dispatch via channel, mark sent/failed.
  /// On UNREGISTERED, marks failed AND invokes onUnregistered so the app can deactivate the stale token.
  /// Returns the persisted notification_id even on dispatch failure.
  Future<String> send(Envelope envelope, {required String fcmToken});
}

// === Server-side handler factories (shelf) ===
Handler envelopeFetchHandler({
  required NotificationRepository repo,
  required Future<String?> Function(Request) patientResolver,
});

Handler envelopeSinceHandler({
  required NotificationRepository repo,
  required Future<String?> Function(Request) patientResolver,
});

// === Client-side fetcher (pure Dart) ===
class EnvelopeFetcher {
  EnvelopeFetcher({required this.httpClient, required this.baseUrl});
  Future<Envelope> fetchById(String id, {required String authHeader});
  Future<List<Envelope>> fetchSince(DateTime since, {required String authHeader, int limit = 50});
}
```

---

## Phase 0 — IAM grant (DONE)

**Recap (no work to do; reference for new-sponsor onboarding):**

- The `cure-hht-admin` GCP project is the FCM "Firebase project" all sponsor servers send through.
- Each sponsor's compute service account on `{sponsor}-{env}` (e.g., `421945483876-compute@developer.gserviceaccount.com` for `callisto4-qa`) needs `roles/cloudmessaging.admin` on `cure-hht-admin`.
- Granted via `gcloud projects add-iam-policy-binding cure-hht-admin --member=serviceAccount:<sa> --role=roles/cloudmessaging.admin`.
- See `docs/cross-project-iam-runbook.md` for the per-feature cross-project IAM matrix and onboarding procedure for new sponsors.

**Verification (already passing):** server logs in callisto4-qa show `FCM sent ...` with `message_id: projects/cure-hht-admin/messages/0:...`.

---

## Stabilize Phase

### S1 — Migration 010 (DONE)

**Files:** `database/migrations/010_add_fcm_notification_action_type.sql`, `database/migrations/rollback/010_rollback.sql`, `database/schema.sql`.

**What changed:** `admin_action_log_action_type_check_v2` (introduced in migration 007) did not include `'FCM_NOTIFICATION'` in its allowed list. The notification_service.dart code writes `action_type='FCM_NOTIFICATION'` after every FCM send → CHECK violation → exception swallowed inside `_logNotificationAudit`. The send succeeds but the audit row is silently dropped — meaning environments running migration 007 had **zero FCM audit trail**.

**Fix:** add `'FCM_NOTIFICATION'` to the allowed list using NOT VALID + VALIDATE pattern (zero-downtime). Replaces v2 with v3.

**Status:** applied locally and committed.

### S2 — Server senders (DONE)

**Files:**
- `apps/sponsor-portal/portal_functions/lib/src/notification_service.dart`
- `apps/sponsor-portal/portal_functions/lib/src/patient_linking.dart`
- `apps/sponsor-portal/portal_functions/lib/src/questionnaire.dart`
- `apps/daily-diary/diary_functions/lib/src/fcm_token.dart`

**What changed:**
1. New `sendPatientStatusNotification` method in `NotificationService` — covers all 5 patient transitions (disconnect, reconnect, mark_not_participating, reactivate, start_trial) using a single `type: 'patient_status_update'` channel with `action` for sub-routing.
2. New `sendQuestionnaireFinalizedNotification` for the previously-missing finalize transition.
3. 10 s HTTP timeout added to FCM POST.
4. `fcm_message_id` captured into action audit rows for every transition (DISCONNECT_PATIENT, MARK_NOT_PARTICIPATING, REACTIVATE_PATIENT, RECONNECT_PATIENT, START_TRIAL, QUESTIONNAIRE_DELETED, QUESTIONNAIRE_UNLOCKED, QUESTIONNAIRE_FINALIZED).
5. Replaced leaky `'trial-$patientId'` literal with the new `patient_status_update` channel that includes no patient identifier in the FCM payload.
6. Cross-patient FCM token uniqueness in `registerFcmTokenHandler` — when a re-installed/shared device's token reappears under a different `patient_id`, the old patient's row is deactivated to prevent stale routing.

**Status:** committed; verified locally in console mode (Layer 1 test) — both audit rows write correctly.

### S3 — Mobile stabilize (PENDING)

**Goal:** mobile app correctly handles every notification type the server now sends post-S2. Without this, Phase 1B is theoretical — the dispatcher would receive `patient_status_update` and `questionnaire_finalized` and ignore them.

#### S3.1 — Dispatcher cases for new types

**File:** `apps/daily-diary/clinical_diary/lib/services/task_service.dart`

**Current:** `handleFcmMessage` switches on `type` and handles only `questionnaire_sent` and `questionnaire_deleted`.

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
- Unit-test dispatcher with a fake FCM message map per `(type, action)` pair
- Integration test: emulator + fake FCM push (`adb shell am broadcast -a com.google.firebase.MESSAGING_EVENT --es type ...`)

#### S3.2 — Background handler does real work

**File:** `apps/daily-diary/clinical_diary/lib/services/notification_service.dart:17`

**Current:** top-level `@pragma('vm:entry-point')` `firebaseMessagingBackgroundHandler` only `debugPrint`s. So when the app is backgrounded/terminated and a data-only push arrives, nothing happens until the user opens the app.

**Change:**
1. Initialize a minimal Hive box (background isolate has no shared state).
2. Persist the message to a local outbox (`pending_fcm_messages` Hive box).
3. Schedule a foreground sync when the app resumes.

**Why outbox vs direct task creation:** the background isolate doesn't have full DI/auth state. Persist and let the foreground isolate process on resume. This pattern also matches Phase 1B polling (eventual reconciliation).

**Test plan:** background the app, send a push via console-mode, foreground the app, verify task appears.

#### S3.3 — APNS payload split (server-side, but conceptually S3)

**File:** `apps/sponsor-portal/portal_functions/lib/src/notification_service.dart`

**Current:** all sends use `apns-priority: 10` + `content-available: 1` + alert body. iOS treats this as user-visible AND wakes the app — fine for `questionnaire_sent`, technically wrong for pure data-only updates.

**Change:** add a `userVisible: bool` parameter to `_sendFcmMessage`:
- `true` (questionnaire_sent, finalized, patient_status_update): keep current shape — `priority: 10`, alert + `content-available: 1`
- `false` (future silent state-sync pushes): `priority: 5`, no alert, only `content-available: 1`. Avoids iOS background-wake throttling that priority-10 silent pushes hit.

For Stabilize: all existing sends are user-visible, so this is a no-op behavior-wise — future-proofing the API.

#### S3 PR shape

- Single PR on `feature/cur-826-fcm-stabilize` (keep S1/S2/S3 together).
- Roll forward: server already on this branch; app store release after merge.
- Roll back: revert PR. No DB damage — pure code.

---

## Phase 1A — Bootstrap `comms` package

### Goal

Stand up the full `comms` package — channels, compliance, notifications domain protocol — and migrate the existing FCM transport into it. After Phase 1A, Phase 1B is mostly app-side wiring.

### Why this scope

Bootstrapping the full protocol now (not just FCM transport) means Phase 1B doesn't have to touch the package — it just consumes it. Future apps that adopt notifications get the package's full surface from day one.

### Sub-phases

#### 1A.1 — Package skeleton + transport core

**Files (NEW):**
- `apps/common-dart/comms/pubspec.yaml`
- `apps/common-dart/comms/analysis_options.yaml`
- `apps/common-dart/comms/lib/comms.dart` — barrel re-exporting the public API
- `apps/common-dart/comms/lib/src/channel.dart` — `Channel<T>` + `ChannelMessage` base
- `apps/common-dart/comms/lib/src/dispatch_result.dart` — `DispatchResult`
- `apps/common-dart/comms/lib/src/compliance/payload_guard.dart` — full impl
- `apps/common-dart/comms/test/compliance/payload_guard_test.dart`

**Workspace registration:** add `comms` to root `pubspec.yaml` workspace list (mirror `trial_data_types`).

**`PayloadGuard` regex set** (REQ-d00194-E — "at minimum"):

| Pattern name | Regex | Matches |
|--------------|-------|---------|
| `subject_key_strict` | `\b\d{3}-\d{3}-\d{3}\b` | Spec-mandated SubjectKey: 3-3-3 digits |
| `subject_key_extended` | `\b\d{3}-\d{3}[A-Z]?-\d{3}\b` | Real-world SubjectKeys with optional letter (e.g. `999-001A-125`) |
| `email` | `\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b` | RFC-lite email |
| `common_name` | (per-sponsor configured list, default empty) | Names known to appear in clinical workflows (e.g. coordinator names from sponsor config) |

**Bypass policy (REQ-d00194-H):** production code SHALL NOT bypass. Test fixtures may set `PayloadGuard.testOnlyDisable = true` — checked at runtime via assertion that fails when running with `--release`.

**Test plan:** `dart analyze` clean; `payload_guard_test.dart` covers:
- Each pattern matches a known PHI string
- Each pattern rejects a known-safe lookalike (e.g. `123-45-678` doesn't match SubjectKey because of the `\b` boundaries)
- `'Account Disconnected'` and `'New Questionnaire Available'` (real titles from S2) pass
- Test-only disable flag panics on `--release`

#### 1A.2 — `channels/fcm/` — move FCM transport

**Files (NEW):**
- `apps/common-dart/comms/lib/src/channels/fcm/fcm_channel.dart`
- `apps/common-dart/comms/lib/src/channels/fcm/fcm_message.dart`
- `apps/common-dart/comms/lib/src/channels/fcm/adc_client.dart`
- `apps/common-dart/comms/test/channels/fcm/fcm_channel_test.dart`
- `apps/common-dart/comms/test/channels/fcm/adc_client_test.dart`

**Moves from `portal_functions/lib/src/notification_service.dart`:**
- `_createAdcClient` → `AdcClient.create()`
- `_needsTokenRefresh` / `_refreshIfNeeded` → `AdcClient.refreshIfNeeded()`
- HTTP POST + 10 s timeout + response parsing → `FcmChannel.dispatch(FcmMessage)`

**`FcmChannel` calls `PayloadGuard.assertSafeFcm(message)` before the network call** — fail-closed PHI check.

**Response classification (REQ-d00193-C, D):**

| HTTP status | FCM error | Result | Tag for metric |
|-------------|-----------|--------|----------------|
| 200 | — | `DispatchResult.success(messageId)` | `result=success` |
| 404 | `UNREGISTERED` | `DispatchResult.unregisteredToken()` | `result=unregistered` |
| any other non-200 | any | `DispatchResult.failure(error)` | `result=failed` |

`DispatchResult.unregistered=true` flows up to `OutboxWriter`, which calls `onUnregistered(fcmToken)` so the app can deactivate the stale token row in `patient_fcm_tokens`.

**Metric emission (REQ-d00193-H):**

```dart
metric.increment('comms.fcm.dispatch', tags: {
  'result': result.outcome,                 // 'success' | 'failed' | 'unregistered'
  'notification_type': message.notificationType.name,
});
```

Emitted exactly once per `dispatch()` call, regardless of outcome. Replaces the existing S2 `fcmNotificationSent(messageType, status)` emission so there's one metric site, not two.

**Stays in `notification_service.dart` (Phase 1B sweeps it):**
- The public `sendQuestionnaireNotification` / `sendPatientStatusNotification` methods (thin orchestrators that build `FcmMessage` and call `fcmChannel.dispatch`).
- Audit logging (`_logNotificationAudit`).
- Metrics (`fcmNotificationSent`).
- The `NotificationService` singleton (now holds an `FcmChannel`).

#### 1A.3 — `notifications/` domain protocol

**Files (NEW):**
- `apps/common-dart/comms/lib/src/notifications/notification_type.dart`
- `apps/common-dart/comms/lib/src/notifications/envelope.dart`
- `apps/common-dart/comms/lib/src/notifications/envelope_status.dart`
- `apps/common-dart/comms/lib/src/notifications/repository.dart`
- `apps/common-dart/comms/lib/src/notifications/outbox_writer.dart`
- `apps/common-dart/comms/lib/src/notifications/server/envelope_fetch_handler.dart`
- `apps/common-dart/comms/lib/src/notifications/server/envelope_since_handler.dart`
- `apps/common-dart/comms/lib/src/notifications/client/envelope_fetcher.dart`
- `apps/common-dart/comms/test/notifications/envelope_test.dart`
- `apps/common-dart/comms/test/notifications/outbox_writer_test.dart`
- `apps/common-dart/comms/test/notifications/server/envelope_fetch_handler_test.dart`

**`OutboxWriter.send` flow:**

```dart
class OutboxWriter {
  final NotificationRepository repo;
  final Channel<FcmMessage> channel;
  final Future<void> Function(String fcmToken)? onUnregistered;

  Future<String> send(Envelope envelope, {required String fcmToken}) async {
    PayloadGuard.assertSafe(envelope);                  // PHI check on envelope
    await repo.insertPending(envelope);                 // durability before send
    final message = _toFcmMessage(envelope, fcmToken);
    final result = await channel.dispatch(message);     // PayloadGuard runs again on FcmMessage; metric emitted here

    if (result.unregistered) {
      await repo.markFailed(envelope.notificationId, 'UNREGISTERED');
      if (onUnregistered != null) {
        await onUnregistered!(fcmToken);                // app deactivates the stale token row
      }
    } else if (result.success) {
      await repo.markSent(envelope.notificationId, result.messageId!);
    } else {
      await repo.markFailed(envelope.notificationId, result.error ?? 'unknown');
    }
    return envelope.notificationId;
  }
}
```

**`envelopeFetchHandler` factory:**

```dart
Handler envelopeFetchHandler({
  required NotificationRepository repo,
  required Future<String?> Function(Request) patientResolver,
}) {
  return (Request request) async {
    final patientId = await patientResolver(request);
    if (patientId == null) return Response.unauthorized('...');
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

#### 1A.4 — Wire `portal_functions` to depend on `comms`

**Files:**
- `apps/sponsor-portal/portal_functions/pubspec.yaml` — add `comms: ^0.1.0`
- `apps/sponsor-portal/portal_functions/lib/src/notification_service.dart` — import `package:comms/comms.dart`, hold an `FcmChannel`, build `FcmMessage` objects in orchestrator methods

### Behavior contract after Phase 1A

Runtime behavior of S2 is **unchanged**. Pure refactor — `notifications/` domain code is present but not wired into the request flow. It lights up in Phase 1B.

### Risks & mitigations (Phase 1A)

| Risk | Mitigation |
|------|------------|
| Workspace package not picked up by build/IDE | Mirror `trial_data_types` setup. Verify `dart pub get` + `dart analyze` from root. |
| `comms` accidentally pulls in Flutter SDK | CI lint: `dart pub deps --style=tree` must not list `flutter` under `comms`. Add as a check in `tools/`. |
| `notifications/` domain unused → bitrot | Phase 1B is the immediate consumer. Package-level unit tests guarantee correctness regardless. |
| `PayloadGuard` false positives blocking legit sends | Allow per-call opt-out only in tests; production never bypasses. Tune regex against known-safe strings. |
| `OutboxWriter` over-prescribes the dispatch sequence | Keep it small (one method). If a future channel needs different sequencing, sibling writer in Phase 3. |

### PR shape

- Single PR recommended (1A.1 → 1A.4 as commits). Sub-PR split is OK if reviewer asks.
- Dep order: 1A.1 → 1A.2 → 1A.3 → 1A.4.
- Roll forward: deploy to qa, smoke-test that disconnect/finalize/etc. still produce both audit rows.
- Roll back: revert PR. No DB or runtime state to clean up — `notifications` table doesn't exist yet.

---

## Phase 1B — Envelope pattern + polling

### Goals & invariants

- **Compliance:** zero PHI in FCM payload — only opaque IDs + categorical type.
- **Durability:** every notification written to a `notifications` row **before** FCM dispatch. If FCM fails, row stays `status='pending'` and mobile discovers it via polling.
- **Truth:** mobile polling is source of truth. FCM is a nice-to-have wakeup. `delivered_at` is updated when mobile fetches — that is our delivery confirmation, not the FCM ack.

### Schema

```sql
-- database/migrations/011_create_notifications_table.sql

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

-- RLS policy for participant access
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY notifications_patient_select ON notifications
  FOR SELECT USING (patient_id = current_setting('app.current_patient_id', true));
CREATE POLICY notifications_patient_update ON notifications
  FOR UPDATE USING (patient_id = current_setting('app.current_patient_id', true));
```

### API contract

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

#### `GET /api/v1/notifications/<id>`

Returns a single envelope. Idempotently sets `delivered_at`.

#### Why two endpoints

GET-since is the primary polling endpoint; GET-by-id is for FCM-arrival fast-path and debugging. Both idempotently set `delivered_at` server-side. We deliberately do **not** expose a separate POST `/ack` endpoint — fetching = ack. Simpler, fewer round-trips, and matches the redesign plan's "fetched = delivered" semantic.

If FDA later asks for "user actually saw this" timestamps, add a separate `viewed_at` column updated by an explicit ack endpoint without changing the fetch semantics.

### PR sequence

#### P1B.1 — Schema + Postgres repo impl

**Files:**
- `database/migrations/011_create_notifications_table.sql` (forward + rollback)
- `database/schema.sql` (greenfield)
- `apps/sponsor-portal/portal_functions/lib/src/notifications/pg_notification_repository.dart` (NEW)

**`PgNotificationRepository`** implements `comms` `NotificationRepository`. Uses `Database.executeWithContext` with `UserContext.service` for inserts (system writes) and `UserContext.patient(patientId)` for reads (RLS scopes them).

**Test plan:**
- Migration applies + rolls back cleanly on local DB.
- `PgNotificationRepository` integration-tested against the docker postgres.
- EXPLAIN of polling query shows `notifications_patient_pending_idx` used.
- RLS test: spin up two participant JWTs; participant A cannot read/update participant B's rows.

**Rollback:** drop notifications table, drop type. Safe — table is new.

#### P1B.2 — Route ONE handler through `OutboxWriter` (proof of concept)

**Choice:** `disconnectPatientHandler`.

**Behavior:** the handler builds an `Envelope` and calls `outboxWriter.send(envelope, fcmToken: ...)`. The audit row keeps including `fcm_message_id`.

```dart
final envelope = Envelope.patientStatusUpdate(
  patientId: patientId,
  title: 'Account Disconnected',
  body: 'Your study account has been disconnected. ...',
  payload: {'action': 'disconnect', 'new_status': 'disconnected'},
);
final notificationId = await outboxWriter.send(envelope, fcmToken: fcmToken);
// fcm_message_id can be looked up from the row OR returned from outboxWriter.send
```

**Feature flag:** `FCM_USE_ENVELOPE_DISCONNECT=true` — server-side env. Default OFF.

**Test plan:** local console-mode test:
- Flag off: behavior identical to S2 (`DISCONNECT_PATIENT` row + `FCM_NOTIFICATION` audit row).
- Flag on: same audit rows + new `notifications` row (status `pending → sent`).

**Rollback:** flag off.

#### P1B.3 — Migrate remaining server senders

Per-handler env flag. Same call-site shape as P1B.2 for: `questionnaire_sent`, `questionnaire_deleted`, `questionnaire_unlocked`, `questionnaire_finalized`, `mark_not_participating`, `reactivate`, `reconnect`, `start_trial`. Each handler is ~10 lines because `OutboxWriter` does the heavy lifting.

**Send-handler suppression rules (REQ-d00182-B, C):** the questionnaire-sent migration adds two pre-flight checks inside the same transaction as the outbox insert:

- **Already submitted** — skip outbox insert if the questionnaire's `submitted_at IS NOT NULL` at trigger time (handles re-trigger after submission).
- **Called back** — skip outbox insert if the questionnaire is in a called-back state at trigger time (the existing soft-deleted/recalled check used by the portal-ui).

Suppression is silent: no notification row, no FCM dispatch, no audit. Returns the action's normal success response. The S2 send handler currently does NOT enforce these — adding the checks is part of P1B.3, not a separate ticket.

**Cleanup at end of P1B.3:** remove `_logNotificationAudit` writes from `notification_service.dart`. With the outbox in place, `notifications` IS the send audit trail. Keep the **action** audit row (e.g., `DISCONNECT_PATIENT`); only stop writing the redundant `FCM_NOTIFICATION` row. Migration 010 stays in place.

#### P1B.4 — Mount API on `diary_server`

**File:** `apps/daily-diary/diary_server/lib/server.dart` (route registration)

```dart
import 'package:comms/comms.dart';

final notificationRepo = PgNotificationRepository(db: db);
final patientResolver = (Request req) async {
  final auth = verifyAuthHeader(req.headers['authorization']);
  if (auth == null) return null;
  return await lookupPatientByAuth(auth);
};

router.get('/api/v1/notifications/<id>',
  envelopeFetchHandler(repo: notificationRepo, patientResolver: patientResolver));
router.get('/api/v1/notifications',
  envelopeSinceHandler(repo: notificationRepo, patientResolver: patientResolver));
```

**RLS test:** participant A's token cannot fetch participant B's notifications.

#### P1B.5 — Mobile polling integration

**Files (NEW):**
- `apps/daily-diary/clinical_diary/lib/services/notification_poll_service.dart`

**Uses `EnvelopeFetcher` from `comms`** — mobile doesn't reimplement the wire format or URL paths.

**Triggers (REQ-d00195-F, G):**
1. App startup (cold start, after auth init).
2. App resume from background (lifecycle observer).
3. FCM arrival (foreground or via background-handler outbox replay) — trigger an immediate poll. The FCM payload's `notification_id` is treated as a **hint to poll**, not a navigation target.
4. Periodic background poll while app foregrounded (every 60 s) — REQ-d00195-G default; sponsor-configurable.
5. Pull-to-refresh on the main task list.

**Cold-start sequence (REQ-d00196 — always Main Screen, no deep-link):**

```
1. Flutter init
2. Hive open + read auth state
3. If authenticated:
   a. Fetch participant context
   b. POLL /api/v1/notifications?since=<lastSeen>
   c. Apply incoming envelopes (mutate local state — task list, disconnection notice, badge)
4. Render Main Screen — always
```

If launched from a notification tap: `FirebaseMessaging.getInitialMessage()` is consumed only to confirm a poll is needed (which it always is on cold start anyway). The `notification_id` in the tap payload is **not** used for navigation. `payload.action` is used to mutate local state (e.g. `lock_task` for `questionnaire_finalized`) but never to navigate.

**Cursor storage and lifecycle (REQ-d00195-H, I, K):**

| Key | Storage | When written | When read |
|-----|---------|--------------|-----------|
| `notification_lastSeen` | Hive | After every successful poll → set to `server_time` from response | On every poll → sent as `since=` |
| `notification_recent_ids` | Hive (Set, rolling 500 entries) | When an envelope is applied to local state | Before applying — if id already present, skip (REQ-d00195-J dedupe across FCM + polling) |

**Bootstrap (first launch ever):** `notification_lastSeen` is null → poll uses `since = now() - 30 days`. Bounded fetch; older notifications are stale in clinical-trial context.

**Lifecycle reset (REQ-d00195-K):** clear both `notification_lastSeen` and `notification_recent_ids` on:
- `AuthService.signOut()` — explicit logout
- `PatientLinkingService.unlink()` — participant unlinked from device (covered by `disconnect` and `mark_not_participating` actions)

**Dispatch on arrival:** map `Envelope.type` → existing handler:
- `questionnaireUpdate` → `task_service.handleEnvelope(envelope)`
- `patientStatusUpdate` → `enrollment_service.handleEnvelope(envelope)`
- `reminder` → reminder service

**Reactivity (REQ-d00198):** the mobile state-management layer (the existing reactive store in `clinical_diary`) MUST propagate state changes triggered by an applied envelope within 1 second. No artificial debounce on the apply path. Verified via integration test: insert a row server-side, observe Task List updates in ≤ 1 s on the device.

**Test plan:**
- Integration test on emulator — start app, no notifications visible. Server-side: insert a row directly. Mobile: verify it appears within 60 s without any FCM.
- Dedupe test: deliver the same `notification_id` via both FCM and polling; verify the apply-handler runs exactly once.
- Logout test: sign out, sign back in as a different participant; verify polling does not return any of the previous participant's envelopes.
- Cold-start test: tap a push from terminated state; verify app lands on Main Screen, not the questionnaire / disconnection screen.

#### P1B.6 — Cleanup + retire old direct-FCM path

After 2 weeks of envelope-on in production with no incidents:
- Flip default for all per-handler flags to ON.
- Remove the direct-FCM code paths (the `if (notificationTitle != null)` branch in `_sendFcmMessage`).
- Remove orchestrator methods on `NotificationService` that aren't used by `OutboxWriter` (`sendQuestionnaireNotification`, `sendPatientStatusNotification`, etc.).
- Remove feature flags.

### Risks & mitigations (Phase 1B)

| Risk | Mitigation |
|------|------------|
| Outbox row commits but FCM dispatch crashes process before `markDispatched` | Row stays `pending`. Mobile polling discovers it. Reconciler in Phase 2 re-attempts pending rows >5 min old. |
| Mobile fetches notification but crashes before ack | `delivered_at IS NULL` → next poll re-fetches. Idempotent UI consumes by `notification_id`. |
| Cutover double-fires (old path + envelope) | Per-handler feature flag. Default OFF. Validate per-handler before flipping. |
| `delivered_at` race: server INSERT not yet committed when mobile polls | Outbox INSERT in same transaction as the action. Mobile won't see uncommitted rows. |
| Participant with multiple devices: which device wins on `delivered_at`? | First device to fetch wins. Other devices fetch but `markDeliveredIfNull` is a no-op. |
| Schema migration deployed but P1B.2 code not deployed | Safe — empty table sits unused. |
| RLS misconfigured → participant sees other participants' notifications | RLS test in CI: spin up two participant JWTs, attempt cross-participant read, expect 0 rows. |

---

## Phase 1C — Yesterday Reminder scheduler

### Goal

Implement the one server-side scheduled job currently in spec scope: the Yesterday Entry Reminder (REQ-d00200, REQ-d00201). The job evaluates each active participant once per local calendar day at the configured Reminder Time, suppresses if a Daily Status already exists for the previous local day, and idempotently writes a `notifications` row via `OutboxWriter`. Phase 1B's polling delivers it to the device.

### Scope

#### P1C.1 — Cron infrastructure + Yesterday Reminder

**Trigger mechanism:** Cloud Scheduler → HTTPS POST → `portal_server` cron route group, authenticated via OIDC token from the scheduler's SA.

**Cron cadence:** every 5 minutes (a participant whose local 09:00 falls in any 5-minute bucket gets evaluated when that bucket's job fires).

**Eligibility (REQ-d00200 A–D, REQ-d00201):** for each active participant with a registered `device_timezone`:
1. Compute `now()` in that timezone.
2. If the participant's local clock is currently in the configured `Yesterday Reminder Time` window (e.g. 09:00–09:04 for cadence 5 min) — proceed; otherwise skip.
3. If a `daily_status` row exists for the participant's previous local calendar day — skip (REQ-d00201-A).
4. If a `notifications` row already exists with `reminder_kind='yesterday_entry'` and `payload.for_date` equal to the previous local calendar day — skip (idempotency, REQ-d00200-D).
5. Otherwise: write to outbox.

**Outbox payload (REQ-d00200-G):**
```json
{
  "notification_type": "reminder",
  "title": "<Yesterday Reminder Text from sponsor config>",
  "body": null,
  "payload": {
    "reminder_kind": "yesterday_entry",
    "action": "yesterday_entry",
    "for_date": "2026-05-06"
  }
}
```

**Files (NEW):**
- `apps/sponsor-portal/portal_server/lib/cron_routes.dart` — route group `/admin/cron/<job>` with OIDC verification
- `apps/sponsor-portal/portal_functions/lib/src/scheduler/cron_auth.dart` — verify Cloud Scheduler OIDC token
- `apps/sponsor-portal/portal_functions/lib/src/scheduler/eligibility_helper.dart` — common helpers (timezone arithmetic, day-bucket calculations)
- `apps/sponsor-portal/portal_functions/lib/src/scheduler/yesterday_reminder_job.dart`
- `apps/sponsor-portal/portal_functions/test/scheduler/yesterday_reminder_job_test.dart`
- `database/migrations/012_add_device_timezone_to_fcm_tokens.sql` — adds `device_timezone text NOT NULL DEFAULT 'UTC'` to `patient_fcm_tokens`
- `apps/daily-diary/diary_functions/lib/src/fcm_token.dart` — accept + persist `device_timezone` on registration (REQ-d00200-E)
- `apps/daily-diary/clinical_diary/lib/services/fcm_token_registration.dart` — include current IANA timezone (`flutter_timezone` package) on every registration and on timezone change

**Sponsor config slot (REQ-d00200-F):** `Yesterday Reminder Time` — `LocalTime` (HH:MM). Sourced from the existing sponsor-config interface in `apps/common-dart/shared_functions/`. When unset, the job no-ops (and logs WARN once at startup).

The cron infrastructure (`cron_routes.dart`, `cron_auth.dart`, `eligibility_helper.dart`) is built generically so future scheduler jobs (Lock Warning, Epistaxis Reminder, Historical Gap Reminder, etc.) can plug in without re-architecting. Currently only the Yesterday Reminder consumes it.

### Phase 1C risks & mitigations

| Risk | Mitigation |
|------|------------|
| Cron job duplicate-fires (Cloud Scheduler retry on transient failure) | Idempotency-via-row-presence: second invocation finds the existing notifications row and skips |
| Server clock drift | Time comparisons use `now()` from Postgres, not the app server; participant timezone resolved from `device_timezone` column |
| Mobile fails to send timezone → defaults to UTC | Reminder fires at UTC 09:00 instead of local 09:00. Acceptable degraded behaviour; logs warn once per participant/day |
| `Yesterday Reminder Time` config missing | Eligibility evaluator short-circuits on missing config; emits a WARN log once at startup |
| Cron auth bypass | OIDC token verification + Cloud Scheduler SA allowlist; bare HTTP request returns 401 |

### Phase 1C PR shape

Single PR (P1C.1 above). Roll forward: deploy with cron trigger paused; flip on once eligibility queries verified against qa data.

---

## Phase 2 — Reconciler & observability

**Out of scope for this plan; high-level only.**

- Background job (Cloud Run scheduled invocation OR cron) that scans `notifications` for rows with `status='pending'` and `created_at < now() - interval '5 minutes'`, attempts re-dispatch.
- Cap retries at 3 with exponential backoff; mark `failed` after that.
- Metrics: `notifications_pending_total`, `notifications_failed_total`, `notifications_redispatch_attempts_total`, `notifications_delivered_lag_seconds` (histogram of `delivered_at - created_at`).
- Grafana dashboard: pending count, failure rate, delivery lag p50/p95.

---

## Phase 3 — `EmailChannel` + `SlackChannel`

**Out of scope for this plan; high-level only.**

- Move `apps/sponsor-portal/portal_functions/lib/src/email_service.dart` into `apps/common-dart/comms/lib/src/channels/email/`.
- New `EmailMessage`, `EmailChannel`, `dwd_client.dart` (domain-wide delegation auth — different from FCM's straight ADC).
- Add `SlackChannel` with webhook-based dispatch.
- Per-channel `OutboxWriter` siblings if recipient addressing differs sufficiently (likely yes).
- May extend `notification_type` enum to add `audit_alert` (for ops Slack pings), `coordinator_email`, etc.

---

## Phase 4 — Terraform / IaC

**Out of scope for this plan; high-level only.**

- Codify cross-project IAM grants in `terraform/` so new sponsor onboarding is `terraform apply` rather than the runbook in `docs/cross-project-iam-runbook.md`.
- Modules: per-feature IAM grants on `cure-hht-admin`, sponsor compute SA bindings, WIF pool config.

---

## Cross-cutting concerns

### Compliance (FDA 21 CFR Part 11 / HIPAA)

- Every notification send has a durable audit trail: `notifications` row (Phase 1B) + `admin_action_log` action row (already in S2).
- `PayloadGuard` runs before every send (in `OutboxWriter.send` AND `FcmChannel.dispatch`) — defense in depth.
- `delivered_at` provides a "received" timestamp the auditor can rely on.
- All channels use cryptographically-tamper-evident audit logging via existing `admin_action_log` triggers.

### Testing strategy

| Layer | What | Tools |
|-------|------|-------|
| Unit (package) | `Channel`, `OutboxWriter`, `PayloadGuard`, handlers, `EnvelopeFetcher` with fakes | `dart test` |
| Unit (app) | `PgNotificationRepository`, route mounting | `dart test` against docker postgres |
| Integration | Console-mode end-to-end: trigger handler → audit rows + notifications row | local server + docker postgres |
| Integration (qa) | Real FCM end-to-end: trigger handler → real device receives push → fetches envelope | callisto4-qa + real Android/iOS device |
| RLS | Cross-participant access attempts must return 0 rows / 403 | `dart test` integration suite |
| Mobile dispatcher | Each `(type, action)` pair routes to correct handler | flutter test |
| Mobile polling | Server-inserted row appears in app within 60 s without FCM | emulator integration |

### Local development

```bash
# Start docker postgres
docker compose -f docker-compose.db.yml up -d

# Apply migrations
docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal \
  < database/migrations/011_create_notifications_table.sql

# Run portal_server (console mode = no real FCM)
cd apps/sponsor-portal/portal_server
FCM_CONSOLE_MODE=true ./tool/run_local.sh

# Trigger a transition
curl -X POST http://localhost:8084/api/v1/portal/patients/disconnect \
  -H "Authorization: Bearer <investigator-token>" \
  -H "Content-Type: application/json" \
  -d '{"patientId": "999-001A-125", "reason": "Subject Withdrawal"}'

# Verify
docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal -c "
  SELECT notification_id, notification_type, status FROM notifications
  WHERE patient_id = '999-001A-125' ORDER BY created_at DESC LIMIT 5;
"
```

### Deployment & rollout

- Each phase ships behind feature flags where applicable (P1B.x).
- Roll forward: qa first, soak 1 week, then production.
- Roll back: flag flip; schema rollbacks only if explicitly required.
- New sponsor onboarding: see `docs/cross-project-iam-runbook.md` (Phase 4 will codify in Terraform).

### Observability

- Metrics emitted today: `fcm_notifications_total{message_type, status}`.
- Add in Phase 1B: `notifications_inserted_total{type}`, `notifications_dispatched_total{status}`, `notifications_polled_total`, `notifications_delivered_lag_seconds`.
- Logs: structured JSON, trace correlation. `logWithTrace('INFO', 'envelope dispatched', labels: {...})`.

### Multi-sponsor impact

- `comms` is a shared workspace package — all sponsors get the same protocol.
- Each sponsor wires its own `PgNotificationRepository` (sponsor schema) and `patientResolver` (sponsor auth).
- Per-sponsor flags can override per-handler envelope adoption if a sponsor wants to lag the rollout.

---

## Risks & mitigations

(Aggregated from per-phase risks above; see each phase for context.)

| Risk | Phase | Mitigation |
|------|-------|------------|
| Workspace package not picked up | 1A | Mirror `trial_data_types` exactly |
| `comms` pulls in Flutter | 1A | CI dep-tree check |
| `PayloadGuard` false positives | 1A | Tune regex; allow opt-out only in tests |
| Outbox row commits but dispatch crashes | 1B | Phase 2 reconciler |
| Cutover double-fires | 1B | Per-handler feature flags |
| RLS misconfigured | 1B | Cross-participant access CI test |
| Participant with multiple devices | 1B | First-fetch wins; idempotent ack |
| Email/Slack auth model differs from FCM | 3 | Sibling writers, not unified |

---

## Estimate

| Phase | Days | PRs |
|-------|------|-----|
| Phase 0 (DONE) | — | — |
| S1 (DONE) | — | — |
| S2 (DONE) | — | — |
| **S3** | 1 | 1 |
| **Phase 1A** | 3 | 1 (or 3 sub-PRs) |
| **P1B.1** | 1 | 1 |
| **P1B.2** | 0.5 | 1 |
| **P1B.3** | 2 | 1–3 |
| **P1B.4** | 0.5 | 1 |
| **P1B.5** | 2.5 | 1 |
| **P1B.6** | 0.5 | 1 |
| **P1C** (cron infra + Yesterday Reminder + migration 012 + mobile timezone + config slot) | 3 | 1 |
| **Total remaining** | **~14** | **~9–11** |

Plus 2 weeks of soak time before P1B.6.

**Note on P1C scope:** the cron infrastructure (`cron_routes.dart`, `cron_auth.dart`, `eligibility_helper.dart`) is sized for one job today but built generically so future scheduler additions (Lock Warning, Epistaxis Reminder, Historical Gap Reminder — see "Plan provenance" §C for the deferred list) can plug in without re-architecting.

**Estimate history:** the plan was at ~10 days remaining after the FCM redesign; expanded to ~23 days when the wider notifications spec was reviewed (4 schedulers, 4 mobile UI surfaces, 9 config slots); narrowed back to ~14 days when the spec was trimmed to keep only Section 1 foundation + Yesterday Reminder + reactive task list updates + send-handler suppression.

---

## Decision points / open questions

1. **Package name and location.** Proposing `apps/common-dart/comms/`. Open to `messaging`, `comms_common`, or another suggestion.
2. **S3 first, or Phase 1A in parallel?** Both are independent. Recommendation: land S3 first to close out Stabilize.
3. **Phase 1A as one PR or three?** Single PR is reviewable but heavy (~12 new files + tests). Three sub-PRs trade reviewer load for sequencing overhead. Recommendation: start as one; split if reviewer asks.
4. **Schema (P1B.1) before, after, or alongside Phase 1A?** Schema is independent. Recommendation: land Phase 1A first so 1B.1 includes the Postgres repo impl alongside the migration.
5. **Per-handler flag granularity in P1B.3.** One per handler (8 flags) vs one per `notification_type` (3 flags). Recommendation: one per handler — most rollback granularity at low cost.
6. **Ack-on-fetch vs ack-on-display in P1B.5.** Ack-on-fetch is simpler. Defer ack-on-display unless FDA auditor asks for it.
7. **Reconciler in Phase 1B or Phase 2?** Phase 2. P1B covers the happy path + polling-as-fallback.
8. **When does `email_service.dart` move into `comms`?** Phase 3. Email uses domain-wide delegation (signJwt) — different auth model from FCM's straight ADC. Conflating both auth models in one Phase-1A PR adds risk for no immediate benefit.
9. **Should `OutboxWriter` be channel-agnostic?** Today coupled to FCM. For email/slack, addressing differs. Recommendation: keep `OutboxWriter` FCM-coupled for now; add sibling writers per channel in Phase 3.
10. **`expires_at` on `notifications` rows?** Some notifications (questionnaire_sent for an expired questionnaire) become stale. Defer; mobile UI can hide based on the underlying questionnaire state. Revisit if cleanup becomes painful.
11. **Per-sponsor isolation in `notifications`?** Currently the table sits in the shared schema; `patient_id` naturally scopes by sponsor. Verify with RLS testing.
12. **Cloud Tasks for outbox retry (Phase 2) vs cron-based reconciler?** Cloud Tasks is more accurate but adds infra. Cron is simpler. Decide when we get to Phase 2.
13. **Does `comms` need `otel_common` dep, or should observability be injected by the consumer?** Initial proposal: depend directly (matches what `notification_service.dart` does today). Revisit if `comms` is consumed outside the GCP/OTel-instrumented services.
14. **`FcmChannel` lifecycle.** Singleton-per-app or instance-per-call? Today's `NotificationService` is a singleton. Recommendation: instance-per-app (one per server boot); the package itself doesn't enforce singleton — consumer manages lifecycle.
15. **`PayloadGuard` regex tuning** (Gap 5 / REQ-d00194-E). The spec mandates `\d{3}-\d{3}-\d{3}` for SubjectKey, but real-world IDs include a letter (e.g. `999-001A-125`). Plan ships both the strict spec regex AND an extended regex that covers the real format. Open: should `common_name` patterns be configured per-sponsor (proposed), or is a platform-default name list sufficient?
16. **Dedupe set size and eviction** (Gap 6 / REQ-d00195-J). Plan uses a Hive `Set<String>` capped at 500 entries with FIFO eviction. Alternative: time-based eviction (drop ids older than 7 days). 500 entries comfortably covers a high-volume month for one participant. Revisit if participants accumulate >500 notifications between launches.
17. **Bootstrap window for first-launch `lastSeen`** (Gap 3). Plan uses 30 days. Could go 90 days (more historical recovery) or epoch (full backfill). 30 is a reasonable clinical-trial default; revisit if participants report missed historical notifications.
18. **Cron mechanism for Phase 1C.** Plan proposes Cloud Scheduler → HTTPS → portal_server cron route group, OIDC-authenticated. Alternative: an in-process scheduler in portal_server (simpler, no GCP dependency for local dev) but loses durability across deploys. Recommendation stays with Cloud Scheduler.
19. **Suppression rules in P1B.3** (REQ-d00199-B, C). Plan adds two pre-flight checks (already-submitted, called-back) inside the same transaction as the outbox insert. Open: define the exact "called-back" predicate against the current questionnaire schema before P1B.3 lands.
20. **Deferred scope in dev-notifications-v2.md.** The spec has been narrowed since the previous gap analysis: Lock Warning, Epistaxis Reminder, Historical Gap Reminder, Task List domain, Disconnection Notification, Participation Status Badge, and most sponsor config slots have been removed. If they return, Phase 1C's cron infrastructure is reusable for the schedulers; the mobile UI work would need its own planning pass.

---

## Glossary

| Term | Meaning |
|------|---------|
| **Envelope** | A row in the `notifications` table. Contains the title/body the participant sees and a JSONB payload for app-specific routing. |
| **Channel** | A transport (FCM, email, Slack). Each channel implements `Channel<T>.dispatch(T) → DispatchResult`. |
| **OutboxWriter** | The persist-then-dispatch helper. Writes a `pending` envelope, calls `Channel.dispatch`, marks `sent` or `failed`. |
| **NotificationRepository** | The interface the package needs against the `notifications` table. Apps provide a Postgres impl. |
| **PHI guard** | The compliance check that rejects sends if title/body/payload contains anything resembling PHI. |
| **Polling fallback** | Mobile app periodically fetches `GET /notifications?since=<ts>` so missed FCM pushes are recovered. |
| **`delivered_at`** | Server-side timestamp set when mobile fetches an envelope. Acts as the delivery confirmation; replaces FCM's "ack" semantics. |
| **WIF / ADC** | Workload Identity Federation / Application Default Credentials. How Cloud Run obtains FCM tokens without key files. |
| **Cross-project IAM** | The grant on `cure-hht-admin` that lets a sponsor's compute SA send FCM through the shared Firebase project. |
| **Stabilize** | The Phase-0-prerequisite work (S1, S2, S3) that fixes critical bugs in the current direct-FCM path before the architectural Phase 1 refactor. |
