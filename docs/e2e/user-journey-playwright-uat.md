# How-To: USER_JOURNEY UAT validated by Playwright

Author a `USER_JOURNEY` in `spec/`, drive it with a Playwright script, publish the
results so elspais ingests them, see them in the elspais viewer, and read a
traceability report scoped to UAT (journey) coverage.

## The model (constant across all phases)

```text
Playwright test(s)  --(verify)-->  journey         (a journey's verdict is
                                      |             all-or-nothing: pass iff
                                      |             everything verifying it passed)
                                   journey  --Validates-->  requirement / assertion
```

- A **journey** cites requirements/assertions as a whole, via its `Validates:`
  line. That creates the `VALIDATES` edge that feeds the `uat_coverage` dimension.
- A journey has a single **all-or-nothing verdict**: pass iff every test (or
  step) verifying it passed. That verdict feeds the `uat_verified` dimension along
  the `Validates:` edges.
- Coverage is reported with elspais's standard **tiers** — a categorical bucket
  per requirement per dimension, not a number:

  ```text
  uat_coverage  full-direct  <- every assertion is NAMED by some journey's Validates:
                full-indirect<- every assertion covered, but only via whole-REQ Validates:
                partial      <- only some assertions named
  uat_verified  full-direct  <- ...and each validating journey's verdict is pass
                failing      <- ...but at least one validating journey's verdict is fail
                partial      <- only some assertions verified
  ```

  There is **no averaging** across multiple validating journeys: a target is
  verified iff every journey validating it passes; one failure puts it in the
  `failing` tier.

What changes between phases is only **how a test links to a journey and how the
verdict is sourced** — not the tier model above.

| Phase | Test references | Journey verdict comes from | Results ingestion |
| ----- | --------------- | -------------------------- | ----------------- |
| 1 (now) | nothing in elspais (convention only) | a `uat-results.csv` row you produce | adapter writes the CSV |
| 2 | `Verifies: <JOURNEY>` | rollup of the journey's verifying tests | normal test-result ingestion |
| 3 | `Verifies: <JOURNEY>/step-N` | rollup of the journey's step results | normal test-result ingestion |

---

## Common setup (all phases)

### Journey file location

- Journey files live under `spec/user-journeys/`. `[scanning.journey]` already
  scans `directories = ["spec"]` for `*.md`, so they are picked up automatically.
- **No config change needed.** A file is classified `JOURNEY` by content (its
  `# JNY-...` blocks), so the requirement scanner ignores it on its own.
  **Do NOT add `user-journeys` to `[scanning.spec].skip_dirs`** — journey files
  are discovered *through* the spec scan, so skipping the directory there removes
  them from the graph entirely (verified: doing so drops the journey count to 0).

### Journey file format

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

- **ID:** `JNY-<PREFIX>-NN`, stable.
- **`Validates:`** drives `uat_coverage`. Name assertions for `full-direct`
  (`DIARY-PRD-portal-auth-A+B`); naming the whole requirement gives `full-indirect`.
  A bare `## Requirements` bullet list creates no edges — use `Validates:`.
- **Steps** are plain numbered prose. (They only become individually addressable
  in Phase 3.)

After authoring (the CLI rebuilds the graph automatically per command):

```bash
elspais fix   # regenerates INDEX.md so journeys appear, plus _generated artifacts
```

---

## Phase 1 — How it works now

The journey verdict is supplied to elspais as a row in a results CSV. elspais
knows nothing about which test produced it; the test-to-journey link is a
convention inside your Playwright harness.

### How-to (test-writer)

