# Real Android device E2E runbook (hybrid: automate link + verify, manual entries)

End-to-end check of the diary app on a **real Android device** wired to the local
stack: the device links to a participant, the tester records a spread of diary
entries by hand, and a script confirms those entries were ingested into the
portal's Postgres event log + canonical view.

This is intentionally **hybrid** — the deterministic parts (stand up the stack,
issue a link code, verify ingest) are scripted; the part a phone is actually
needed for (tapping through the diary UI) is a manual checklist. It is a one-off
diagnostic, not a CI job.

- **Automated:** local stack, link-code issuance, Postgres ingest verification.
- **Manual:** install/sideload the app, link it, record entries on the device.

Related automated coverage (no device required, runs in CI): the link loop,
relink/reconnect/reactivate, idempotent redelivery, and diverse event types are
covered hermetically by `portal_server_evs/test/*_e2e_test.dart`. This runbook
is what those tests *cannot* cover: a genuine device, its keyboard/timezone,
cleartext networking, and FCM registration on real hardware.

## Prerequisites

- Android device in **Developer Mode** with USB debugging on, connected and
  visible to `adb devices`.
- `flutter`, `adb`, `docker`, `psql` available on the host.
- The throwaway Postgres + `portal_server_evs` running (the `run-link-e2e.sh`
  harness already stands these up; see step 1).

## 1. Stand up the local stack (Postgres + portal_server_evs)

Reuse the existing harness, which resets the throwaway Postgres (`evs-pg` on
`:5433`), boots `portal_server_evs` on `:8084` in dev-auth mode, and seeds the
`DevSeedRaveClient` participants:

```bash
# Boots the Postgres-backed server; leave it running (Ctrl-C the Playwright step
# if it proceeds — we only need the server + DB up).
apps/sponsor-portal/portal_ui_evs/scripts/run-link-e2e.sh
```

Confirm the server is healthy:

```bash
curl -s http://localhost:8084/health    # -> ok
```

The seeded participants are `DEV-001-001`, `DEV-001-002`, `DEV-002-001`,
`DEV-003-001` (sites `site-1/2/3`). Pick one, e.g. `DEV-001-001`, as the
participant the device will link to.

## 2. Issue a linking code (automated)

Issue a code via the real `/actions` endpoint as a coordinator (dev-auth mode
trusts the bearer user id):

```bash
curl -s -X POST http://localhost:8084/actions \
  -H 'authorization: Bearer sc-1' \
  -H 'content-type: application/json' \
  -d '{
        "actionName": "ACT-PAT-001",
        "rawInput": {"siteId": "site-1", "participantId": "DEV-001-001"},
        "idempotencyKey": "device-runbook-1"
      }'
# -> { ... "linkingCode": "XX........", "expiresAt": "..." }
```

Copy the `linkingCode` from the response.

## 3. Point the device at the host and install the app (manual)

The device must reach `portal_server_evs` on the host. Two options:

- **adb reverse (simplest, USB):** map the device's localhost to the host port,
  then use `http://localhost:8084` as the API base:
  ```bash
  adb reverse tcp:8084 tcp:8084
  ```
- **LAN IP:** put the device on the same network as the host and use
  `http://<host-LAN-IP>:8084` as the API base instead.

Build + install the **dev** flavor pointed at the local server. `DIARY_API_BASE`
is the compile-time override (see `clinical_diary/lib/config/app_config.dart`):

```bash
cd apps/daily-diary/clinical_diary
flutter run --flavor dev -d <device-id-from-adb-devices> \
  --dart-define=DIARY_API_BASE=http://localhost:8084
```

> Cleartext gotcha: Android blocks cleartext (plain `http`) traffic by default.
> If the app cannot reach the server, the dev flavor needs
> `android:usesCleartextTraffic="true"` (or a network-security-config allowing
> the host) for this local-http test. Do NOT ship that in qa/uat/prod.

## 4. Link the device (manual)

In the app: user menu → **Link to Clinical Trial** → enter the `linkingCode`
from step 2 (two halves) → accept the privacy consent → submit. Expect the
enroll-success confirmation. Under the hood this calls `/link`, mints the
participant JWT, and consumes the code.

## 5. Record a spread of diary entries (manual checklist)

On the device, record at least one of each so the verifier sees diverse types:

- [ ] An **epistaxis** (nosebleed) event — exercises the bare-uuid aggregate path.
- [ ] A **no-nosebleed** day — exercises the per-day `pid:date` marker aggregate.
- [ ] An **unknown day** — second per-day marker variant.
- [ ] A **questionnaire / survey** entry if one is assigned — exercises the
      dynamic `<id>_survey` entry type.

Give the device a moment to sync (it ships finalized events to `/ingest`).

## 6. Verify ingest landed in Postgres (automated)

Run the verifier against the participant you linked:

```bash
apps/sponsor-portal/portal_server_evs/scripts/verify-device-ingest.sh DEV-001-001 \
  epistaxis_event no_epistaxis_event unknown_day_event
# add a survey id (e.g. phq9_survey) if you recorded one
```

It prints the ingested diary events from the `events` log, the materialized
`diary_entries` view rows, and a PASS/MISS line per expected entry type. A
`RESULT: PASS` means every expected type was ingested and is the green signal for
this run.

## 7. Tear down

```bash
fuser -k 8084/tcp 2>/dev/null || true   # stop the server
adb reverse --remove tcp:8084 2>/dev/null || true
```

## What this run additionally exercises (vs the hermetic tests)

- Real on-device keyboard entry and the device's own timezone on captured
  timestamps (the canonical local-day derivation, `canonicalEntryDate`).
- Cleartext networking from a physical device to the host.
- FCM token registration on real hardware (`fcm_token_registered`) — note this is
  device-local and does **not** flow to the portal `diary_entries` view; confirm
  it via the device logs, not the verifier.
