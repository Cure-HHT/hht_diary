# local-stack (EVS)

Developer-machine rehearsal of the Cloud Run `dev` deployment for the
event-sourced (EVS) architecture. Brings up the Firebase auth emulator,
otel-lgtm telemetry, the EVS portal (`portal-final`), and — in the default
durable mode — a plain Postgres event store, all on a single docker bridge
network built from your local working trees.

**The portal is the only backend.** `portal-final` serves *both* the portal
UI/API and the mobile diary's API on `http://localhost:8080`. There is no
separate diary-server. The portal is event-sourced and **creates its own
event-store tables on boot** — there is no schema job, no `init.sql`, and no
seeded `patients`/`portal_users` tables. SystemOperator seed identities come
from the sponsor's `deployment/seed/portal-users.json`, baked into the
`portal-final` image and applied idempotently on boot.

## This toolkit lives in core and resolves the sponsor repo

This toolkit lives in the **core** repo (`hht_diary`). The **core path** is the
toolkit's own checkout (`git rev-parse --show-toplevel`), so it needs no
configuration. What it resolves at runtime is the **sponsor** build inputs:
`deployment/base-config.json` (sponsor id + EDC module), the
`portal-final.Dockerfile`, `content/`, and `deployment/seed/portal-users.json`.

By default it needs **no sponsor checkout at all**: it falls back to the
built-in **reference sponsor** that ships in core at
`deployment/reference-sponsor/` (sponsor id `reference`, empty `content/`
overlay). This is what lets a core dev rehearse the dev stack from `hht_diary`
alone — e.g. to reproduce a Postgres-only event-store bug — without checking out
any sponsor repo.

Sponsor resolution order (see `lib/resolve-sponsor-path.py`):

1. The `SPONSOR_REPO` env var, if set (absolute path). This is how the
   sponsor-side thin wrapper (`deployment/local-stack-wrapper.sh` in the
   sponsor repo) drives the toolkit — it exports `SPONSOR_REPO` to its own repo
   root and execs this CLI. Running the local-stack from a sponsor repo
   therefore uses that sponsor.
2. Otherwise, `[associated.sponsor].path` in `.local-stack.toml` at this
   toolkit's root (`deployment/local-stack/.local-stack.toml`), overlaid with
   `.local-stack.local.toml` (gitignored, per-developer) if present, resolved
   relative to the toolkit root. (The checked-in `.local-stack.toml` ships
   without this block, so it is unset unless a dev adds it.)
3. Otherwise, the built-in reference sponsor at
   `<core>/deployment/reference-sponsor` — the bare-core default.

The resolved sponsor is validated by the marker file
`deployment/base-config.json` (which the reference sponsor also carries). To
rehearse a **real** sponsor from a core checkout (instead of the reference one),
override the default:

```bash
# Option A: export an absolute path (also how the sponsor wrapper works)
SPONSOR_REPO=/abs/path/to/hht_diary_<sponsor> ./deployment/local-stack/local-stack portal
```

```toml
# Option B: deployment/local-stack/.local-stack.local.toml
[associated.sponsor]
path = "/abs/path/to/hht_diary_<sponsor>"
```

A relative `[associated.sponsor].path` resolves against the toolkit root, so the
canonical sibling layout (`../../../hht_diary_<sponsor>`) works from a normal
clone but not from a git worktree (one level deeper) — use an absolute path
there, or run from the sponsor repo.

## Prerequisites

- Docker Engine >= 24 with the `docker compose` v2 plugin
- Doppler CLI, authenticated (`doppler login`) and set up for the dev config (`doppler setup`)
- Python >= 3.11 (for the TOML path resolver -- `tomllib` is stdlib in 3.11+)
- **No `docker login ghcr.io` required** for the default run: the CI toolchain
  base image is built locally (see "CI base image" below). Only `--ci-base ghcr`
  needs GHCR access.
- **No sponsor checkout required** for the default (reference-sponsor) run. To
  rehearse a real sponsor, either run the local-stack from the sponsor repo, or
  point this toolkit at a sponsor checkout. Canonical sibling layout:

  ```text
  ~/cure-hht/hht_diary            (core — this toolkit's home + reference sponsor)
  ~/cure-hht/hht_diary_<sponsor>   (sponsor, optional)
  ```

  Select a real sponsor via `SPONSOR_REPO` or `.local-stack.local.toml` (see above).

- `bats` (>= 1.5) and `jq` for the test suite (optional, dev-only).

## Backend store: durable (default) vs ephemeral

- **Durable (default)**: Postgres runs as a plain, empty event store and the
  portal points `DB_HOST` at it. State survives `down --keep-db`. Postgres is
  gated behind the compose `durable` profile.
