import { test, expect } from '@playwright/test';
import { byId, waitForFlutter, readSemanticValue } from '../helpers';

// The coordinator browser flow against the live Postgres-backed server:
// connect as the seeded StudyCoordinator (sc-1), open Participants, issue a
// linking code for a site-1 participant, and assert the SERVER-generated code
// surfaces in the UI (the C2 ActivationCodeDisplay).
//
// STATUS: the connect -> nav -> reactive participant-list legs drive reliably
// (proving Playwright + the flt-semantics technique work against the real
// portal + live Postgres). The last leg — expanding the participant's
// ExpansionTile to reach the issue button — is FLAKY: the WS-backed reactive
// list re-renders and the tile's semantics node churns, so the expand toggle
// (mouse or keyboard) is non-deterministic under automation. A robust version
// needs either a non-churning affordance for the lifecycle actions or a UI
// that doesn't gate them behind an ExpansionTile. Tracked as a follow-up.
//
// Requires the live portal_server_evs on :8084 with the dev seed
// (DevSeedRaveClient participants DEV-001-00x @ site-1) — see e2e/README.
//
// Run: portal_server_evs on :8084 (Postgres), then:
//   cd apps/sponsor-portal/portal_ui_evs
//   flutter build web --release --dart-define=PORTAL_SERVER_URL=http://localhost:8084
//   cd e2e && npm install && npx playwright test
const PARTICIPANT = 'DEV-001-002';

/** Activate a node by semantics id via keyboard (robust to position churn in
 *  the reactive CanvasKit tree), tolerating it not (yet) existing. */
async function tryActivate(page, id: string): Promise<boolean> {
  const n = page.locator(byId(id)).first();
  try {
    await n.focus({ timeout: 2500 });
    await page.keyboard.press('Enter');
    return true;
  } catch {
    return false;
  }
}

test('coordinator issues a linking code; server code appears in the portal UI', async ({
  page,
}) => {
  await page.goto('/');
  await waitForFlutter(page);

  // Connect as sc-1 (StudyCoordinator @ site-1) via the dev quick-connect.
  await page.locator(byId('connect-as-sc-1')).first().click();

  // Navigate to the Participants destination on the nav rail.
  const nav = page.locator(byId('nav-participants')).first();
  await nav.waitFor({ state: 'attached', timeout: 30_000 });
  await nav.click();

  // The participants list re-renders reactively (WS snapshots) and the
  // ExpansionTile's title identifier disappears once expanded, so a single
  // click is unreliable. Re-click the tile until the issue button surfaces.
  const issueBtn = page.locator(byId(`issue-${PARTICIPANT}`)).first();
  await page
    .locator(byId(`participant-${PARTICIPANT}`))
    .first()
    .waitFor({ state: 'attached', timeout: 30_000 });
  await expect
    .poll(
      async () => {
        if (await issueBtn.count()) return true;
        await tryActivate(page, `participant-${PARTICIPANT}`);
        await page.waitForTimeout(800);
        return (await issueBtn.count()) > 0;
      },
      { timeout: 40_000, intervals: [500] },
    )
    .toBe(true);

  // Issue the code; the builder swaps the button for the ActivationCodeDisplay,
  // wrapped in Semantics(identifier: 'linking-code-<pid>', value: <code>).
  const codeNode = page.locator(byId(`linking-code-${PARTICIPANT}`)).first();
  await expect
    .poll(
      async () => {
        if (await codeNode.count()) return true;
        await tryActivate(page, `issue-${PARTICIPANT}`);
        await page.waitForTimeout(800);
        return (await codeNode.count()) > 0;
      },
      { timeout: 40_000, intervals: [500] },
    )
    .toBe(true);

  const code = await readSemanticValue(page, `linking-code-${PARTICIPANT}`);
  console.log('issued linking code =', code);

  // Server prefix + 8 non-ambiguous chars (e.g. CAYYFYXCVQ).
  expect(code).toMatch(/^[A-Z]{2}[A-Z0-9]{8}$/);

  await page.screenshot({
    path: 'test-results/portal-issue.png',
    fullPage: true,
  });
});