1. Author the journey with a `Validates:` line (above).
2. Write a Playwright spec, titling the test with the journey ID and one
   `test.step()` per journey step:

   ```ts
   // e2e/oq-login-01.spec.ts
   import { test, expect } from '@playwright/test';

   test('JNY-OQ-Login-01: Coordinator signs in', async ({ page }) => {
     await test.step('step-1: open login page', async () => {
       await page.goto('/login');
       await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
     });
     await test.step('step-2: submit credentials', async () => {
       await page.getByLabel('Email').fill(process.env.UAT_USER!);
       await page.getByLabel('Password').fill(process.env.UAT_PASS!);
       await page.getByRole('button', { name: 'Sign in' }).click();
     });
     await test.step('step-3: lands on dashboard', async () => {
       await expect(page).toHaveURL(/\/dashboard/);
     });
   });
   ```

3. Run an adapter that collapses each test to a single journey verdict
   (`pass` iff every step passed) and writes the results file:

   ```bash
   playwright test --reporter=json > pw-results.json
   node tools/uat/pw-to-uat-csv.mjs pw-results.json > uat-results.csv
   ```

   `uat-results.csv` lives at the **repo root** (the default for
   `[scanning.journey].results_file`) with one row per journey:

   ```csv
   journey_id,status
   JNY-OQ-Login-01,pass
   JNY-OQ-Deploy-01,fail
   ```

   (`status`: `pass`/`passed`, `fail`/`failed`, `skip`/`skipped`.)

4. Re-run `elspais checks --tests` (it rebuilds the graph and re-reads the CSV),
   then view (§Viewing) or report (§Report).

### elspais feature requirement — *available today, no new work*

**JOURNEY-UAT-ingest: Journey-level UAT coverage and result ingestion**

- A. elspais SHALL parse `USER_JOURNEY` blocks under `[scanning.journey]` and
  create a `VALIDATES` edge to every requirement/assertion on each journey's
  `Validates:` line.
- B. elspais SHALL read `[scanning.journey].results_file` (`uat-results.csv`,
  columns `journey_id,status`) and attach a pass/fail/skip RESULT to each journey.
- C. elspais SHALL compute the `uat_coverage` and `uat_verified` tiers on each
  `Validates:` target from those edges and results, using the same tier model as
  code/test coverage.

These behaviors exist in elspais today; Phase 1 needs no elspais changes — only
the journey files and the local `pw-to-uat-csv` adapter (not part of elspais).

---

## Phase 2 — A test can `Verifies:` a journey

A Playwright test names the journey it exercises with a `Verifies:` annotation.
elspais derives the journey verdict from those tests' results, so the manual
`uat-results.csv` and the adapter go away.

### How-to (test-writer)

1. Author the journey with `Validates:` (unchanged).
2. Write one (or more) Playwright tests for the whole journey and annotate the
   journey ID:

   ```ts
   // Verifies: JNY-OQ-Login-01
   test('JNY-OQ-Login-01: Coordinator signs in', async ({ page }) => {
     // ... steps ...
   });
   ```

   A journey may have several verifying tests; it passes iff **all** of them pass.
3. Emit Playwright results as JUnit and let elspais ingest them as test RESULTs
   (no journey CSV):

   ```toml
   # .elspais.toml
   [[scanning.test.targets]]
   name     = "e2e-uat"   # required: unique label for this target
   command  = "playwright test --reporter=junit"
   reporter = "junit"
   results  = "e2e/results/junit.xml"
   ```

4. `elspais checks --tests --run-tests` runs the target, ingests results, and
   resolves the journey verdict -> `uat_verified` on the `Validates:` targets.

The test-to-journey link now lives **in elspais**, so the traceability graph shows
which tests verify which journey.

### elspais feature requirement

**JOURNEY-UAT-verify-journey: Test-to-journey verification**

- A. elspais SHALL accept a `USER_JOURNEY` id as a `Verifies:` target in code/test
  files, creating a `VERIFIES` edge from the test to the journey.
- B. elspais SHALL derive each journey's verdict from its verifying tests'
  RESULTs, all-or-nothing: verified-pass iff every verifying test passed; fail if
  any verifying test failed; unverified if no results exist.
- C. That journey verdict SHALL feed `uat_verified` along the journey's
  `Validates:` edges, replacing any need for a `uat-results.csv` row.