- **Ephemeral** (`--ephemeral` or `LOCAL_STACK_EPHEMERAL=1`): the portal runs
  an in-memory event store (no `DB_HOST`), and Postgres + its volume are
  skipped entirely. Nothing persists across `down`. Fastest to start; ideal for
  throwaway smoke tests.

## CI base image: local build (default) vs GHCR pull

The portal/server images build `FROM` `sponsor-ci`, which in turn builds `FROM`
`clinical-diary-ci` — the heavy CI toolchain image (Flutter SDK, Android SDK,
JDK, gcloud, scanners). Two ways to obtain it, selected by `--ci-base` (global
flag) or `LOCAL_STACK_CI_BASE`:

- **`local` (default)**: build `clinical-diary-ci:local` from core's
  `tools/dev-env/docker/ci.Dockerfile`, using the pinned tool versions in
  `.github/versions.env` (parity with CI). **Needs no `docker login ghcr.io`** —
  a bare core run is fully self-contained for the base image. The first cold
  build downloads the Flutter + Android SDK (several minutes); the image carries
  no sponsor suffix, so it is reused across runs and **survives `down`** (like
  `firebase-emulator:local`). It is rebuilt only when `ci.Dockerfile` or
  `versions.env` changes (Docker layer cache keeps the warm path fast) — i.e.
  about as rarely as CI publishes a new base.
- **`ghcr`** (`--ci-base ghcr` or `LOCAL_STACK_CI_BASE=ghcr`): pull the
  digest-pinned `clinical-diary-ci` from GHCR — faster and byte-identical to the
  CI/deploy base, but **requires `docker login ghcr.io`** (the package is
  private). `sponsor-ci.Dockerfile`'s `ARG CI_BASE_IMAGE` default is this digest,
  so this mode simply leaves the default in place.

The toolkit validates the selection up front: an unrecognized value, or `ghcr`
with no detectable `ghcr.io` credentials, fails fast with a specific message
before any build or Doppler token is created.

## Auth

The portal defaults to **dev auth** (`PORTAL_AUTH_MODE` unset → `"dev"`): log
in by typing a `userId` (an email) with no password. The SystemOperators in
`portal-users.json` are seeded on boot. To exercise real session auth, set
`PORTAL_AUTH_MODE=session` and wire Firebase — out of scope for the default
flow.

## Usage

```bash
# Bring up the stack (durable Postgres event store)
./deployment/local-stack/local-stack portal
# -> portal + diary API at http://localhost:8080
# -> firebase emulator UI at http://localhost:4000

# Same, but in-memory event store (no Postgres, nothing persists)
./deployment/local-stack/local-stack --ephemeral portal

# Re-running `portal` is safe: the portal self-creates its event-store
# tables; source changes are picked up via Docker layer cache on every run.

# Same as portal + Android emulator diagnostic & flutter run hints
./deployment/local-stack/local-stack full-system

# Tail logs (all services or one)
./deployment/local-stack/local-stack logs
./deployment/local-stack/local-stack logs portal-final

# Tail console-mode email output (OTPs, activation links, anything else
# EmailService would normally send). Equivalent to:
#   ./deployment/local-stack/local-stack logs portal-final | grep -A 20 'EMAIL CONSOLE MODE'
./deployment/local-stack/local-stack email

# Show running services
./deployment/local-stack/local-stack status

# Restart the Firebase auth emulator container to clear its in-memory
# rate-limit history + user state (e.g. you tripped your own rate limit).
# In EVS the portal mints firebase identities through its own auth flows, so
# this no longer re-seeds any table — just log in again afterward.
./deployment/local-stack/local-stack reset-emulator

# Wipe the Linux desktop diary client's local state. Use this after `down` +
# `portal` (or any --ephemeral run) so the client doesn't carry pointers
# (linking code, task ids, sequence numbers) into a fresh portal event store.
# Kills any running diary-desktop process, then deletes:
#   ~/Documents/diary.db                                    (sembast event log)
#   ~/.local/share/<APPLICATION_ID>/shared_preferences.json (cached tasks etc.)
#   gnome-keyring entries with account=<APPLICATION_ID>.secureStorage
#                                                           (enrollment, linking code)
# The keyring clear filters on a diary-specific attribute set by
# flutter_secure_storage_linux, so it can't touch other apps' secrets.
# Requires python3-secretstorage (`sudo apt install -y python3-secretstorage`).
./deployment/local-stack/local-stack diary-reset
./deployment/local-stack/local-stack diary-reset --no-kill        # skip the pkill step
./deployment/local-stack/local-stack diary-reset --keep-keyring   # leave keyring alone

# Teardown (containers + volumes + *:local images + revoke auto-created token)
./deployment/local-stack/local-stack down

# Same as above but preserve the Postgres volume (durable event store
# survives the next durable `portal`). No effect in --ephemeral mode.
./deployment/local-stack/local-stack down --keep-db
```

