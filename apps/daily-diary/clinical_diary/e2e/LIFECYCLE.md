# EVS participant-lifecycle e2e (`p1-lifecycle.spec.ts`)

A full happy-path **diary <-> portal** lifecycle, driven through the real
clinical_diary Flutter-web UI against the live event-sourced backend
(`portal_server_evs`). This is the automation foundation for **CUR-968**
(portal/lifecycle verification suite), reframed for the EVS stack — the single
backend serves both the portal API and the mobile diary API on one origin;
there is no separate diary-service.

Unlike the offline specs (`fonts`, `link-redeem`) which `scripts/run-e2e.sh`
builds against a dead port, the lifecycle spec needs a **running backend** and
drives the portal-side Study-Coordinator actions at the right moments relative
to the trial-start sync watermark.

## What it exercises

The 12-step lifecycle validated in the CUR-1437 e2e (Pass 1, local-stack,
12/12 green):

1. Bootstrap (portal self-creates its event store on boot).
2. Record 2 epistaxis entries **before linking** — these must NOT sync.
3-4. SystemOperator provisions an Administrator; the Administrator provisions a
   Study Coordinator + CRA (provisioning is **create + assign** — see below).
5. SC issues a linking code (`ACT-PAT-001`); the diary redeems it (`/api/v1/user/link`).
6. SC starts the trial / "Send EQ" (`ACT-PAT-002`) — opens the sync watermark.
8. Record 3 entries **after trial start** — these must sync (`/ingest/batch`).
9-10. Branding/config applied while participating; sync verified in the store.
11. SC disconnects (`ACT-PAT-003`) then marks not-participating (`ACT-PAT-005`).
12. Diary reverts branding/config.

## Topology / ports

| Thing | Where |
| ----- | ----- |
| Portal + mobile diary API (`portal_server_evs`, one origin) | `http://localhost:8080` (`PORTAL`) |
| Postgres event store | `localhost:5432`, container `reference-local-postgres-1`, db `hht_diary` |
| Diary web bundle (served by Playwright) | `http://localhost:8000` (`baseURL` in `playwright.config.ts`) |

The diary bundle is built with `--dart-define=DIARY_API_BASE=$PORTAL` so the
app's diary API calls hit the live backend at `:8080`. Playwright serves the
built `../build/web` on `:8000` and drives it.

## One command (local-stack)

```sh
# 1. Bring up the local-stack EVS portal (reference sponsor) from the repo root:
./deployment/local-stack/local-stack portal

# 2. Provision + build + run + verify, all in one:
apps/daily-diary/clinical_diary/scripts/run-lifecycle-e2e.sh
```

`scripts/run-lifecycle-e2e.sh` provisions the role chain idempotently via the
dev-auth action API, issues a fresh linking code, builds the web bundle against
`:8080`, runs the spec, and asserts the post-trial entries reached the event
store. Pass extra Playwright flags through (e.g. `... run-lifecycle-e2e.sh --headed`).

> Re-runs accumulate state (the participant ends terminal not-participating and
> its code is consumed). For a clean slate:
> `./deployment/local-stack/local-stack down && ./deployment/local-stack/local-stack portal`.

## Manual run (what the script automates)

### Auth model

local-stack runs with `PORTAL_AUTH_MODE` unset => **dev mode**: the bearer is
just the user's email (`Authorization: Bearer <email>`), roles resolved from the
`user_role_scopes` view. The seed has one SystemOperator: `dev@reference.local`.

### Provisioning is create + assign (not create-only)

`ACT-OPS-003` / `ACT-USR-001` only emit `user_created`; the account is not usable
until its **role scopes** are realized via `ACT-USR-007` (assign role/tier) and,
for site-scoped staff, `ACT-USR-008` (assign site). This mirrors the portal UI.

Action envelope: `POST $PORTAL/actions`
`{"actionName","rawInput","idempotencyKey"}` ->
`{"type":"success","result":{...},"emittedEventIds":[...]}`.

