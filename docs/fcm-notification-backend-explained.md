# FCM Notification Backend — How It Works & What's Next

> **⚠️ HISTORICAL — describes the retired relational / two-service architecture (pre-EVS).**
> The three code paths below (`diary_server` token registration, `patient_fcm_tokens` table,
> `diary_functions`, shared relational DB) describe a design retired in the EVS cutover
> (CUR-1170 / CUR-1437). **Current architecture:** the device syncs directly to `portal_server_evs`
> (no separate diary-server node); FCM-token and notification data are events in the
> `event_sourcing` store, not relational tables. Treat the paths below as historical reference only.
> Authoritative current sources: `spec/ops-push-notifications.md`, `spec/dev-participant-ingest.md`.
> A full EVS-FCM rewrite tracks with CUR-1416 / CUR-1418 / CUR-1399.

## How the backend works today (pre-EVS — historical)

There are three independent code paths. The "magic" of FCM is mostly outside our backend — Google delivers the message; we just hand it to them.

### Path 1 — Token registration (mobile → diary_server → DB)

```
Mobile (clinical_diary)                 Diary Server                    DB
─────────────────────────               ─────────────                   ──
FirebaseMessaging.instance.getToken()
  ↓ (token is bound to cure-hht-admin)
onTokenRefresh fires now and on rotation
  ↓
auth_service POSTs the token            registerFcmTokenHandler         patient_fcm_tokens
POST /api/v1/user/fcm-token  ─────────► verifyAuthHeader(JWT)           ───────────────────
{ fcm_token, platform, app_version }    look up patient_id              UPDATE existing rows
                                         via patient_linking_codes      → is_active = false
                                         ↓                              (same patient+platform)
                                         UPSERT pattern:                INSERT new row
                                           1) deactivate old            → is_active = true
                                           2) insert new
```

Code: `clinical_diary/lib/services/notification_service.dart:111` (`getToken`/`onTokenRefresh`) → diary's `auth_service` calls the route → `diary_functions/lib/src/fcm_token.dart:25` (`registerFcmTokenHandler`).

Result in the DB: at most one `is_active=true` row per `(patient_id, platform)`.

### Path 2 — Sending (admin action → portal_server → FCM → device)

This runs **inline inside the admin's HTTP request**. The admin is blocked until FCM responds.

```
Admin clicks "Send Questionnaire"
  ↓ POST /api/v1/portal/patients/{id}/questionnaires/{type}/send
  ↓
sendQuestionnaireHandler  (questionnaire.dart:~570)
  │
  ├─ 1. INSERT questionnaire instance into DB
  │
  ├─ 2. SELECT fcm_token FROM patient_fcm_tokens
  │      WHERE patient_id=$1 AND is_active=true
  │      ORDER BY updated_at DESC LIMIT 1
  │      └── if no row: log "patient will discover via sync", continue
  │
  ├─ 3. NotificationService.instance.sendQuestionnaireNotification(...)
  │      │
  │      ├─ _refreshIfNeeded()       (rotates ADC token if older than 55 min)
  │      ├─ POST https://fcm.googleapis.com/v1/projects/cure-hht-admin/messages:send
  │      │     body: { message: { token, data: {...}, notification, android, apns } }
  │      │     auth: ADC bearer token (cloud-platform scope)
  │      │
  │      ├─ on 200: returns NotificationResult.success(messageId)
  │      ├─ on 4xx/5xx: returns NotificationResult.failure(errorString)
  │      │
  │      └─ writes admin_action_log row, action_type='FCM_NOTIFICATION'
  │           status = 'sent' | 'failed' | 'console'
  │
  ├─ 4. INSERT admin_action_log row, action_type='QUESTIONNAIRE_SENT'
  │       (includes fcm_message_id if FCM returned one)
  │
  └─ 5. return 200 to admin
```

Important quirks of this path:

- **Failure is swallowed.** If `LIMIT 1` finds nothing, or FCM returns 4xx, the handler logs a warning but still returns 200. The admin sees success; the participant never gets pinged.
- **Tokens don't get cleaned up.** A `404 UNREGISTERED` from FCM means the device is gone, but `is_active` stays `true`. Every future send to that participant will log the same failure forever.
- **The `LIMIT 1` is the silent killer for dual-device participants.** iPhone + iPad, or phone + reinstall = some of those devices never get notified.

### Path 3 — Cross-project auth (the part most people don't see)

The portal_server is in `{sponsor}-{env}` (e.g. `callisto4-dev`). FCM lives in `cure-hht-admin`. The way it bridges is:

1. Cloud Run gives the container an **ADC token** automatically (Workload Identity Federation, no key files).
2. That token is signed for the Cloud Run SA: `{sponsor}-{env}-run-sa@{sponsor}-{env}.iam.gserviceaccount.com`.
3. That SA has been granted `roles/cloudmessaging.messageSender` (or similar `fcmSender`) **on the cure-hht-admin project**, via a manual IAM grant.
4. When portal_server calls `fcm.googleapis.com/v1/projects/cure-hht-admin/messages:send` with that bearer token, Google's IAM checker says "yes, this SA can send via cure-hht-admin" and the call goes through.