### Pointing the mobile diary client at the stack

The EVS portal serves the diary API on `:8080`. The `diary` / `diary-desktop`
subcommands launch the `clinical_diary` Flutter app with
`--dart-define=DIARY_API_BASE=http://localhost:8080` so it hits the portal:

```bash
# Web (Chrome):
./deployment/local-stack/local-stack diary

# Linux desktop (exposes the debug bridge on 127.0.0.1:9876):
./deployment/local-stack/local-stack diary-desktop
```

### Telemetry

Once `./local-stack portal` is up, OpenTelemetry signals from `portal-final`
are visible in Grafana:

- **Grafana UI:** <http://localhost:3000> (anonymous admin)
- **Traces:** Explore -> Tempo
- **Logs:** Explore -> Loki
- **Metrics:** Explore -> Prometheus

The collector listens on `otel-lgtm:4317` (OTLP gRPC) and `otel-lgtm:4318`
(OTLP HTTP) inside the stack network. The portal is configured via three env
vars in the compose file: `OTEL_EXPORTER_OTLP_ENDPOINT`,
`OTEL_EXPORTER_OTLP_PROTOCOL=grpc`, `OTEL_EXPORTER_OTLP_INSECURE=true`. The
last one is required because the dartastic_opentelemetry SDK defaults to TLS
regardless of the `http://` scheme in the endpoint URL.

### Reading email bodies in console mode

Console mode prints email bodies (OTP codes, activation links) to
portal-final's stdout instead of sending via the Gmail API. The discoverable
command is:

```bash
./deployment/local-stack/local-stack email
```

It tails portal-final's logs filtered to `EMAIL CONSOLE MODE` blocks; Ctrl-C to
exit. The output looks like:

```text
============================================================
[EMAIL CONSOLE MODE] Would send otp email:
  To: Mike Bushe <mike.bushe@anspar.org>
  Subject: Your verification code
------------------------------------------------------------
<email body containing the OTP / link>
============================================================
```

If `DOPPLER_TOKEN` is already in your environment (e.g. you ran via
`doppler run --config dev -- ./local-stack portal` yourself), the CLI uses it
directly. Otherwise the CLI auto-creates a scoped 24h service token for the dev
config and revokes it on `down`.

### URLs

```text
Service              URL
-------------------  -----------------------------------
Portal + diary API   http://localhost:8080
Firebase emulator    http://localhost:9099 (UI: :4000)
Postgres (durable)   localhost:5432 (user=postgres)
Grafana (telemetry)  http://localhost:3000
```

### Seeded users

The deployed/local portal seed is **SystemOperator-only**, read from the
sponsor's `deployment/seed/portal-users.json` (baked into `portal-final`,
applied idempotently on boot via `PORTAL_SEED_USERS_PATH`). For a real sponsor
these are its operator identities. Operators provision the first Administrators
through the portal. Under dev auth the `userId` is the login id you type
verbatim (no password); under session auth it's the Identity-Platform email.

## Known limitations

1. **`clinical_diary` Android AVD connectivity.** AVDs see the host as
   `10.0.2.2`, not `localhost`. The CLI's `flutter run` incantation passes the
   right `--dart-define` flags (including `DIARY_API_BASE=http://10.0.2.2:8080`),
   but verify `clinical_diary`'s `local` flavor honors the override on Android.
   Web/desktop usage works unmodified.

2. **No Firestore emulator.** Only Auth. Will be added when a server path
   actually depends on Firestore.

3. **Email is logged to console, not sent.** portal-final runs with
   `EMAIL_CONSOLE_MODE=true` so `EmailService` `print()`s email bodies to
   stdout instead of calling the Gmail API. Read OTPs / activation links /
   linking codes via `./local-stack email` (or `logs portal-final`).

4. **Push is local-socket, not FCM.** `PUSH_MODE` defaults to `local` (see
   `./local-stack --help` → Push), so the portal pushes to the diary in REAL
   TIME over a WebSocket (`/api/v1/user/push`, proxied with WS-upgrade headers
   by the sponsor nginx) instead of FCM — no `cure-hht-admin` send credentials
   needed. The diary runs as env=local and skips `firebase_messaging` init
   entirely, so there is no metadata-server credential noise on the device side.
   To see the loop: `./local-stack diary`, link a participant, then drive a
   portal action (e.g. disconnect the participant, or assign a questionnaire) —
   the diary's banner / reactive UI updates within a second or two with no user
   interaction. The transport is pluggable (mirrors `PORTAL_AUTH_MODE`); set
   `PUSH_MODE=fcm` to exercise the real FCM path, which needs FCM send
   credentials in the portal container (usually only a real cloud deploy).

