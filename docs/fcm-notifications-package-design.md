# `comms` Package — Design & Usage

> **⚠️ SUPERSEDED DESIGN.** This document originally described an `fcm_notifications` package — a domain-layer library that owned envelopes, repositories, and handlers. That direction has been replaced by a thinner, multi-channel `comms` package per [docs/fcm-next-phase-plan.md](./fcm-next-phase-plan.md).
>
> **What's current:** see `fcm-next-phase-plan.md` § "Architectural Decision: Unified `comms` package" and § "Phase 1A — Extract `comms` package". Short version:
>
> - Package lives at `apps/common-dart/comms/`
> - Contains a thin `Channel<T>` interface + `FcmChannel` (today). `EmailChannel` / `SlackChannel` join in Phase 3.
> - Does **not** own envelope types, repository interfaces, server handlers, or mobile receivers — those stay in `portal_functions/` and `clinical_diary/`. The package is transport-only.
>
> **Why the change:** the original design conflated "FCM transport" with "notification domain logic + outbox + polling API". The new direction separates them: `comms` is the dial tone, `notifications` table + outbox + polling are the application's notification feature built on top.
>
> The historical design below is kept for reference — particularly the PHI-guard idea, which remains valid for Phase 1B's outbox layer regardless of where it physically lives.

---

## Historical design (original `fcm_notifications` package)

Companion to `docs/fcm-notification-redesign-plan.md` and `docs/fcm-notification-implementation-plan.md`. This document describes the new shared package introduced in Phase 1: what each file does, why it's structured this way, and how the consuming apps (portal_server, diary_server, clinical_diary) wire it in.

## The big idea

Today, FCM logic is **smeared across three places**: portal_functions has the sender, diary_functions has the token registration, and clinical_diary has the receiver. They each duplicate auth, payload shape, schema knowledge, and PHI-leak risk.

The package collapses that into **one place that owns the FCM contract**: types, the wire format, the sender, the receiver, the API handlers, and the compliance guards. The consuming apps supply only the I/O adapters (a Postgres repo, an HTTP client, a JWT→patient resolver).

Think of the package as the **library that knows the protocol**; the apps are the things that know their own database and auth.

## Package layout (final state, after P1.1 + P1.3 + P1.6)

```
apps/common-dart/fcm_notifications/
├── pubspec.yaml
├── analysis_options.yaml
├── lib/
│   ├── fcm_notifications.dart                 # public exports
│   └── src/
│       ├── types/
│       │   ├── notification_type.dart         # enum: questionnaire_update | patient_status_update | reminder
│       │   ├── envelope.dart                  # the row that the server stores + mobile fetches
│       │   ├── envelope_status.dart           # pending | sent | failed | delivered
│       │   └── send_result.dart               # per-token send outcome
│       ├── compliance/
│       │   └── payload_guard.dart             # regex-based PHI checker, called before every send
│       ├── repository/
│       │   ├── notification_repository.dart   # interface — apps implement against their DB
│       │   └── fcm_token_repository.dart      # interface — same
│       ├── sender/                            # SERVER-SIDE
│       │   ├── adc_client.dart                # ADC bearer token rotation for cross-project FCM
│       │   └── fcm_sender.dart                # POST messages:send, classify response, deactivate UNREGISTERED
│       ├── handlers/                          # SERVER-SIDE shelf handlers
│       │   ├── envelope_fetch_handler.dart    # GET /notifications/{id}
│       │   ├── envelope_since_handler.dart    # GET /notifications?since=
│       │   ├── token_registration_handler.dart# POST /fcm-token
│       │   └── token_delete_handler.dart      # DELETE /fcm-token
│       └── receiver/                          # MOBILE-SIDE
│           ├── fcm_receiver.dart              # subscribes to FCM, dispatches by envelope.notification_type
│           ├── envelope_fetcher.dart          # GET /notifications/{id} from the device
│           └── local_notifications.dart       # wraps flutter_local_notifications for tray rendering
└── test/...
```

## File-by-file purpose

### `types/`

- **`notification_type.dart`** — the three-value enum that mirrors the Postgres enum. Top-level routing. Stable; rarely grows.
- **`envelope.dart`** — the data class for one notification row. Fields: `notificationId` (UUID), `patientId`, `notificationType`, `title`, `body`, `payload` (Map), `status`, `createdAt`, `sentAt`, `deliveredAt`. Has `toJson` / `fromJson` that the API handlers and the mobile receiver share — one wire format, one place.
- **`envelope_status.dart`** — the four-state machine. Used by the sender to mark `sent` / `failed` and by the API handlers to mark `delivered`.
- **`send_result.dart`** — what `FcmSender.send()` returns: per-token `{token, success, messageId?, errorCode?}`. Lets the caller log per-token outcomes without recomputing them.

