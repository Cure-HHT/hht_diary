# DIARY-DEV-pluggable-push-transport: Pluggable Push-Notification Transport

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-DEV-outgoing-intent-correlation

## Assertions

A. The push send seam SHALL be transport-neutral: the notification-dispatch reactor SHALL depend on a generic push channel that accepts a routing target and a message, and the FCM transport SHALL be one adapter of that seam rather than the seam itself.

B. The active push transport SHALL be selected at server bootstrap from a single configuration switch, mirroring the authentication-mode switch; an unrecognized value SHALL fail fast at startup rather than degrade silently.

C. A local transport SHALL deliver a push to a *Participant*'s live device connection located through an in-process registry keyed by *Participant*; the absence of a live connection SHALL be recorded as a dispatch failure and SHALL NOT raise an unhandled error.

D. The device SHALL select a push receiver appropriate to its runtime: the local-transport receiver SHALL register its device-routing identifier through the same token-registration path as the FCM receiver and SHALL feed received pushes into the same receipt-to-event-to-reconcile path, so the recorded event names are identical regardless of transport.

## Rationale

Push delivery is "wake/notify this *Participant*'s device". Only the literal wire is FCM-coupled; the reactor, the active-token projection, the flow-token correlation, and the device's receipt path are already transport-neutral. Raising the send seam to a generic push channel (FCM as an adapter, a local-socket channel as a second adapter) lets the *Sponsor Portal* drive real-time push to a web or desktop *Diary* over the local-stack with no device emulator and no live FCM project — the fast iteration loop for the portal-*Action*-to-receipt business logic. Web and desktop *Diary* clients cannot do FCM at all (FCM-web needs a service worker plus VAPID; desktop has no FCM), so the local transport is not merely a test shim but the natural delivery path for those clients. The transport is chosen by a single bootstrap switch parallel to the authentication-mode switch; an unknown value fails fast so a misconfiguration surfaces at deploy, not at a *Participant*'s device. The local transport rides a dedicated *Participant*-scoped WebSocket the *Diary* holds to the portal (the *Diary* holds no other live portal socket), authenticated in-band with the *Participant* token; a missing connection is the local analogue of "no active token" and is recorded, never thrown. The event names (`fcm_token_registered` / `fcm_message_received`) are deliberately retained — they are catalog ids and renaming them would be a breaking change for no functional gain; only the code interfaces are generalized to push-neutral names.

## Requirements (design provenance)

Authored under CUR-1466. Existing applicable requirements that bound this work:

- `DIARY-DEV-outgoing-intent-correlation` (this repo, `spec/dev-outgoing-intent-correlation.md`) — the parent: record-intent-before-deliver, ride the existing push path, mint-and-carry the flow token. This requirement refines it by making "the push path" pluggable.
- `DIARY-DEV-inbound-event-on-receipt` (this repo) — the device receipt-to-event path the local receiver reuses unchanged.
- `DIARY-OPS-fcm-project-routing` (this repo, `spec/ops-push-notifications.md`) — FCM *configuration* (project routing, sender grant) is explicitly out of scope here and remains covered there; the local transport deliberately bypasses it.
- `EVS-PRD-destinations`, `EVS-DEV-flow-token` (event_sourcing repo) — library primitives, cited via the parent's `**Integrates**` edges.

*End* *Pluggable Push-Notification Transport* | **Hash**: 0493012c