- D. elspais SHALL surface the test->journey->requirement chain in `trace` and the
  viewer.

(Ingestion of the verifying tests' results reuses the existing
`[[scanning.test.targets]]` JUnit pipeline; the new work is accepting a journey id
as a `Verifies:` target and the all-or-nothing rollup in B.)

---

## Phase 3 — A test or test step can `Verifies:` a journey step

Steps become addressable nodes. A test (or a per-step test) names the exact step
it verifies, so a failing journey points at the specific step that broke.

### How-to (test-writer)

1. Author the journey with a clean numbered `## Steps` list (step numbers are now
   the contract).
2. Verify each step. Because Playwright's JUnit output reports per *test*, model
   each step as its own test (or use a reporter that emits per-`test.step`
   results):

   ```ts
   // Verifies: JNY-OQ-Login-01/step-1
   test('JNY-OQ-Login-01/step-1: open login page', async ({ page }) => { ... });

   // Verifies: JNY-OQ-Login-01/step-2
   test('JNY-OQ-Login-01/step-2: submit credentials', async ({ page }) => { ... });

   // Verifies: JNY-OQ-Login-01/step-3
   test('JNY-OQ-Login-01/step-3: lands on dashboard', async ({ page }) => { ... });
   ```

3. Ingest via the same JUnit target as Phase 2.
4. elspais rolls step results up: a step passes iff it has >=1 passing and 0
   failing verifying tests; the journey passes iff every step passes; the journey
   verdict feeds `uat_verified` exactly as in Phase 2.

### elspais feature requirement

**JOURNEY-UAT-verify-step: Step-level verification**

- A. elspais SHALL parse a journey's `## Steps` numbered list into addressable step
  nodes with ids of the form `JNY-<...>/step-<N>`.
- B. elspais SHALL accept a journey-step id as a `Verifies:` target, creating a
  `VERIFIES` edge from the test to the step node.
- C. elspais SHALL compute each step's pass/fail from its verifying tests (step
  passes iff >=1 passing and 0 failing), and derive the journey verdict as
  all-or-nothing across its steps.
- D. The journey verdict SHALL feed `uat_verified` as in
  *JOURNEY-UAT-verify-journey*; a failing journey SHALL identify the failing
  step(s) in `trace` and the viewer.

---

## Viewing results (all phases)

```bash
elspais viewer            # live server, default http://localhost:5001 (rebuilds the graph on launch)
```

- Journeys appear as `USER_JOURNEY` nodes linked to the requirements they
  `Validates`.
- A passing journey lights its validated requirements as uat-verified; a failing
  journey shows the **Failure** indicator (the `failing` tier).
- `uat_coverage` / `uat_verified` are tracked separately from the code
  `tested`/`verified` dimensions.

---

## Traceability report: USER_JOURNEY coverage only (all phases)

*Which requirements are validated by journeys, and do those journeys pass?* —
the `uat_coverage` (validated) and `uat_verified` (passing) dimensions.

### Available today

```bash
elspais checks --tests --format json -o checks.json   # uat.coverage / uat.results
elspais trace --format json -o trace.json             # filter to edge kind == VALIDATES
```

### Desired ergonomics

A journey-scoped one-liner would emit a requirements x journeys matrix with the
`uat_coverage`/`uat_verified` tiers and nothing about code/unit-test coverage:

```bash
elspais trace --dimension uat --format markdown -o uat-traceability.md
```

**elspais feature requirement — JOURNEY-UAT-report: UAT-scoped trace**

- A. `elspais trace` SHALL accept a `--dimension uat` flag.
- B. With it, `trace` SHALL include only requirements with an incoming `VALIDATES`
  edge, list the validating journey(s) and their verdicts, and show the
  `uat_coverage`/`uat_verified` tier per requirement.
- C. The report SHALL exclude code `implemented`/`tested`/`verified` columns.

This applies to all three phases (the report reads the same `uat_*` tiers
regardless of how the verdict was sourced).