### `compliance/payload_guard.dart`

A **single function, called twice**: once in `FcmSender.send()` before the network call, once in `NotificationRepository.insert()` before the row hits Postgres. It runs regex against `title`, `body`, and the serialized `payload` looking for SubjectKey (`\d{3}-\d{3}-\d{3}`), email, common name patterns. Throws `PhiLeakException` if anything matches. Belt-and-braces — if a developer accidentally interpolates `$patientName` into a title, the guard rejects it before the row is written or sent.

### `repository/notification_repository.dart` and `fcm_token_repository.dart`

**Interfaces, not implementations.** This is the seam between the package and the consuming app's database.

```dart
abstract class NotificationRepository {
  Future<void> insert(Envelope envelope);
  Future<Envelope?> findById(String notificationId, {required String patientId});
  Future<List<Envelope>> findSince(DateTime since, {required String patientId});
  Future<void> markSent(String notificationId, String messageId);
  Future<void> markFailed(String notificationId, String error);
  Future<void> markDeliveredIfNull(List<String> notificationIds, String patientId);
}
```

```dart
abstract class FcmTokenRepository {
  Future<List<FcmToken>> findActiveTokens(String patientId);
  Future<void> register({required String patientId, required String fcmToken, required String platform, required String deviceId});
  Future<void> deactivateByToken(String fcmToken);                 // UNREGISTERED self-heal
  Future<void> deactivateAllForPatient(String patientId);          // disconnect / not-participating
  Future<void> deactivateOtherPatientsWithToken(String fcmToken, String patientId); // shared device fix
}
```

The package never imports `package:postgres` — only the apps do. This keeps the package free of any DB dependency and means tests use fake repos.

### `sender/`

- **`adc_client.dart`** — fetches an ADC bearer token via Workload Identity Federation, caches it, refreshes 5 minutes before expiry. Today this lives in `notification_service.dart` mixed in with payload building; we hoist it here so it's reusable and testable.
- **`fcm_sender.dart`** — `send(envelope, tokens)`:
  1. `PayloadGuard.assertNoPhi(envelope)` — fail-closed.
  2. Builds the wire payload: `{data: {notification_id}, notification: {title: '<generic>'}, android: {...}, apns: {...}}` — picking user-visible vs data-only APS shape per envelope type.
  3. POSTs to `https://fcm.googleapis.com/v1/projects/cure-hht-admin/messages:send` per token, with a 10-s timeout.
  4. Classifies response — 200 = success (collect `message_id`), 404 UNREGISTERED = call `tokenRepo.deactivateByToken`, anything else = failure.
  5. Returns `List<SendResult>`. Caller decides what to do (typically: `notificationRepo.markSent` on any success, `markFailed` if all tokens failed).

  No retry. That's the whole point — polling carries reliability, not the sender.

### `handlers/`

