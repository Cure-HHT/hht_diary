# How-To: USER_JOURNEY UAT validated by Playwright

Author a `USER_JOURNEY` in `spec/`, drive it with a Playwright script, publish the
results so elspais ingests them, see them in the elspais viewer, and read a
traceability report scoped to UAT (journey) coverage.

Everything described here is **available as of elspais 0.118.31** — journey steps
as addressable nodes, tests that verify a journey or a specific step, the
all-or-nothing journey rollup, and `elspais trace --dimension uat`. (Earlier
revisions of this doc tracked these as future gaps; they have shipped.)

## The model

```text
Playwright test  --Verifies-->  journey step  --(STRUCTURES)-->  journey
   (one per step)                                                  |
                                                                   | Validates
                                                                   v
                                                       requirement / assertion
```

- A **journey** cites requirements/assertions via its `Validates:` line — that
  creates the `VALIDATES` edge feeding the `uat_coverage` dimension.
- A journey's `## Steps` are parsed into **addressable STEP nodes** (`JNY-.../step-N`),
  linked to the journey by a `STRUCTURES` edge. A test verifies a step (or the
  whole journey) with a `Verifies:` annotation.
- A step is **verified** iff at least one passing test result targets it and none
  failing. The **journey verdict is all-or-nothing**: pass iff every step is
  verified-passing; any failing step makes the verdict fail; an unverified step
  leaves the journey `partial`. The verdict feeds the `uat_verified` dimension
  along the `Validates:` edges.
- Coverage is reported with elspais's standard **tiers** — a categorical bucket
  per requirement per dimension, not a number:

  ```text
  uat_coverage  full-direct   <- every assertion is NAMED by some journey's Validates:
                full-indirect <- every assertion covered, but only via whole-REQ Validates:
                partial       <- only some assertions named
  uat_verified  full-direct   <- ...and each validating journey's verdict is pass
                failing       <- ...but at least one validating journey's verdict is fail
                partial       <- only some assertions verified
  ```

  There is **no averaging** across multiple validating journeys: a target is
  verified iff every journey validating it passes; one failure puts it in the
  `failing` tier.

---

## 1. Author the journey

### Location

- Journey files live under `spec/user-journeys/`. `[scanning.journey]` scans
  `directories = ["spec"]` for `*.md`, so they are picked up automatically.
- **No config change needed.** A file is classified `JOURNEY` by content (its
  `# JNY-...` blocks), so the requirement scanner ignores it on its own.
  **Do NOT add `user-journeys` to `[scanning.spec].skip_dirs`** — journey files
  are discovered *through* the spec scan, so skipping the directory there removes
  them from the graph entirely (verified: doing so drops the journey count to 0).

### Format

```text
# JNY-OQ-Login-01: Coordinator signs in to the portal

**Actor**: Study Coordinator
**Goal**: Authenticate and reach the participant dashboard

Validates: DIARY-PRD-portal-auth-A+B

## Steps

1. Coordinator opens the portal login page
2. Coordinator submits valid credentials
3. System establishes a session and routes to the dashboard

## Expected Outcome

The coordinator is authenticated and lands on the dashboard.

*End* *Coordinator signs in to the portal*
```

- **ID:** `JNY-<PREFIX>-NN`, stable. Each numbered step becomes the node
  `JNY-<PREFIX>-NN/step-N` (read-only; the journey renders verbatim).
- **`Validates:`** drives `uat_coverage`. Name assertions for `full-direct`
  (`DIARY-PRD-portal-auth-A+B`); naming the whole requirement gives `full-indirect`.
  A bare `## Requirements` bullet list creates no edges — use `Validates:`.
- Claim only assertions the journey's steps actually demonstrate. Negative,
  limit, single-use, and configuration assertions that a happy-path run never
  exercises belong in dedicated negative-path journeys, not here.

After authoring (the CLI rebuilds the graph automatically per command):

```bash
elspais fix   # regenerates INDEX.md so journeys appear, plus _generated artifacts
```

---

## 2. Wire Playwright tests to the journey

Pick one of three supported linkings (finest first). All three feed the same
`uat_verified` tiers; they differ only in granularity and whether tests are wired
into elspais.

### Option A — per-step verification (recommended)

