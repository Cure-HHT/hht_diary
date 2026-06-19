# Sponsor Portal

Clinical-trial sponsor web portal for managing users, sites, and trial-data access. The
portal is **event-sourced**: it runs over the `event_sourcing` library, with permissions and
audit recorded as events in the event log rather than as relational rows.

## Components

| Directory            | Description                                                                 |
| -------------------- | --------------------------------------------------------------------------- |
| `portal_ui_evs/`     | Reactive Flutter web client (`reaction_widgets` over a live WebSocket)       |
| `portal_server_evs/` | Dart `reaction` HTTP/WS shell that fronts `portal_service`                   |
| `portal_service/`    | Event-sourced enforcement core (action dispatcher + authorization)          |
| `portal_identity/`   | GCP Identity Platform + Gmail-over-WIF helpers (no Postgres)                 |

The deployable container image is built in the sponsor repo (e.g.
`hht_diary_callisto/deployment/docker/portal-final.Dockerfile`), which inherits from the
`sponsor-ci` image published by this repo and embeds the sponsor's content tree. The deployed
Cloud Run service is named `portal-service`.

## Architecture

```text
  portal_ui_evs           portal_server_evs          portal_service             event_sourcing
  (Flutter web)  --WS-->  (reaction HTTP/WS shell) -> (dispatch + authz core) -> event store (Cloud SQL)
       |
       v
  GCP Identity Platform (portal sign-in; Firebase auth emulator locally)
```

- **Access control & audit** are event-sourced: role assignments, actions, and audit are
  events in the log; `portal_service` evaluates permissions over its own projections. There is
  no in-repo SQL schema or row-level-security — the event-store schema is created and owned at
  runtime by the `event_sourcing` library's `PostgresBackend`.
- **Auth**: GCP Identity Platform in deployed environments; the Firebase auth emulator locally.

## Running locally

Use the local-stack — it builds this repo's source and runs the full event-sourced portal
(Postgres + Firebase auth emulator + `portal-final`) on one Docker network:

```bash
./deployment/local-stack/local-stack portal   # portal on :8080, Firebase emulator UI on :4000
```

See `deployment/local-stack/README.md` for the full command reference (logs, email/OTP console,
reset, teardown). For the standalone reactive UI slice against a local server, `portal_ui_evs`
also ships a `./run.sh` (starts `portal_server_evs` + `flutter run -d chrome`).

## Tests

Per `.github/workflows/sponsor-portal-ci.yml`:

```bash
# Event-sourced server: hermetic link/ingest e2e (in-memory; no Postgres, no emulator)
cd apps/sponsor-portal/portal_server_evs && dart test

# Reactive UI: analyze + unit tests
cd apps/sponsor-portal/portal_ui_evs && flutter test
```

## Related documentation

- `deployment/local-stack/README.md` — running the portal locally
- `portal_service/`, `portal_server_evs/`, `portal_ui_evs/`, `portal_identity/` — per-package source and docs
- `spec/` — portal requirements (`prd-*`, `dev-*`); see `spec/INDEX.md`