```sh
P=http://localhost:8080
act() { curl -fsS -X POST "$P/actions" -H "authorization: Bearer $1" \
  -H 'content-type: application/json' \
  -d "{\"actionName\":\"$2\",\"rawInput\":$3,\"idempotencyKey\":\"$4\"}"; }

# SystemOperator -> Administrator
act dev@reference.local ACT-OPS-003 \
  '{"email":"e2e-admin@reference.local","name":"E2E Admin"}' mkadmin
act dev@reference.local ACT-USR-007 \
  '{"userId":"e2e-admin@reference.local","role":"Administrator","scope":{"class":"tier","value":"staff"}}' admrole

# Administrator -> Study Coordinator @ site-1
act e2e-admin@reference.local ACT-USR-001 \
  '{"email":"e2e-sc@reference.local","name":"E2E SC","activationExpiresAt":"2030-01-01T00:00:00Z","roles":["StudyCoordinator"],"sites":["site-1"]}' mksc
act e2e-admin@reference.local ACT-USR-007 \
  '{"userId":"e2e-sc@reference.local","role":"StudyCoordinator","scope":{"class":"tier","value":"staff"}}' scrole
act e2e-admin@reference.local ACT-USR-008 \
  '{"userId":"e2e-sc@reference.local","role":"StudyCoordinator","site":"site-1"}' scsite

# SC issues a linking code — the code is returned in the result (no view_rows peek needed)
act e2e-sc@reference.local ACT-PAT-001 \
  '{"siteId":"site-1","participantId":"REF-001-001"}' issue-1
# -> {"result":{"participantId":"REF-001-001","linkingCode":"CAGPRLL4AY","expiresAt":"..."}}
```

> Do NOT `POST /link` to peek at a code — redemption is single-use and consumes
> it. `ACT-PAT-001` already returns the code; if you must inspect status,
> read it (don't consume):
> `docker exec reference-local-postgres-1 psql -U postgres -d hht_diary -c \`
> `"select row_key, row_data->>'status' from view_rows where view_name='linking_codes' and row_key='<CODE>';"`

### Build + run

```sh
cd apps/daily-diary/clinical_diary
flutter build web --dart-define=DIARY_API_BASE=http://localhost:8080
cd e2e
npm install   # first time also: npx playwright install chromium
PORTAL=http://localhost:8080 SITE=site-1 PARTICIPANT=REF-001-001 \
  P1_CODE=CAGPRLL4AY SC_BEARER=e2e-sc@reference.local KEY_PREFIX=run1 \
  npx playwright test tests/p1-lifecycle.spec.ts
```

The spec reads these envs (`tests/p1-lifecycle.spec.ts`):

| Env | Meaning | Default |
| --- | ------- | ------- |
| `PORTAL` | portal + diary API base | `http://localhost:8080` |
| `SITE` | site id for the SC actions | `site-1` |
| `PARTICIPANT` | participant id under test | `REF-001-001` |
| `P1_CODE` | linking code to redeem (**required**) | — |
| `SC_BEARER` | SC credential (dev email, or session token) | `sc@reference.local` |
| `KEY_PREFIX` | idempotency-key namespace (use unique per run) | `=PARTICIPANT` |

## Sync-gating verification (the regression that matters)

After the run, the **post-trial** entries must be in the event store and the
**pre-link** entries must not — proving the trial-start watermark opened sync at
the right moment. Synced entries tie to the participant via `initiator->>'user_id'`:

```sh
docker exec reference-local-postgres-1 psql -U postgres -d hht_diary -t -A -c \
  "select count(*) from events
     where aggregate_type='DiaryEntry' and entry_type='epistaxis_event'
       and initiator->>'user_id'='REF-001-001';"
# Fresh DB => exactly 3 (the post-trial entries). A count of 0 is the classic
# trial-start watermark / timezone bug (fixed in #691): started_at serialized
# without a 'Z' => the diary parsed it as local time => sync silently gated off.
```

`run-lifecycle-e2e.sh` performs this check and fails the run if `< 3`.

## Running against a deployed portal (session auth)

For a deployed SESSION-auth portal (e.g. GCP dev), skip the dev-auth
provisioning: mint an SC **session token** out of band and pre-issue a code,
then drive the same spec:

```sh
flutter build web --dart-define=DIARY_API_BASE=https://<portal-service-url>
SC_BEARER=<session-token> P1_CODE=<code> PORTAL=https://<portal-service-url> \
  SITE=<real-site> PARTICIPANT=<real-participant> \
  npx playwright test tests/p1-lifecycle.spec.ts
```

(The CUR-1437 validation drove this as Pass 2: local web diary -> GCP dev portal.)

## Toward CI (the remaining CUR-968 work)

This suite passes manually; it is **not yet wired into CI**. To make it a PR
gate that regenerates the lifecycle evidence automatically:

- A GitHub Actions job that stands up local-stack (Postgres + EVS portal + auth
  emulator), then runs `run-lifecycle-e2e.sh`. The EVS portal self-provisions
  its event-store schema on boot — no DB-schema job needed.
- Upload the Playwright HTML report / traces plus `e2e/test-results/`
  (screenshots, `p1-link.json`, `p1-ingest-posts.json`) as artifacts.
- Tag selective runs (`@smoke` / `@lifecycle` / `@critical`); consider a fast
  smoke on every PR vs. the heavier lifecycle run gated/nightly.

See also: `e2e/README.md` (semantics-identifier conventions + Flutter-web
gotchas), CUR-1307 (CanvasKit/Playwright enabler).
