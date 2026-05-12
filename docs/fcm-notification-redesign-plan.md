# FCM Notification Redesign — Compliance-Safe Envelope Pattern

> **📍 Update (2026-05-07):** The package portion of this plan has been revised. Instead of an FCM-only `apps/common-dart/fcm_notifications/` package, we are building a generic `apps/common-dart/comms/` package that hosts an `FcmChannel` today and will grow `EmailChannel` / `SlackChannel` later.
>
> The architecture in this document (envelope pattern, polling fallback, per-handler feature flags, schema) is **still current**. Only the package shape and naming have changed. Wherever this document refers to `fcm_notifications`, mentally substitute the FCM portion of `comms`.
>
> **Authoritative current plan:** [docs/fcm-next-phase-plan.md](./fcm-next-phase-plan.md). Read that first for the live phase breakdown (S3 → Phase 1A → Phase 1B).

## Context

The current FCM flow works (once IAM is granted — see Phase 0 below) but two gaps motivate a redesign:

1. **Compliance.** Even though no PHI is in the FCM payload today, business-object IDs (`questionnaire_instance_id`) flow through Google's FCM service. Under HIPAA Safe Harbor / GDPR, identifiers that link to a patient record can themselves be considered PHI.
2. **Reliability.** FCM sends are fire-and-forget today. If FCM 5xx's, if the token is stale, or if the server crashes between DB write and FCM call, the notification is lost with no retry.

Two plans were on the table when this redesign started:

- **Envelope plan** (proposed): persist a notification row server-side, send only an opaque UID via FCM, mobile fetches content via authenticated API.
- **Sync plan** (proposed): FCM as a sync trigger feeding a `SyncController`; polling fallback when FCM unavailable.

This document combines both into one architecture, calls out their respective scopes, and lays out the phased implementation.

## Verdict on the two plans

**The envelope plan is correct for compliance-grade notifications** — same pattern Slack, banking, and most healthcare apps use.

**The sync plan solves a different problem** (keeping local data fresh) and shouldn't be on the same code path as user-facing notifications. Different SLAs, different failure semantics:

| Concern | Sync | Notification |
|---|---|---|
| Goal | Keep local data fresh | Tell user something happened |
| Trigger | Time-based or push-driven | Specific event |
| User-visible | No (background) | Yes (tray) |
| Acceptable lag | 15 min | Seconds |
| Failure cost | Stale data — recovers next sync | Missed notification — user never told |

Implement them separately. This document is about notifications.

## What the existing code already does (don't reinvent)

- FCM payload is already PHI-free:
  ```json
  { "type": "questionnaire_sent",
    "questionnaire_type": "nose_hht",
    "questionnaire_instance_id": "<uuid>",
    "action": "new_task" }
  ```
- The `questionnaire_instance_id` is effectively an envelope UID, but it's a *business* ID — not opaque.
- A `notification` block carries the literal string `"New Questionnaire Available"`. Not PHI, but also not localized server-side.
- Mobile already fetches questionnaire data via API after receiving — the "pull" half of envelope-pattern is already in place for one notification kind.

So the existing system is partway to the envelope pattern. What's missing:

