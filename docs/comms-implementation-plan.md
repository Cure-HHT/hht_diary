# Comms / FCM on EVS

How push notifications work on the event-sourced (EVS) stack. The transport
(`comms` package) is built; wiring it into the portal is **CUR-1436** (in progress).

## Topology

Mobile device → **portal-server (`portal_server_evs`) directly** — no diary-server
relay. Notifications are dispatched from the portal; the device receives via FCM and
reconciles its state. Push is the primary channel; the polling backup is
`GET /api/v1/user/state` (wired in CUR-1409).

## Transport — `apps/common-dart/comms/`

The single, generic FCM send path (no logic smeared across server handlers):

- **`FcmChannel`** (`lib/src/channels/fcm/fcm_channel.dart`) → `POST
  fcm.googleapis.com/v1/projects/{projectId}/messages:send`, authenticated with
  ADC/WIF (`adc_client.dart`). Default project `cure-hht-admin` (shared FCM;
  default-app-only — see CUR-1399).
- **`OutboxWriter`** (`lib/src/notifications/outbox_writer.dart`) — persist-then-dispatch:
  `insertPending` → dispatch → `markSent` / `markFailed`. Durable and replay-safe.
- **`Envelope`** (`lib/src/notifications/envelope.dart`) — snake_case wire format; the
  device fetches the body via `/api/v1/notifications/{id}`. `userVisible` selects an
  APNS alert (priority 10) vs a silent data message (priority 5 + `content-available`).
- **`PayloadGuard`** (`lib/src/compliance/payload_guard.dart`) — PHI-free egress guard,
  **fail-closed in release**, run before any network call. Built-in `subject_key` /
  email blocks; sponsor-extendable name patterns.
- **Token model** — `participant_fcm_tokens` (one active token per device). An FCM
  `404 UNREGISTERED` → `DispatchResult.unregisteredToken()` → `OutboxWriter.onUnregistered`
  deactivates the row (self-healing). Sends target every active device, not `LIMIT 1`.

## Project & IAM

FCM lives in `cure-hht-admin`. Each sponsor's Cloud Run service account holds a
least-privilege `fcmSender` custom role on `cure-hht-admin`, granted via **hht_admin
terraform** (CUR-1418 — not a manual `gcloud` grant). The declarative routing-manifest
seam is `hht_sponsor_iac/fcm/routing.yaml`; a per-sponsor Firebase split is deferred
(CUR-1399). Normative rules: `spec/ops-push-notifications.md`
(`DIARY-OPS-fcm-project-routing`).

## Device receive

`clinical_diary/lib/services/notification_service.dart` — foreground (`onMessage`),
background, and terminated handlers, plus token registration/refresh. Receiving a push
triggers an immediate `/state` reconcile, converging on the same lifecycle behavior the
polling backup produces.

## Remaining work — CUR-1436 (EVS FCM dispatch)

1. FCM token-registration endpoint on `portal_server_evs` (persist to `participant_fcm_tokens`).
2. Wire `comms` into `portal_server_evs` — instantiate `FcmChannel` + `OutboxWriter` (ADC auth).
3. Participant-notification subscriber reactor: consume participant-lifecycle events
   (`participant_disconnected` / `_marked_not_participating` / `_reconnected` /
   `_reactivated`, plus questionnaire sends) → emit `notification_sent`, push via FCM,
   correlate via the `flowToken` the actions already mint.
4. Emulator / fake-channel wiring so the path is exercisable without live FCM.

## Authoritative sources

- **Normative:** `spec/ops-push-notifications.md`, `spec/prd-mobile-notifications.md`,
  `spec/prd-notification-behavior.md`.
- **Code:** `apps/common-dart/comms/` (+ its tests).
- **Live execution:** CUR-1436.
