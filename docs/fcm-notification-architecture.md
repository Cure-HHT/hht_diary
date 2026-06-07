# FCM Notification Architecture

> **⚠️ HISTORICAL — describes the retired relational / two-service architecture (pre-EVS).**
> This document predates the EVS cutover (CUR-1170 / CUR-1437) and the portal-only topology
> (CUR-1446). It describes a now-retired design: a separate `diary-server` Cloud Run service, a
> shared relational Cloud SQL database, and `patient_fcm_tokens` / `database/migrations` tables —
> all of which have been removed. **Current architecture:** the device syncs directly to
> `portal_server_evs` (no separate diary-server node); FCM-token and notification data are events in
> the `event_sourcing` store (schema created at runtime), not relational tables. Treat the GCP
> layout, diagrams, and code paths below as historical reference only. Authoritative current
> sources: `spec/ops-push-notifications.md`, `spec/dev-participant-ingest.md`. A full EVS-FCM
> rewrite tracks with CUR-1416 / CUR-1418 / CUR-1399.

## GCP Project Layout

```
cure-hht-admin (shared org project)
├── Artifact Registry          — container images (GHCR remote proxy)
├── Gmail SA                   — org-wide email sending
├── FCM                        — push notifications (mobile app registers here)
└── Workload Identity Fed.     — CI/CD (GitHub Actions → GCP)

{sponsor}-{env} (per-sponsor project, e.g. callisto4-dev)
├── Cloud Run: diary-server    — mobile app backend
├── Cloud Run: portal-server   — admin portal backend
├── Cloud SQL (PostgreSQL 17)  — shared database (private IP only)
├── Identity Platform          — portal auth (per-sponsor Firebase)
├── Service Account            — {sponsor}-{env}-run-sa (shared by both servers)
└── VPC + Serverless Connector — private Cloud SQL access
```

**Key fact:** Both servers run in the **same sponsor GCP project** and share one Cloud Run Service Account. The cross-project boundary is only between the sponsor project and `cure-hht-admin`.

## Current Flow (How It Works Today)

### Step 1: Mobile App Registers FCM Token

```
Mobile App (Flutter)
    |
    |  On login / token refresh, gets FCM token from
    |  Firebase project "cure-hht-admin"
    |
    |  POST /api/v1/user/fcm-token
    |  Body: { "fcm_token": "xxx", "platform": "android"|"ios" }
    |
    v
Diary Server (Cloud Run, sponsor project)
    |
    |  Verifies JWT → looks up patient_id via patient_linking_codes
    |  Deactivates old tokens for same patient+platform (UPSERT)
    |  Inserts new token
    |
    v
Cloud SQL ─── patient_fcm_tokens table
              ├── patient_id     (FK to patients)
              ├── fcm_token      (device token)
              ├── platform       (android | ios)
              ├── app_version    (optional)
              ├── is_active      (boolean, one active per patient+platform)
              └── updated_at
```

**Code:** `apps/daily-diary/diary_functions/lib/src/fcm_token.dart`

### Step 2: Admin Action → FCM Sent Inline

```
Admin (Sponsor Portal UI)
    |
    |  e.g. "Send Questionnaire to Participant"
    |
    v
Portal Server (Cloud Run, sponsor project)
    |
    |  1. Writes business data to DB (questionnaire instance, admin_action_log)
    |  2. Queries patient_fcm_tokens for active token (LIMIT 1)
    |  3. Calls FCM HTTP v1 API INLINE (same request handler, blocks until done)
    |
    |     POST https://fcm.googleapis.com/v1/projects/cure-hht-admin/messages:send
    |
    |     Auth: Cloud Run SA uses ADC (Application Default Credentials)
    |     The SA has "fcmSender" IAM role on cure-hht-admin project
    |     → cross-project access, no key files needed
    |
    |  4. Logs result to admin_action_log (action_type='FCM_NOTIFICATION')
    |
    v
FCM (cure-hht-admin project)
    |
    v
Mobile App receives push notification
```

**Code:** `apps/sponsor-portal/portal_functions/lib/src/notification_service.dart`

### How Cross-Project FCM Works

```
Portal Server's Cloud Run SA ({sponsor}-{env}-run-sa)
    |
    |  Has IAM role: "fcmSender" on project "cure-hht-admin"
    |  Auth: Workload Identity Federation (ADC) — no key files
    |  Token auto-refreshes 5 min before 1-hour expiry
    |
    v
FCM API: fcm.googleapis.com/v1/projects/cure-hht-admin/messages:send
    |
    |  The FCM token was registered by the mobile app against
    |  cure-hht-admin, so FCM recognizes and delivers it
    |
    v
Mobile App (registered with cure-hht-admin Firebase)
```

### Current Notification Types

| Event Type               | Trigger                          | Message                                     |
|--------------------------|----------------------------------|---------------------------------------------|
| `questionnaire_sent`     | Investigator sends questionnaire | "New Questionnaire Available"               |
| `questionnaire_deleted`  | Investigator deletes questionnaire | Data-only (removes task from app)          |
| `questionnaire_unlocked` | Investigator unlocks questionnaire | "Questionnaire Unlocked"                  |
| `trial_started`          | Investigator starts participant trial | (via sendQuestionnaireNotification)         |

**Code locations:**
- Send handler: `portal_functions/lib/src/questionnaire.dart` (lines 667-677, 905-912, 1079-1086)
- Trial start: `portal_functions/lib/src/patient_linking.dart` (line 1160)
- Audit logging: Every send recorded in `admin_action_log` with `action_type='FCM_NOTIFICATION'`

## Known Weaknesses