These are `shelf.Handler` factories. Each takes the repos + a `PatientResolver` callback (the app's logic for "JWT → patient_id") and returns a handler ready to mount on a router.

- **`envelope_fetch_handler.dart`** — `GET /notifications/{id}`. Verifies JWT, resolves patient, looks up the envelope, **rejects if `envelope.patient_id != caller's patient`** (defense in depth — RLS already covers it, but the handler doesn't trust RLS alone), idempotently sets `delivered_at`, returns the envelope as JSON.
- **`envelope_since_handler.dart`** — `GET /notifications?since=<ts>`. Same auth pattern; bulk version. Sets `delivered_at` on every returned envelope. **This is the polling endpoint** — it's the primary catch-up for missed pushes, so it has to be correct.
- **`token_registration_handler.dart`** — `POST /fcm-token`. Hoists today's `registerFcmTokenHandler` from diary_functions, plus the **shared-device fix** (Issue #1): deactivate any other patient's row holding the same token before inserting.
- **`token_delete_handler.dart`** — `DELETE /fcm-token`. Brand new endpoint (Issue #8). Mobile calls it on logout / unlink; server marks the row `is_active=false`.

### `receiver/` (mobile)

- **`fcm_receiver.dart`** — the new `MobileNotificationService`. One subscriber for FCM that handles foreground / background / terminated through the same code path. On every message it pulls `notification_id`, hands it to `EnvelopeFetcher`, then dispatches by `envelope.notificationType` to a handler the app registered (`onQuestionnaireUpdate`, `onPatientStatusUpdate`, etc.). The app supplies the handlers; the package owns the routing.
- **`envelope_fetcher.dart`** — `GET /notifications/{id}` from the device, with the app's auth header. Uses the app's `http.Client` so retries / cert pinning / interceptors are inherited.
- **`local_notifications.dart`** — thin wrapper around `flutter_local_notifications` to render the tray entry from `envelope.title` / `envelope.body`. Centralizes the iOS/Android channel setup so the app doesn't redo it.

## How each app consumes the package

The package is dependency-injected — apps **wire** their adapters and **register** the handlers/receiver. No singletons, no hidden state.

### portal_server / portal_functions (sender side)

```dart
// In portal_server bootstrap
final notificationRepo = PgNotificationRepository(pool);          // app-owned impl
final tokenRepo = PgFcmTokenRepository(pool);                     // app-owned impl
final adcClient = AdcClient();                                    // package-provided
final fcmSender = FcmSender(
  adcClient: adcClient,
  fcmProjectId: 'cure-hht-admin',
  tokenRepo: tokenRepo,                                           // for UNREGISTERED self-heal
);

// In every handler that mutates patient/questionnaire state:
final envelope = Envelope.questionnaireSent(
  patientId: pid,
  questionnaireInstanceId: id,
  questionnaireType: 'nose_hht',
);
await notificationRepo.insert(envelope);                          // PHI guard runs here
final tokens = await tokenRepo.findActiveTokens(pid);
final results = await fcmSender.send(envelope, tokens);           // PHI guard runs here too
await _recordSendOutcome(notificationRepo, envelope, results);
```

That's the **whole** send call site — no more 30-line copy-pasted token-lookup blocks.

### diary_server / diary_functions (mobile-API side)

```dart
// In diary_server route registration
final patientResolver = (Request req) async {
  final claims = await verifyJwt(req);
  return await lookupPatientByLinkingCode(claims.sub);
};

router.get('/api/v1/notifications/<id>',
  envelopeFetchHandler(notificationRepo, patientResolver));
router.get('/api/v1/notifications',
  envelopeSinceHandler(notificationRepo, patientResolver));
router.post('/api/v1/user/fcm-token',
  tokenRegistrationHandler(tokenRepo, patientResolver));
router.delete('/api/v1/user/fcm-token',
  tokenDeleteHandler(tokenRepo, patientResolver));
```

diary_server stops owning any FCM logic — it just mounts the handlers from the package.

### clinical_diary (receiver side)

```dart
// In clinical_diary main / bootstrap
final receiver = FcmReceiver(
  envelopeFetcher: EnvelopeFetcher(httpClient, baseUrl),
  localNotifications: LocalNotificationsAdapter(),
  onQuestionnaireUpdate: (env) => taskService.handleQuestionnaireUpdate(env),
  onPatientStatusUpdate: (env) => enrollmentService.handlePatientStatusUpdate(env),
  onReminder: (env) => reminderService.handle(env),
);
await receiver.start();
```

`task_service.dart` and `enrollment_service.dart` keep owning the **business logic** of "what does a sent questionnaire mean for the task list?" — the package owns the **plumbing** of "how do I get the envelope from FCM to that handler?"

## Why this split is the right one

- **Contract in one place.** Anyone who wants to know "what does an FCM message look like in this system?" reads `envelope.dart` + the handler files. Today they'd have to read three apps.
- **Apps stay thin.** Adapters are ~50 lines each. The work isn't being copied into a shared place — it's being **lifted** into a shared place, and the apps shrink.
- **Compliance is centralized.** `PayloadGuard` runs every time. You can't accidentally bypass it from a handler.
- **Testability.** Package has no DB / no HTTP / no Firebase — fake the repos, fake the HTTP client, run unit tests in milliseconds.
- **Coexistence is straightforward.** P1.5 puts a feature flag at the call site; the old `NotificationService.instance.send...` and the new `notificationRepo.insert + fcmSender.send` live side-by-side until P1.7 deletes the old path.

## Related docs

- `docs/fcm-notification-redesign-plan.md` — architecture and design rationale
- `docs/fcm-notification-implementation-plan.md` — phase-by-phase ticket breakdown
- `docs/fcm-notification-architecture.md` — current architecture before redesign
- `docs/fcm-notification-backend-explained.md` — walkthrough of the current backend code