A test names the exact step it verifies, so a failing journey points at the
specific step that broke. Because Playwright's JUnit output reports per *test*
(not per `test.step()`), model each step as its own test:

```ts
// e2e/oq-login-01.spec.ts
import { test, expect } from '@playwright/test';

// Verifies: JNY-OQ-Login-01/step-1
test('JNY-OQ-Login-01/step-1: open login page', async ({ page }) => {
  await page.goto('/login');
  await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
});

// Verifies: JNY-OQ-Login-01/step-2
test('JNY-OQ-Login-01/step-2: submit credentials', async ({ page }) => {
  await page.getByLabel('Email').fill(process.env.UAT_USER!);
  await page.getByLabel('Password').fill(process.env.UAT_PASS!);
  await page.getByRole('button', { name: 'Sign in' }).click();
});

// Verifies: JNY-OQ-Login-01/step-3
test('JNY-OQ-Login-01/step-3: lands on dashboard', async ({ page }) => {
  await expect(page).toHaveURL(/\/dashboard/);
});
```

A step counts as passing iff at least one verifying test passes and none fails;
the journey passes iff every step passes.

### Option B — whole-journey verification

When step-level granularity isn't needed, one test can verify the journey as a
whole. It passes iff all tests targeting that journey pass:

```ts
// Verifies: JNY-OQ-Login-01
test('JNY-OQ-Login-01: Coordinator signs in', async ({ page }) => {
  // ... full flow ...
});
```

### Option C — journey-level results CSV (no test wiring in elspais)

The simplest path: don't reference journeys from tests at all; instead hand
elspais a per-journey verdict in `uat-results.csv` at the repo root (the default
for `[scanning.journey].results_file`):

```csv
journey_id,status
JNY-OQ-Login-01,pass
JNY-OQ-Deploy-01,fail
```

(`status`: `pass`/`passed`, `fail`/`failed`, `skip`/`skipped`.) Produce it from
Playwright's JSON reporter with a small adapter that ANDs each test's steps into
one journey verdict:

```bash
playwright test --reporter=json > pw-results.json
node tools/uat/pw-to-uat-csv.mjs pw-results.json > uat-results.csv
```

With this option the test-to-journey link lives only in your harness, not in the
elspais graph (so `trace` won't show which test verified which step).

---

## 3. Ingest the test results (Options A and B)

Tests that carry `Verifies: JNY-...` reach elspais through the normal
test-results pipeline. Add a target so elspais runs the suite and ingests its
JUnit output:

```toml
# .elspais.toml
[[scanning.test.targets]]
name     = "e2e-uat"   # required: unique label for this target
command  = "playwright test --reporter=junit"
reporter = "junit"
results  = "e2e/results/junit.xml"
```

```bash
elspais checks --tests --run-tests   # runs the target, ingests results,
                                      # resolves step -> journey -> uat_verified
```

For Option C there is no target — `elspais checks --tests` reads `uat-results.csv`
directly (the `uat.results` check).

---

## 4. View results

```bash
elspais viewer   # live server, default http://localhost:5001 (rebuilds on launch)
```

- Journeys appear as `USER_JOURNEY` nodes linked to the requirements they
  `Validates`. The journey card renders a **Steps (N)** section with a
  per-step pass/fail/untested badge and the verifying tests that target each step.
- A failing journey shows the **Failure** indicator (the `failing` tier).
- `uat_coverage` / `uat_verified` are tracked separately from the code
  `tested`/`verified` dimensions.

---

## 5. UAT-only traceability report

*Which requirements are validated by journeys, and do those journeys pass?* — a
single command answers it, scoped to the `uat_coverage`/`uat_verified` dimensions
and excluding code columns:

```bash
elspais trace --dimension uat --format markdown -o uat-traceability.md
```

It lists every requirement with an incoming `VALIDATES` edge, its
`uat_coverage` and `uat_verified` tiers (e.g. `5.3/7 (76%)`), and the validating
journeys with their verdicts (`JNY-SET-01:unverified` until results exist).
`--format csv` / `json` are also available.

Related queries:

```bash
elspais checks --tests   # uat.coverage / uat.results summary
elspais unvalidated      # requirements with no UAT (journey) coverage
```