- A dedicated, generalized notification table (today's logic is per-kind).
- An opaque UID separate from business IDs.
- A mobile API specifically for rendering notifications.
- Retry / delivery state tracking.
- A polling safety net for missed pushes.

## Issues called out in the original envelope plan

1. **The UID must be opaque.** Don't reuse `questionnaire_instance_id`. A separate `notifications.notification_id` UUID prevents identifier leakage and decouples from business schema.
2. **Don't split "envelope store" and "retry queue" into two tables.** One `notifications` table with a `status` column is cleaner. Avoids two-table consistency concerns.
3. **Going data-only loses the OS tray notification.** Today, the FCM `notification` block makes Android show a tray entry automatically. With pure data-only, the mobile app must construct local notifications using `flutter_local_notifications`. Real client work, especially on iOS background.
4. **Background fetch on iOS is throttled.** Apple gives the background isolate ~30s and rate-limits data-only wakeups (`apns-priority: 5`, `content-available: 1`). If envelope fetch fails, user gets nothing until they open the app. Mitigation below.
5. **Decide what the user sees if envelope fetch fails.** Recommendation: include a **generic localized title** (`"You have a new message"`, fully sponsor-neutral) in the FCM `notification` block. That string isn't PHI but gives the OS something to show even if the API call fails.
6. **Acknowledgement / read tracking.** When the mobile fetches the envelope, mark `delivered`. Useful for support and FDA audit.
7. **Cloud Tasks > custom retry loop.** Don't write a polling worker. Cloud Tasks gives exponential backoff and dead-letter for free; the `notifications` row stays as source of truth.

## Issues called out in the sync plan

1. **Conflates two concerns.** Sync ≠ notification.
2. **15-min polling is too slow for notifications.** Fine for sync. Notifications need to be near-real-time — that's what FCM is for.
3. **No outbox.** Same gap as the envelope plan; closed by Cloud Tasks.
4. **`SyncController` is solid for sync** — keep it (separately).

## Synthesis: the architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          SERVER                                  │
│                                                                  │
│  Business / status-change event                                  │
│    │                                                             │
│    ├─ INSERT business row (questionnaire_instances or patients)  │
│    │                                                             │
│    ├─ INSERT notification row (notifications table)              │
│    │    notification_id = <opaque uuid>                          │
│    │    patient_id, notification_type (enum), payload (action+), │
│    │    status='pending'                                          │
│    │                                                             │
│    └─ Send FCM inline (synchronous, fire-and-forget on failure)  │
│         │  load active FCM tokens                                │
│         │  FCM send: {notification_id} + generic title           │
│         │                                                        │
│         ├─ on 200: status='sent', record message_id              │
│         ├─ on UNREGISTERED: deactivate token, status='failed'    │
│         └─ on any other failure: status='failed', record error   │
│            → no retry. Mobile polling will catch it on resume.   │
│                                                                  │
│  Mobile API:                                                     │
│    GET /api/v1/notifications/{notification_id}  (auth: JWT)      │
│      → returns envelope (title, body, type, payload),            │
│        marks 'delivered'                                          │
│                                                                  │
│    GET /api/v1/notifications?since=<ts>  (auth: JWT)             │
│      → returns all envelopes since ts (regardless of FCM status) │
│      → primary catch-up mechanism for missed/failed pushes       │
└─────────────────────────────────────────────────────────────────┘
                       │ FCM
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                          CLIENT                                  │
│                                                                  │
│  FCM receive (foreground / background / terminated)              │
│    │  payload: { notification_id }                               │
│    │           + notification: { title: "<generic localized>" }  │
│    │                                                             │
│    ├─ If foreground:                                             │
│    │    - GET /api/v1/notifications/{id}                         │
│    │    - show in-app surface or local notification              │
│    │                                                             │
│    ├─ If background:                                             │
│    │    - GET /api/v1/notifications/{id}                         │
│    │    - construct local notification with real title/body      │
│    │    - if fetch fails: keep generic title (already shown)     │
│    │                                                             │
│    └─ If terminated:                                             │
│         - generic title shown by OS                              │
│         - on tap: app launches, fetches envelope, deeplinks      │
│                                                                  │
│  Foreground refresh (catches any missed pushes):                 │
│    on app resume → GET /api/v1/notifications?since=<lastSeen>    │
│                  → render any unfetched envelopes                │
│                                                                  │
│  Sync (separate concern, kept simple):                           │
│    on app resume → existing diff endpoints                       │
│    NOT driven by notifications                                   │
└─────────────────────────────────────────────────────────────────┘
```

Key design choices:

- **One table, `notifications`** — envelope store. No retry queue: failed sends stay `failed` and are caught on the mobile via polling.
- **FCM payload = `{notification_id}` + generic localized title.** Generic title is patient-neutral, OS-friendly fallback.
- **Synchronous send, no backend retry.** If FCM fails (transient or permanent), the row is marked `failed` and no retry happens server-side. The mobile's `?since=` polling on app resume is the **primary catch-up mechanism**, not a fallback. This keeps the backend simple.
- **Mobile fetches the envelope to render the real notification.** Fallback chain on FCM-fetch failure.
- **`since` polling endpoint** is required-path, not optional. Runs on app foreground (immediate + every N minutes while foregrounded). Returns all envelopes since `ts` regardless of FCM `status`, so envelopes that never reached the device via FCM still surface.
- **Every patient-status change → notification.** All five status-change handlers send FCM. See "Status-change matrix" below.
- **Sync is separate.** Existing diff endpoints stay as they are.

## Status-change matrix — every transition gets a notification

Design rule: **whenever a handler mutates patient status (or questionnaire status), it sends an FCM envelope.** No silent state changes.

All entries below produce a row with the noted `notification_type` enum + `payload.action`.

### Patient status transitions → `notification_type = 'patient_status_update'`

| Handler | File | From → To | `payload.action` | Status |
|---|---|---|---|---|
| `startTrialHandler` | `patient_linking.dart:1033` | trial_started=false → true | `trial_started` | ✅ already sends |
| `disconnectPatientHandler` | `patient_linking.dart:469` | `connected` → `disconnected` | `disconnected` | ❌ to add |
| `generatePatientLinkingCodeHandler` (reconnect path) | `patient_linking.dart:62` (with `reconnect_reason`) | `disconnected` → `connected` | `reconnected` | ❌ to add |
| `markPatientNotParticipatingHandler` | `patient_linking.dart:682` | `disconnected` → `not_participating` | `not_participating` | ❌ to add |
| `reactivatePatientHandler` | `patient_linking.dart:867` | `not_participating` → `connected` | `reactivated` | ❌ to add |

### Questionnaire status transitions → `notification_type = 'questionnaire_update'`

| Handler | File | From → To | `payload.action` | Status |
|---|---|---|---|---|
| `sendQuestionnaireHandler` | `questionnaire.dart:~570` | `not_sent` → `sent` | `sent` | ✅ already sends |
| `deleteQuestionnaireHandler` | `questionnaire.dart:~830` | * → `deleted` | `deleted` | ✅ already sends |
| `unlockQuestionnaireHandler` | `questionnaire.dart:980` | `ready_to_review` → `sent` | `unlocked` | ✅ already sends |
| `finalizeQuestionnaireHandler` | `questionnaire.dart:1155` | `ready_to_review` → `finalized` | `finalized` | ❌ to add (Issue #27) |

### Token-deactivation ordering for status changes

The status changes that **invalidate the patient's mobile session** are `disconnect` and `not-participating`. Both must:

1. Send the notification first (synchronous, await result).
2. Update `patient_fcm_tokens SET is_active=false WHERE patient_id=$1` afterwards.

`reconnect` and `reactivate` go the other way — they don't touch tokens (the patient may register a fresh token when they next open the app; old tokens were already deactivated on the previous disconnect).

### What if FCM fails on a status-change notification?

Same rule as everything else: log `failed`, move on. The mobile's `since` poll catches it on next app open. The status change in the DB has already happened — the user will discover their state via the existing sync mechanism, just delayed slightly. No retry needed.

## Implementation plan

### Phase 0 — Unblock current state (5 min, today)

- Grant `roles/cloudmessaging.admin` on `cure-hht-admin` to the Compute default SA `421945483876-compute@developer.gserviceaccount.com` (callisto4-qa). Same grant required for every other sponsor-env that uses FCM.
- Verify `FCM sent` log appears for a triggered send.
- Independent of the redesign — even if we ship Phase 1, IAM is required.

### Phase 1 — Notifications table + envelope API (1–2 days)

Schema (new migration, must pass Squawk):

```sql
-- Top-level routing category. Three values, may grow later via ALTER TYPE.
CREATE TYPE notification_type AS ENUM (
  'questionnaire_update',   -- sent / deleted / unlocked / finalized
  'patient_status_update',  -- trial_started / disconnected / reconnected / not_participating / reactivated
  'reminder'                -- future: scheduled reminders (no triggers yet)
);

CREATE TABLE notifications (
  notification_id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id        text NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
  notification_type notification_type NOT NULL,            -- top-level category (enum) — drives behavior
  title             text NOT NULL,                          -- literal display text (sponsor-neutral, no PHI)
  body              text,                                   -- literal display text (optional, no PHI)
  payload           jsonb NOT NULL DEFAULT '{}'::jsonb,    -- 'action' (sub-routing) + business IDs
  status            text NOT NULL DEFAULT 'pending',        -- pending | sent | failed | delivered
  message_id        text,                                   -- FCM-issued ID on success
  last_error        text,                                   -- FCM error string on failure
  created_at        timestamptz NOT NULL DEFAULT now(),
  sent_at           timestamptz,                            -- set when FCM returns 200
  delivered_at      timestamptz                             -- set when mobile fetches via API
);

CREATE INDEX notifications_patient_created_idx
  ON notifications (patient_id, created_at DESC);
```

### Two roles, two columns

| Concern | Field(s) | Used by |
|---|---|---|
| **Display** — what the patient sees | `title`, `body` | Mobile renders verbatim. Compliance-safe: rows must contain no PHI (no patient name, no DOB). |
| **Behavior** — what code path runs | `notification_type`, `payload.action` | Mobile dispatches: type → category handler, action → specific action handler. |

The mobile uses `title`/`body` for the visible notification but uses `notification_type` + `payload.action` for everything else (creating tasks, clearing banners, deeplink routing, audit categorization).

### Compliance check on `title` / `body`

Stored copy must be **generic and sponsor-neutral**, e.g.:
- ✅ "New Questionnaire Available" / "You have a new questionnaire to complete."
- ❌ "John Smith — your nose_hht for Visit 3 is ready" (contains identifier + business detail)

The same `PayloadGuard` we add for `payload` should run a regex check on `title`/`body` rejecting strings that look like patient IDs, names, etc. Belt-and-braces: server-side validation prevents copy mistakes from leaking PHI.

### Localization

Today there's no `patients.language` column. For now, copy is English-only — generic enough that a single language is acceptable for MVP. When localization becomes needed:
- Option A: add `patients.language` column; sender picks copy per patient.
- Option B: store `title_key` / `body_key` alongside `title` / `body`; mobile uses key if it has a translation, falls back to literal `title`. Lets the server be progressive.

Don't pre-build either. Ship English-only until product asks.

### What's still NOT in the schema (and why)

- **No `deeplink`** — mobile owns its own routing. From `(notification_type, payload.action)` plus IDs in `payload`, the mobile constructs the route locally (e.g. `questionnaire_update`/`sent` + `payload.questionnaire_instance_id` → `/questionnaire/<id>`). Adding `deeplink` would couple the server to mobile route format.

### What goes in `payload`

By convention, `payload.action` is required for every notification (used for inner dispatch). Other keys depend on the type:

```jsonc
// questionnaire_update / sent
{
  "action": "sent",
  "questionnaire_instance_id": "<uuid>",
  "questionnaire_type": "nose_hht"
}

// questionnaire_update / finalized (with end event)
{
  "action": "finalized",
  "questionnaire_instance_id": "<uuid>",
  "end_event": "study_completed"
}

// patient_status_update / disconnected
{
  "action": "disconnected"
}

// patient_status_update / reconnected
{
  "action": "reconnected"
}
```

Keep `payload` keys flat and stable — the mobile reads them with hard-coded keys. New keys are additive; **don't rename or remove them once shipped**.

### Why an enum + payload action (not just nine specific values)

The mobile needs to know **which specific action** happened to behave correctly: questionnaire_sent → create task, questionnaire_deleted → remove task, etc. So we need both:

- **`notification_type`** (enum, three values) — top-level routing category. Useful for inbox grouping ("Show all questionnaire updates"), retention policies, audit filtering, and coarse-grained UI affordances. Stable, rarely needs new values.
- **`payload.action`** (string in jsonb) — the specific sub-action. Drives behavior on the mobile. New sub-actions don't need a DB migration.

Mapping table:

| `notification_type` | `payload.action` | Effect on mobile |
|---|---|---|
| `questionnaire_update` | `sent` | Create task |
| `questionnaire_update` | `deleted` | Remove task |
| `questionnaire_update` | `unlocked` | Reopen task / informational |
| `questionnaire_update` | `finalized` | Informational; if `payload.end_event` present → trial-ended state |
| `patient_status_update` | `trial_started` | Activate outbound destinations |
| `patient_status_update` | `disconnected` | Trigger `disconnectedNotifier`, clear pending tasks |
| `patient_status_update` | `reconnected` | Clear disconnected banner, refresh enrollment |
| `patient_status_update` | `not_participating` | Trigger `disconnectedNotifier`, clear pending tasks |
| `patient_status_update` | `reactivated` | Clear not-participating state, refresh enrollment |
| `reminder` | (future) | (future) |

### Mobile dispatch model

```dart
// After fetching envelope from /api/v1/notifications/{id}:
switch (envelope.notificationType) {
  case NotificationType.questionnaireUpdate:
    _handleQuestionnaireUpdate(envelope.payload['action'], envelope.payload);
  case NotificationType.patientStatusUpdate:
    _handlePatientStatusUpdate(envelope.payload['action'], envelope.payload);
  case NotificationType.reminder:
    _handleReminder(envelope);
}
```

Each inner handler switches on `payload['action']` for its sub-cases. New sub-actions only require new `case` arms, no DB or enum changes.

### Extending the enum later

Postgres `ALTER TYPE notification_type ADD VALUE 'system_message'` is a one-line migration. Use it when product asks for a new top-level category (e.g. "system maintenance," "account update"). Adding values is safe; **renaming or removing them is hard**, so name conservatively at first.

State machine is intentionally simple:

```
pending ──► sent ──► delivered
   │
   └─────► failed   (no retry — mobile polling catches up)
```

No `sending`, no `dead`, no `attempts` counter — those were artifacts of the dropped Cloud Tasks retry plan. A failed send stays `failed`; the envelope is still served via the `?since=` API, so the mobile picks it up on resume.

Server work (portal_functions / portal_server):

- New helper to write envelope rows in same transaction as business writes.
- Refactor every FCM call site (now nine: 4 questionnaire + 5 patient-status — see status-change matrix above).
- FCM payload becomes `{ notification_id }` data only, plus `notification: { title: "<generic>" }`.
- `NotificationService` updates `notifications.status` on result. No retry. On UNREGISTERED, deactivate the token and mark the envelope `failed` (mobile catches up via polling once a fresh token is registered).

Mobile API on diary_server:

- `GET /api/v1/notifications/{id}` — returns the envelope (title, body, type, payload). JWT-authenticated, must verify `notifications.patient_id == JWT's linked patient`. Sets `delivered_at = now()` if currently NULL (see "Delivery semantics" below). Mobile displays `title`/`body` directly; uses `type` + `payload.action` for behavior; derives deeplink locally.
- `GET /api/v1/notifications?since=<ts>` — returns envelopes for the patient where `created_at > since`. **Same delivery rule applies**: every envelope returned has its `delivered_at` set on the way out, idempotent on already-delivered rows.

### Delivery semantics

`delivered_at` means **"the envelope was successfully transmitted to the patient's device"**, evidenced by a JWT-authenticated fetch returning that envelope. It does NOT mean "the patient saw it" (that would be a `read_at` field, future work).

Both fetch endpoints share the same `UPDATE` semantics — run as part of the response transaction:

```sql
UPDATE notifications
   SET delivered_at = now()
 WHERE notification_id = ANY($1)
   AND patient_id = $2          -- defense in depth: confirm authz at write time
   AND delivered_at IS NULL;    -- idempotent: don't overwrite first delivery
```

The `delivered_at IS NULL` guard makes retries safe: if the mobile drops the response and re-polls, the same envelopes come back, and `delivered_at` stays pinned to the first successful fetch. No flapping, no race.

**Why update for the bulk endpoint at all?** Audit completeness. Without it, FDA-relevant questions like "when did patient X first see notification Y?" can't be answered for envelopes the mobile got via polling rather than via direct fetch (which is most of them, given polling is the primary catch-up mechanism).

**Future work**: a separate `POST /api/v1/notifications/{id}/read` endpoint when product wants per-notification read tracking. Different concern, doesn't change this design.

Mobile work (clinical_diary):

- New `NotificationEnvelopeService` that fetches envelopes by ID and renders local notifications via `flutter_local_notifications`.
- Foreground/background/terminated paths all converge on this service.
- Removes the `notification` payload reliance; replaces it with local notifications constructed from envelope data.

### Phase 2 — Mobile polling (½–1 day) — **required, not a fallback**

This is the **primary catch-up mechanism** for missed FCM pushes. Without retries on the backend, polling carries the reliability story.

Mobile-only:

- On app resume: `GET /api/v1/notifications?since=<lastSeen>` → render any envelopes the device hasn't seen.
- While foregrounded: poll every N minutes (default 60s, sponsor-configurable).
- After receiving a push via FCM: still update `lastSeen` so the polling cursor doesn't reprocess.
- **No background timer**, no `WorkManager`, no `background_fetch`. Apple/Google both throttle background work; we don't fight that.
- Persist `lastSeen` per-patient in `SharedPreferences`. Reset on logout.

Failure modes this catches:
- FCM permission denied on the device.
- Network down when the push was sent.
- App reinstalled (new FCM token, old envelopes server-stamped before re-registration).
- FCM token rotated mid-flight.
- FCM service outage during a status change.
- Server-side `failed` envelope (FCM returned 5xx, no backend retry, mobile polling is the recovery path).

### Phase 3 — IAM in Terraform + UNREGISTERED cleanup (½ day)

- Add `google_project_iam_member` granting `roles/cloudmessaging.admin` on `cure-hht-admin` to each sponsor's Cloud Run SA. Codifies the manual grant from Phase 0.
- On FCM 404 `UNREGISTERED`, set `is_active=false` on the offending row in `patient_fcm_tokens`. Self-healing — bad tokens stop being retried forever.

**Cloud Tasks (dropped from this plan)** — original Phase 2/Phase 5 envisioned backend retries via Cloud Tasks. Removed because the mobile polling above already catches every transient and permanent FCM failure. Backend retries would be redundant with polling. If a retry policy is ever needed (e.g. bursty status changes saturating FCM quota), reintroduce it then; not now.

## Decisions to make upfront

1. **Localization strategy.** Server stores literal English copy in `title` / `body` for MVP. When localization is needed, add `patients.language` column and have the sender pick copy per patient at write time. Don't pre-build.
2. **Multi-device.** Phase 1 is the right time to remove the `LIMIT 1` and send to all active tokens for a patient.
3. **Notification inbox UI?** If yes (badge counts, "View all notifications" screen), the `notifications` table powers it. Worth designing the schema with that in mind even if the UI ships later.
4. **Audit retention.** Notification rows are audit data under 21 CFR Part 11. Likely retention: indefinite (same as `admin_action_log`).
5. **Generic FCM title text.** Sponsor-neutral, language-localized. Suggest "You have a new message" or similar.

## Risks / things that could bite

- **iOS data-only throttling.** Apple may suppress data-only pushes if too frequent. Generic-title fallback handles the worst case.
- **Local notification permission.** Showing local notifications still requires the user grant. If they deny, the polling-on-foreground path is the only way they'll see anything. Design for it.
- **Cross-project IAM drift.** Phase 4 closes this for new sponsors. Existing sponsors still need a one-time manual grant or a Terraform import.
- **JWT-to-patient mapping for envelope API.** The diary_server already does this for `/fcm-token` registration — reuse the same lookup.

---

# Gap Analysis: Missing Scenarios from Code Review

Found by walking the existing FCM call sites, mobile init, token lifecycle, and DB schema. Grouped by severity. File/line references included for verification. Several of these are bugs in the **current** behavior, regardless of redesign.

## 🔴 Critical — correctness or compliance bugs

### 1. Cross-patient notification leak when devices are shared

**`patient_fcm_tokens` has no uniqueness on `fcm_token` itself** — the partial unique index is on `(patient_id, platform) WHERE is_active = true` (`migrations/004:117`). Sequence:

```
Patient A logs in on device X → row: (A, android, token-T, active=true)
Patient A logs out, Patient B logs in on same device X
  → FCM token T is unchanged (it's per-device, not per-user)
  → diary_server inserts: (B, android, token-T, active=true)
  → both rows now active, both pointing at the same physical device
```

When portal sends to **Patient A**, FCM delivers to **device X**, currently logged in as Patient B. Patient B sees a notification meant for Patient A.

**Fix**: when registering a token, deactivate any other patient's row for the same `fcm_token`. Token T can only ever be active for one patient at a time.

### 2. Disconnect / not-participating: no notification sent + token not deactivated

Two related gaps in `disconnectPatientHandler` (`patient_linking.dart:469`) and `markNotParticipatingHandler`:

**Gap 2a — patient is never notified.** Both handlers update DB state silently. The patient learns of the change only on the next time they open the app and `syncTasks` runs. They keep getting reminder notifications for questionnaires they're no longer expected to fill.

**Gap 2b — FCM tokens stay `is_active=true`** after disconnect / not-participating. The disconnected patient keeps receiving notifications until FCM eventually returns UNREGISTERED (only happens if the app is uninstalled).

**Required behavior:**

1. **Send a notification to the patient first** — new kinds:
   - `patient_disconnected` — title key `notif.patient_disconnected.title`, body key `notif.patient_disconnected.body`. Suggested copy (sponsor owns localization): "Your trial enrollment has changed — please contact your site for details."
   - `patient_not_participating` — title key `notif.patient_not_participating.title`, body key `notif.patient_not_participating.body`. Suggested copy: "Your participation in the trial has ended."
   - (Future symmetric: `patient_reconnected` and `patient_reactivated` if product wants the positive-event mirror. Out of scope for this round.)
2. **Then deactivate tokens** — `UPDATE patient_fcm_tokens SET is_active=false WHERE patient_id = $1`.

**Ordering matters.** Deactivate AFTER the notification has been handed to FCM, not before. Otherwise the disconnect notification itself would fail to deliver because the lookup would skip inactive tokens.

In Phase 1 (synchronous send): trivially correct — `await sendNotification(...)` then `UPDATE patient_fcm_tokens ... SET is_active=false`.

In Phase 2 (Cloud Tasks): tag these notification kinds as **synchronous-delivery only** (skip the Cloud Tasks queue for them) so the deactivation can't race the task fire. Alternative: have the worker accept inactive tokens for these specific kinds. Sync-only is simpler — disconnects are rare, latency is irrelevant.

**Mobile-side behavior on receipt** — the app should:
- Show the local notification from the envelope.
- Trigger `EnrollmentService.disconnectedNotifier` immediately so the home screen banner appears without waiting for next sync (`home_screen.dart:147` already listens).
- Clear pending questionnaire tasks (they're no longer applicable).
- Do NOT auto-logout the user — let them navigate naturally.

### 3. Mobile silently drops `questionnaire_unlocked` and `trial_started`

`TaskService.handleFcmMessage` (`task_service.dart:139`) only switches on `questionnaire_sent` and `questionnaire_deleted`. Portal sends:
- `questionnaire_unlocked` (`questionnaire.dart:1081`)
- `trial_started`-typed via `sendQuestionnaireNotification` (`patient_linking.dart:1161` with `questionnaireType: 'trial_started'`)

Mobile logs `Unknown message type` and does nothing. The OS tray entry shows because of the `notification` block, but no in-app state changes.

### 4. `trial-$patientId` is a patient-ID leak through FCM

`patient_linking.dart:1164`:
```dart
questionnaireInstanceId: 'trial-$patientId',
```
The `patient_id` (RAVE SubjectKey, e.g. `999-001C-001`) is embedded in the FCM data field. Identifiable info crossing Google's infrastructure. The redesign fixes this by replacing the payload with `{notification_id}`, but it's the most concrete compliance break in the current code.

### 5. Background handler doesn't create tasks → dismissed notifications vanish

`firebaseMessagingBackgroundHandler` (`notification_service.dart:17`) only does `debugPrint`. When the app is backgrounded/terminated and a `questionnaire_sent` arrives:
- OS shows tray notification (because of `notification` block).
- Local task is **NOT** created.
- If user **dismisses** the tray notification without tapping, no record exists locally.
- Task only appears when user opens the app and `syncTasks` runs — could be hours.

### 6. iOS APNS payload combo is non-standard

`notification_service.dart:323`:
```dart
message['apns'] = {
  'headers': {'apns-priority': '10'},
  'payload': {
    'aps': {'content-available': 1},
  },
};
```
Apple docs: **priority 10 = user-visible alert** (requires `alert`/`badge`/`sound`); **`content-available: 1` = silent background push** (requires priority 5). Combining them violates Apple's contract — APNs may downgrade or throttle. Production reliability concern.

### 27. Finalize doesn't notify the patient — no closure on submitted questionnaires

`finalizeQuestionnaireHandler` (`questionnaire.dart:1155`) updates status to `finalized`, writes the `QUESTIONNAIRE_FINALIZED` audit row, and returns. **No FCM send.** Effect on the patient lifecycle:

```
sent ────► in_progress ────► ready_to_review ────► finalized
 ✅ FCM      (silent)              (silent)         ❌ no FCM
```

After the patient submits, they have no acknowledgement that their submission was accepted. This is particularly bad when finalize includes an `end_event` (e.g. `study_completed`) — that's the **end of the patient's trial participation**, the most significant lifecycle moment, and it goes entirely silent.

**Required behavior:**

1. **New notification kind**: `questionnaire_finalized`. One kind covers both regular finalize and end-event finalize; the payload distinguishes:
   ```jsonc
   {
     "questionnaire_instance_id": "...",   // (Phase 1: not in payload — looked up from envelope)
     "questionnaire_type": "nose_hht",
     "end_event": "study_completed"        // null for regular finalize
   }
   ```
2. **Title / body keys** (sponsor owns localization):
   - Regular finalize: `notif.questionnaire_finalized.title` / `.body`. Suggested copy: "Your questionnaire was reviewed."
   - End-event finalize (when `payload.end_event != null`): different keys, e.g. `notif.trial_completed.title` / `.body`. Suggested copy: "You've completed the trial. Thank you for your participation."
3. **Mobile-side**: handler for `questionnaire_finalized` in `TaskService.handleFcmMessage`. The local task was already removed when the patient submitted, so this notification is informational — no task-state mutation needed. If `end_event` is present, this is also a trial-end signal; the app should reflect "trial ended" status (similar to disconnect path).
4. **Audit**: capture `fcm_message_id` in the `QUESTIONNAIRE_FINALIZED` audit row, same as `QUESTIONNAIRE_SENT` already does (Issue #12 was already tracking this gap; finalize is one of the affected handlers).

**Edge case to think about**: if the questionnaire is finalized hours or days after the patient submitted, a delayed notification could be confusing. Mitigation: include the questionnaire type / cycle in the body copy so context is clear. This is a copy decision, not architecture.

### 26. `FCM_NOTIFICATION` audit type rejected by check constraint — every FCM send is missing its audit row

`notification_service.dart:417` writes an `admin_action_log` row with `action_type = 'FCM_NOTIFICATION'` after every FCM send. But the constraint `admin_action_log_action_type_check_v2` (defined in `migrations/007:48-59`) does not include `'FCM_NOTIFICATION'` in its allowed list:

```sql
CHECK (action_type IN (
  'ASSIGN_USER', ..., 'START_TRIAL',
  'QUESTIONNAIRE_SENT', 'QUESTIONNAIRE_DELETED',
  'QUESTIONNAIRE_UNLOCKED', 'QUESTIONNAIRE_FINALIZED',
  'QUESTIONNAIRE_SUBMITTED'
  -- ← 'FCM_NOTIFICATION' missing
))
```

Effect:
- Every FCM send → audit insert violates the check → exception is **caught and logged inside `_logNotificationAudit`** → swallowed.
- The send itself succeeds, but the corresponding audit row is silently dropped.
- Confirmed live in callisto4-qa: log entry `"FCM failed to log notification audit"` accompanies every successful `"FCM sent"` log, with error `23514: ... violates check constraint "admin_action_log_action_type_check_v2"`.
- Has been silently failing since migration 007 (CUR-1111) tightened the constraint.

**FDA / 21 CFR Part 11 implication**: there is no audit trail for FCM notification sends in any environment running migration 007. The `QUESTIONNAIRE_SENT` audit row exists and references `fcm_message_id`, so the *admin's* action is recorded, but the *FCM delivery attempt* is not.

**Two fixes — both should land**:

- **Fix A (immediate)**: new migration adding `'FCM_NOTIFICATION'` to the constraint, following the same `NOT VALID` + `VALIDATE` pattern as 007. Stops the swallowed errors and restores audit completeness in days, not weeks.
- **Fix B (Phase 1)**: drop `_logNotificationAudit` entirely. The new `notifications` table replaces it — the row's `status`, `sent_at`, `attempts`, `last_error` columns are the audit record. Cleaner long-term: `admin_action_log` is for admin-initiated actions, FCM sends are side effects.

Don't skip Fix A waiting for Phase 1 — running with FDA-relevant audit gaps in prod is not acceptable risk.

## 🟠 High — broken flows under realistic conditions

### 7. Mobile doesn't retry on 409 "No linked patient"

`main.dart:507`:
```dart
if (response.statusCode == 200) { ... }
else { debugPrint('[FCM] Token registration failed: ${response.statusCode}'); }
```
Handler returns 409 if JWT exists but linking row hasn't propagated. Mobile logs and walks away. No retry. `_onPostEnrollment` only fires on enrollment success — if linking races against FCM init, token is permanently unregistered until next manual re-init.

### 8. No "delete token" call on logout / unlink

No `DELETE /api/v1/user/fcm-token` endpoint exists. On logout / unlink, server keeps the row `is_active=true` and keeps sending; FCM keeps delivering to the (logged-out) app, which has no auth to fetch envelopes. Tokens only get cleaned up on next login of the **same patient** on the same device.

### 9. iOS permission denial is silent

`MobileNotificationService._requestPermission()` (`notification_service.dart:98`) calls `requestPermission()` once. If denied:
- iOS doesn't allow re-prompting from the app.
- No UI affordance to deeplink the user to system Settings.
- No telemetry — server never knows the patient won't get notifications.

### 10. `getInitialMessage()` doesn't deep-link

`notification_service.dart:87` — when the app cold-launches from a notification tap, `_handleMessageOpenedApp` is called (which is identical to foreground handling). User lands on home screen and has to find the task. No routing to the questionnaire.

### 11. No HTTP timeout on FCM call

`notification_service.dart:330` — `_httpClient!.post(url, ...)` has no `.timeout(...)`. If FCM is slow, an admin's "Send Questionnaire" request can hang up to Cloud Run's 300s timeout.

### 12. Audit log inconsistency

`questionnaire.dart:723` (send) writes `fcm_message_id` into `QUESTIONNAIRE_SENT` audit. The delete flow (`questionnaire.dart:927`) and unlock flow don't capture it — `QUESTIONNAIRE_DELETED` audit row has no link to the notification. Makes "did the deletion notification reach the patient?" investigations harder.

## 🟡 Medium — reliability and UX gaps

### 13. Multi-device per platform is broken by schema

The unique index `(patient_id, platform) WHERE is_active=true` enforces **one device per platform per patient**. A patient with phone + tablet (both Android) gets the tablet deactivated whenever they open the phone. The doc mentioned `LIMIT 1`; the schema enforces it harder.

**Phase 1 should change this schema** — add `device_id`, drop the partial unique index, key on `(patient_id, device_id)`.

### 14. EQ questionnaires send wasted FCMs

Server sends FCM for every `eq` questionnaire. Mobile's `_handleQuestionnaireSent` (`task_service.dart:166`) skips them per CUR-1050. Wasted FCM round-trips. Server should know not to send.

### 15. `app_version` captured but unused

`patient_fcm_tokens.app_version` is recorded on registration, never queried. Useful for "only send rich-format notifications to v ≥ X" — design decision to make now or punt.

### 16. Token prefix in logs is too long (20 chars)

`fcm_token.dart:119` and `notification_service.dart:344-346` log 20-char prefixes. Even 20 chars is identifying when correlated with Google's logs. Reduce to 8.

### 17. No FCM failure-rate alert

`portal_metrics.dart` exposes `fcm_notifications_total` with status labels. No alerting policy on `failed/total > 5%`. Failures go unnoticed until someone manually checks the audit table.

### 18. GDPR right-to-erasure: no `ON DELETE` clause

`patient_fcm_tokens.patient_id REFERENCES patients(patient_id)` — default `NO ACTION`. Patient deletion is blocked until tokens are manually cleared.

Should be `ON DELETE CASCADE`. Same audit needed for the new `notifications` table.

### 19. iOS getToken returns null silently if permission denied

`notification_service.dart:115` — token never registered, no error reported, server silently never gets a token for this patient. UI shows nothing. Companion to #9 in a different code path.

### 20. No deduplication beyond questionnaire_sent

`_handleQuestionnaireSent` checks `_tasks.any((t) => t.id == instanceId)` — good. Other types (when added) would double-process duplicate FCM deliveries. FCM occasionally redelivers.

## 🟢 Low — design decisions to make explicitly

### 21. Sponsor isolation at FCM level

All sponsors share `cure-hht-admin`. A bug in callisto4 send logic could spam patients in another sponsor's trial. Mitigation: add `sponsor_id` to `notifications`, server-side hard-check on every send.

### 22. Timezones for scheduled notifications

`patients` schema doesn't include `timezone`. Any future "remind at 9am local" feature requires this column. Add now to avoid later migration.

### 23. Per-type notification preferences

No table for "Patient A muted reminders, kept urgent alerts." If sponsors ask for this, design space exists for `notification_preferences (patient_id, notification_type, enabled)` — the three-value enum is the right granularity for opt-in/opt-out toggles.

### 24. APNs key on cure-hht-admin Firebase project

Operational, not code: confirm the Apple Developer APNs auth key is uploaded to `cure-hht-admin` Firebase console. iOS pushes silently fail if missing or expired.

### 25. Notification rate limit per patient

A buggy admin loop could send hundreds of notifications to one patient. Server-side throttle (e.g. max 10/hour per kind per patient) is cheap insurance.

## Updates to the implementation plan

The phases above are mostly right, but these explicit work items need to be folded in:

### Stabilize-current-FCM PR (ship before Phase 1)
- [ ] **Add `'FCM_NOTIFICATION'` to `admin_action_log_action_type_check_v2`** via new migration `010_add_fcm_notification_action_type.sql` (with rollback). FDA audit completeness — must land in prod ASAP. (Issue #26 / Fix A)
- [ ] Patient-A-then-B same-device token deactivation (Issue #1)
- [ ] **Status-change notifications — every transition from the matrix above sends FCM** (each writes a `notifications` row with the matrix-specified `notification_type` + `payload.action`):
  - [ ] `disconnectPatientHandler` → `patient_status_update` / `disconnected` → then deactivate tokens (Issue #2)
  - [ ] `markPatientNotParticipatingHandler` → `patient_status_update` / `not_participating` → then deactivate tokens (Issue #2)
  - [ ] `generatePatientLinkingCodeHandler` (reconnect path, when `reconnect_reason` is set) → `patient_status_update` / `reconnected`
  - [ ] `reactivatePatientHandler` → `patient_status_update` / `reactivated`
  - [ ] `finalizeQuestionnaireHandler` → `questionnaire_update` / `finalized` (with `end_event` in payload when applicable). Capture `fcm_message_id` in audit. (Issue #27 + #12)
- [ ] Mobile dispatch: outer switch on `notification_type` (three values), inner switch on `payload.action`. Add `case` arms for every action introduced above. (Issue #3 + #2 + #27)
- [ ] On `patient_status_update` / `disconnected` | `not_participating`: trigger `disconnectedNotifier`, clear pending questionnaire tasks (Issue #2)
- [ ] On `patient_status_update` / `reconnected` | `reactivated`: clear disconnected banner, refresh enrollment state
- [ ] On `questionnaire_update` / `finalized` with `payload.end_event` set: reflect trial-ended state (Issue #27)
- [ ] Replace `'trial-$patientId'` with opaque ID in `patient_linking.dart` (Issue #4)
- [ ] Background handler creates tasks (Issue #5)
- [ ] Split iOS APS payload: user-visible vs data-only (Issue #6)

### Phase 1 additions (compliance + safety bundled)
- [ ] **Drop `_logNotificationAudit` entirely** — `notifications` table replaces it. (Issue #26 / Fix B)
- [ ] **Schema change**: add `device_id` column to `patient_fcm_tokens`; drop `(patient_id, platform)` partial unique index; add `(patient_id, device_id)` unique index. (Issue #13)
- [ ] **Schema change**: add `ON DELETE CASCADE` to `patient_fcm_tokens.patient_id` FK. (Issue #18)
- [ ] **Schema change**: same `ON DELETE CASCADE` on the new `notifications.patient_id` FK.
- [ ] **Schema change**: add `device_id` to `notifications` if multi-device addressing is needed.
- [ ] **Token uniqueness across patients**: registration handler deactivates any other patient's row with the same `fcm_token`. (Issue #1)
- [ ] **All status-change handlers send envelopes** (per matrix above): five patient-status transitions + finalize. Send synchronously in same handler as the DB write — no retry on failure, polling catches it. (Issues #2, #27)
- [ ] **Disconnect / not-participating**: send envelope first, **then** deactivate tokens (synchronous order). (Issue #2)
- [ ] **Mobile message routing**: handlers for all status-change kinds. On envelope-only design, the mobile fetches the envelope by id and routes by `kind`. (Issues #2, #3, #27)
- [ ] **Background handler**: must fetch envelope and create local task, not just `debugPrint`. (Issue #5)
- [ ] **iOS APS payload**: separate user-visible (`priority 10`, no `content-available`) from data-only (`priority 5`, `content-available: 1`). (Issue #6)
- [ ] **Mobile token-registration retry**: handle 409 from diary_server with backoff retry (and on next foreground). (Issue #7)
- [ ] **`DELETE /api/v1/user/fcm-token`**: new diary_server endpoint, called by mobile on logout / unlink. (Issue #8)
- [ ] **HTTP timeout** on FCM client (≤ 10s). (Issue #11)
- [ ] **Capture `fcm_message_id`** in delete and unlock audit rows. (Issue #12)
- [ ] **Server-side suppression**: don't FCM-send for `eq`. Encode "should this kind notify?" in one place. (Issue #14)
- [ ] **Reduce log token prefix to 8 chars**. (Issue #16)
- [ ] **Decide & implement `app_version` usage** — even if it's just a column comment that says "currently informational." (Issue #15)
- [ ] **iOS permission UX**: detect denied state, surface in-app banner with "Enable in Settings" deeplink. (Issues #9, #19)

### Phase 2 additions (mobile polling)
- [ ] **Per-kind dedup** on both push receive and polling paths — envelope ids are unique, but the same envelope can arrive via FCM AND polling, so the renderer must dedupe by `notification_id`. (Issue #20)
- [ ] **Deep-link routing** from `getInitialMessage()` and `onMessageOpenedApp` — mobile derives the route from `(notification_type, payload.action)` plus IDs in `payload`. (Issue #10)

### Phase 3 additions (Terraform + UNREGISTERED)
- [ ] **Alerting policy** on `fcm_notifications_total{status="failed"}` / `total > 5%` over 1h. (Issue #17)

### Standalone tickets (file separately; don't bundle)
- [ ] **Sponsor isolation guard**: `sponsor_id` on `notifications`, server-side cross-check before send. (Issue #21)
- [ ] **`patients.timezone`** column. (Issue #22)
- [ ] **`notification_preferences` table** if/when product asks. (Issue #23)
- [ ] **APNs key check on cure-hht-admin** — operational ticket, not code. (Issue #24)
- [ ] **Per-patient rate limit**. (Issue #25)

## Recommendation update

The Critical bugs (#1, #2, #3, #4, #5, #6, **#26**, #27) are shipping incorrect behavior **today** regardless of architecture. Cluster them as a "stabilize current FCM" PR alongside Phase 0's IAM grant — this can ship in a day or two and de-risks Phase 1. **Issue #26 (audit constraint) should be the highest-priority item in this PR** because it has FDA compliance implications and is failing silently in every environment running migration 007.

The High bugs (#7–#12) get folded into Phase 1 as part of the envelope refactor.

Medium and Low items either ship inside the relevant phases (per the checklist above) or as standalone tickets when product prioritizes them.

---

## Final shipping order

Ship in order: **Phase 0 → Stabilize-current-FCM PR (Critical bugs) → Phase 1 → Phase 2 → Phase 3**.

- **Phase 0** — IAM grant. Unblocks today's flow.
- **Stabilize PR** — Critical bug fixes against current architecture (audit constraint, status-change notifications, token sharing fix, etc.).
- **Phase 1** — Notifications table + envelope API + every-status-change-sends-FCM. Compliance-safe by design.
- **Phase 2** — Mobile polling. Required, not optional — carries the entire reliability story now that backend retries are dropped.
- **Phase 3** — Terraform IAM + UNREGISTERED cleanup + alerting. Reliability hardening.

The original Phase 2 (Cloud Tasks) and Phase 5 (Outbox) are dropped. Mobile polling covers all the failure modes those phases addressed; backend retries would be redundant.

## File reference

| File | Phase | Change |
|---|---|---|
| `database/migrations/010_add_fcm_notification_action_type.sql` (new) | Stabilize | Add `'FCM_NOTIFICATION'` to `admin_action_log` check constraint |
| `database/migrations/0XX_notifications_table.sql` (new) | 1 | `notifications` table; `device_id` on `patient_fcm_tokens`; `ON DELETE CASCADE` |
| `apps/sponsor-portal/portal_functions/lib/src/notification_service.dart` | Stabilize, 1 | Status-change senders; UID-only payload after Phase 1 |
| `apps/sponsor-portal/portal_functions/lib/src/questionnaire.dart` | Stabilize, 1 | `finalizeQuestionnaireHandler` sends; all four sites switch to envelope insert + send |
| `apps/sponsor-portal/portal_functions/lib/src/patient_linking.dart` | Stabilize, 1 | Five status-change handlers each send their respective envelope |
| `apps/daily-diary/diary_functions/lib/src/notifications.dart` (new) | 1 | `GET /notifications/{id}`, `GET /notifications?since=` |
| `apps/daily-diary/diary_functions/lib/src/fcm_token.dart` | Stabilize, 3 | Cross-patient token deactivation; UNREGISTERED handling; `DELETE /fcm-token` |
| `apps/daily-diary/clinical_diary/lib/services/notification_service.dart` | Stabilize, 1, 2 | Mobile handlers for new kinds; envelope fetch; polling on resume |
| `apps/daily-diary/clinical_diary/lib/services/task_service.dart` | Stabilize | New `case` arms for status-change kinds in `handleFcmMessage` |
| `infrastructure/terraform/sponsor-envs/main.tf` | 3 | `google_project_iam_member` for `cloudmessaging.admin` on cure-hht-admin |