The token the device registered also points at `cure-hht-admin` (because the mobile app's `firebase_options.dart` is initialized with that project's config). So everything aligns: same project on both sides of the FCM call.

### Path 4 — Device receive

```
FCM (cure-hht-admin) ─── push ───► Device's OS-level FCM service
                                          ↓
                                    if app foreground → onMessage stream
                                    if app background → system tray (because we send a `notification` block)
                                                       + onMessageOpenedApp on tap
                                    if app terminated → firebaseMessagingBackgroundHandler runs
                                                       (top-level function, vm:entry-point)
```

Code: `clinical_diary/lib/services/notification_service.dart:17` (background handler) and `:77` (foreground handler). On any data message, the app calls `onDataMessage(data)` which routes by `data.type` (`questionnaire_sent`, `questionnaire_deleted`, etc.) and creates/removes tasks locally.

## So where can it fail right now?

In order of likelihood (based on the code, before we look at logs):

1. No `is_active=true` row in `patient_fcm_tokens` for the patient. → "No FCM token found, patient will discover via sync" in the logs. The mobile app never registered, or registered before linking and the linking step never tied it to a patient.
2. SA missing `fcmSender` IAM on `cure-hht-admin` for that sponsor's project. → `403 PERMISSION_DENIED`. **Not in Terraform** today — manual grant per sponsor.
3. Mobile build initialized against a different Firebase project than `cure-hht-admin`. → `404 NOT_FOUND` / `Requested entity was not found` (token belongs to a different project).
4. Stale token. → `404 UNREGISTERED`.
5. Permission denied on the device. → 200 from FCM, nothing on screen.

That's literally the order to walk through `admin_action_log`, then Cloud Run logs, then the device.

## What we're going to do

Three layers, in increasing scope. Pick the layer that matches what you actually need.

### Layer 1 — Make the current backend trustworthy (1 PR, no new infra)

Stays inline, stays simple, fixes the silent-failure traps:

1. **Send to all active devices, not `LIMIT 1`.** Loop over every `is_active=true` row for the participant. Per-token success/failure, all logged.
2. **Mark UNREGISTERED tokens inactive.** When FCM responds 404 with `UNREGISTERED`, set `is_active=false` for that exact token. Self-healing — bad tokens stop being retried forever.
3. **Extract one helper.** `getActiveTokensForPatient(patientId)` replaces the four copy-pasted SQL blocks (`questionnaire.dart` ×3, `patient_linking.dart` ×1).
4. **Add `fcmSender` to Terraform.** `google_project_iam_member` on `cure-hht-admin`, granted to each sponsor's run-sa. Removes the manual onboarding step that's quietly broken at least one sponsor before.

That's the whole change. After this, the backend tells you *exactly* why notifications didn't arrive, and stops sending to dead tokens.

### Layer 2 — Make sending non-blocking and retried (Cloud Tasks)

The admin handler enqueues a Cloud Task and returns immediately. A separate `/internal/send-notification` endpoint does the actual FCM call, with Cloud Tasks handling retries and dead-letter:

```
Admin handler (questionnaire.dart)              Cloud Tasks queue          Internal endpoint
──────────────────────────────────              ─────────────────          ─────────────────
1. INSERT questionnaire row                                                 POST /internal/send-notification
2. enqueue task ────────────────►  task: { patientId, instanceId,  ───►   {body from queue}
   { patientId, type, instanceId }   type, attempt }                         │
3. INSERT admin_action_log         (auto-retry w/ backoff,                   ├─ getActiveTokensForPatient
4. return 200 (no FCM call)         dead-letter on max attempts)             ├─ for each: send via FCM
                                                                             │   ├─ 200 → audit 'sent'
                                                                             │   ├─ 404 UNREG → deactivate
                                                                             │   └─ 5xx → 503 back to queue
                                                                             └─ return 200/503
```

What this buys: admin requests get fast (no 500ms–2s FCM latency), transient FCM blips don't lose notifications, and dead-letter gives you a real "stuck notifications" view. Costs nothing — Cloud Tasks free tier is 1M/month.

The internal endpoint must be locked down to only accept calls from the queue's OIDC token (so it's not a public send-anything endpoint).

### Layer 3 — Outbox table (only if Layer 2 isn't enough)

Write a `notification_events` row in the **same DB transaction** as the questionnaire insert. A separate worker drains the outbox into Cloud Tasks. This guarantees "if the questionnaire was committed, the notification will eventually be attempted, even if the server crashed between insert and enqueue."

This is real engineering — new table, new worker, new failure modes. Don't do it unless we hit a case where Layer 2's failure mode (server crashes between INSERT and enqueue) actually bites, or unless other services need to trigger notifications too.

## Recommendation

**Do Layer 1 now, Layer 2 next sprint, Layer 3 only if we need it.** Layer 1 is straightforward and gives you observable, reliable behavior. Layer 2 is the right "production push" architecture and is cheap. Layer 3 is over-engineering for the current volume.