### 1. Fire-and-Forget — No Retry

If FCM fails (network blip, token expired, FCM outage), the notification is lost. The code logs a warning and continues:

```dart
if (!notificationResult.success) {
  logWithTrace('WARNING', 'FCM notification failed' ...);
  // No retry. Notification is gone.
}
```

### 2. Inline Blocking — Slows Admin Requests

FCM send happens inside the HTTP request handler. If FCM API is slow (500ms–2s), the admin waits. The business action (DB write) is already done — the notification shouldn't block the response.

### 3. Single Device Per Participant

```sql
SELECT fcm_token FROM patient_fcm_tokens
WHERE patient_id = @patientId AND is_active = true
ORDER BY updated_at DESC
LIMIT 1    -- ← Only one device gets notified
```

If a participant has both an iPhone and Android device, only the most recently updated one receives notifications.

### 4. No Stale Token Cleanup

When FCM returns HTTP 404 with `UNREGISTERED` error (token expired, app uninstalled), the token stays `is_active = true`. Every future send to that participant fails silently.

### 5. Duplicated Token Lookup

The same FCM token query is copy-pasted in 4 handler locations instead of being a shared helper.

### 6. Cross-Project IAM Not in Terraform

The `fcmSender` IAM grant on `cure-hht-admin` for each sponsor's Cloud Run SA is **not codified in Terraform**. This means:
- New sponsor onboarding requires a manual IAM grant
- If forgotten, FCM silently fails for that sponsor
- SA rotation or recreation breaks FCM until manually re-granted

## Recommended Improvements

### Priority 1: Quick Wins (no new infrastructure)

| # | Improvement | What to Do |
|---|---|---|
| 1 | **Handle UNREGISTERED tokens** | On FCM 404, set `is_active = false` in `patient_fcm_tokens` |
| 2 | **Send to all active devices** | Remove `LIMIT 1`, loop over all active tokens for the participant |
| 3 | **Extract token lookup** | Single `getActiveTokensForPatient()` helper, replace 4 copies |
| 4 | **Add fcmSender to Terraform** | `google_project_iam_member` in sponsor-envs for cross-project FCM |

### Priority 2: Reliability (Cloud Tasks — $0 cost)

Replace inline FCM sends with GCP Cloud Tasks for async delivery with built-in retries:

```
Admin Handler → writes DB → enqueues Cloud Task → returns response immediately
                                   |
                                   v
                    Cloud Task calls /internal/send-notification
                                   |
                                   v
                    Portal Server sends FCM + logs audit
                    (auto-retries on failure, up to configurable max)
```

**Why Cloud Tasks:**
- Free tier: 1M tasks/month (more than enough)
- Built-in retry with exponential backoff
- No new infrastructure — just an API call to enqueue
- Admin request returns immediately (no FCM latency)
- Dead-letter queue for permanently failed notifications

### Priority 3: Outbox Pattern (future scale)

Only needed if notification volume grows significantly or if more services need to trigger notifications. Adds a `notification_events` table written in the same DB transaction as business data, processed asynchronously.

**Not recommended now** — Cloud Tasks (Priority 2) provides the same reliability guarantees without adding DB tables or worker processes.

## Cross-Project Considerations

| Concern | Status | Risk |
|---|---|---|
| **IAM fcmSender grant** | Manual, not in Terraform | High — breaks on new sponsor |
| **ADC token scope** | `cloud-platform` scope via ADC | Low — works automatically |
| **Network / VPC** | FCM is public API, egress is `PRIVATE_RANGES_ONLY` | None — public calls work |
| **FCM quota** | Shared across all sponsors on `cure-hht-admin` | Low — unlikely at current scale |
| **SA rotation** | Would need fcmSender re-granted | Medium — should be in Terraform |
| **Billing** | FCM API usage billed to `cure-hht-admin` | Low — FCM is free for standard use |

## Sequence Diagram (Current Flow)

```
Admin          Portal Server      Cloud SQL       cure-hht-admin FCM     Mobile App
  |                 |                  |                  |                    |
  |--action-------->|                  |                  |                    |
  |                 |--write data----->|                  |                    |
  |                 |--query token---->|                  |                    |
  |                 |<--fcm_token------|                  |                    |
  |                 |--POST /messages:send--------------->|                    |
  |                 |   (ADC auth, fcmSender role)        |                    |
  |                 |<--200 OK-------------------------- -|                    |
  |                 |--log audit------>|                  |--push------------->|
  |<--200 OK--------|                  |                  |                    |
```

## File Reference

| File | Purpose |
|---|---|
| `apps/sponsor-portal/portal_functions/lib/src/notification_service.dart` | FCM send logic (HTTP v1 API, ADC auth, audit logging) |
| `apps/daily-diary/diary_functions/lib/src/fcm_token.dart` | FCM token registration handler |
| `apps/sponsor-portal/portal_functions/lib/src/questionnaire.dart` | Questionnaire handlers (send, delete, unlock — trigger FCM) |
| `apps/sponsor-portal/portal_functions/lib/src/patient_linking.dart` | Patient linking (trial start triggers FCM) |
| `apps/daily-diary/clinical_diary/lib/services/notification_service.dart` | Mobile app FCM receiver (foreground, background, terminated) |
| `infrastructure/terraform/sponsor-envs/variables.tf` | `admin_project_id` defaults to `cure-hht-admin` |
| `infrastructure/terraform/modules/cloud-run/main.tf` | Cloud Run SA roles (missing fcmSender cross-project) |
| `database/migrations/004_questionnaire_and_fcm_tokens.sql` | `patient_fcm_tokens` table migration |