## Troubleshooting

**`denied: unauthorized` during image build.** Only happens with `--ci-base
ghcr`. Either run `docker login ghcr.io` with a PAT that has `read:packages`
scope, or drop the flag to build the CI base locally (the default, no auth).

**`portal did not become healthy within 240s`.** Run `./local-stack logs` and
check the failing service. Common causes:

- portal-final timing out: usually a DB connection failure in durable mode.
  `docker compose exec portal-final env | grep DB_HOST` -- should be
  `postgres`. Try `--ephemeral` to rule the DB out. If a Cloud SQL host leaks
  through despite `--preserve-env`, check the doppler `dev` config.
- firebase-emulator slow: the **first** `portal` builds the cached
  `firebase-emulator:local` image (JRE + firebase-tools, ~45s). Subsequent runs
  reuse the image. Editing `firebase-emulator/Dockerfile` (e.g. bumping
  `FIREBASE_TOOLS_VERSION`) is picked up automatically via the layer cache.
- otel-lgtm slow: cold-cache pull plus Grafana/Tempo/Loki/Mimir bootstrap can
  take 60-90s on the first run; the budget is 240s.

**Force a fresh firebase-emulator base image.** The cached
`firebase-emulator:local` image survives `down` (no sponsor suffix, so the
image-removal loop doesn't touch it). To force a *full* rebuild from a
re-pulled `node:20-slim`:

```bash
./deployment/local-stack/local-stack down
docker image rm firebase-emulator:local
./deployment/local-stack/local-stack portal
```

**`Sponsor repo path does not exist`.** The resolver couldn't find the sponsor
repo. Export `SPONSOR_REPO=/abs/path/to/hht_diary_<sponsor>` or create
`.local-stack.local.toml` (see top of this README).

**Doppler `--max-age` flag rejected.** If your doppler CLI is older than 3.70
it may not support `--max-age`. The token will live until manually revoked or
you run `./local-stack down`.

**"Failed to send verification email" in the UI.** Expected -- see Known
limitations #3. The email body is in `./local-stack email`; grep for the
recipient. Paste the OTP into the verification-code input.

## Internals

```text
local-stack                   CLI entry point; subcommand dispatch
                              ([--ephemeral] portal / full-system /
                               down [--keep-db] / logs / email / status /
                               reset-emulator / rebind / diary* / debug / --help)
.local-stack.toml             optional [associated.sponsor] pointer at a real
                              sponsor repo; ships unset so the default is the
                              built-in reference sponsor (override per-dev via
                              .local-stack.local.toml or the SPONSOR_REPO env var)
../reference-sponsor/         built-in reference sponsor (sponsor id `reference`,
                              empty content overlay): base-config.json +
                              portal-final.Dockerfile + nginx + scripts/start.sh +
                              seed/portal-users.json + content/. The bare-core
                              default when no sponsor repo is selected.
lib/common.sh                 shared bash helpers
                              (log, die, require_cmd, require_env, CORE_PATH,
                               resolve_sponsor_path, resolve_sponsor, resolve_edc_module,
                               resolve_ci_base + ensure_ghcr_auth)
lib/resolve-sponsor-path.py   resolves the sponsor from SPONSOR_REPO,
                              .local-stack.toml (+ .local override), else the
                              built-in ../reference-sponsor; validates via
                              deployment/base-config.json marker
lib/build-images.sh           builds the cached firebase-emulator:local image
                              (one-time), the clinical-diary-ci:local CI base
                              (default --ci-base local; cached, survives `down`),
                              plus 3 sponsor-suffixed :local images
                              (sponsor-ci + portal-server-binary from core,
                               portal-final from the sponsor repo / reference)
firebase-emulator/Dockerfile  cached firebase-emulator:local image
                              (JRE + pinned firebase-tools); sponsor-agnostic
lib/doppler-token.sh          auto-creates a scoped service token if
                              DOPPLER_TOKEN absent; cleanup on 'down'
lib/android-helper.sh         AVD detection + emulator -avd boot hint
lib/flutter-run-incantation.sh  prints flutter run snippets for clinical_diary
scripts/portal-start-local.sh bind-mounted over portal-final's /app/start.sh;
                              adds --preserve-env so compose env wins over Doppler
compose/docker-compose.yml    service topology (postgres [durable profile],
                              firebase-emulator, otel-lgtm, portal-final)
compose/firebase/firebase.json  emulator config
tests/                        bats suites for the sponsor-path resolver, CLI
                              dispatch, OTel wiring, identity pinning, and the
                              firebase-emulator image + compose invariants
```
