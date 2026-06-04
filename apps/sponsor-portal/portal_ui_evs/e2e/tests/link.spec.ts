import { test, expect } from '@playwright/test';
import { byId, waitForFlutter, readSemanticValue } from '../helpers';

// The coordinator browser flow against the live Postgres-backed server:
// connect as the seeded StudyCoordinator (sc-1), open Participants, issue a
// linking code for a site-1 participant, and assert the SERVER-generated code
// surfaces in the UI (the C2 ActivationCodeDisplay, driven by the reactive
// ActionBuilder). The lifecycle actions render inline (no expand), so the row
// is deterministic to drive.
//
// Requires the live portal_server_evs on :8084 with the dev seed
// (DevSeedRaveClient participants DEV-001-00x @ site-1).
//
// Run: portal_server_evs on :8084 (Postgres), then:
//   cd apps/sponsor-portal/portal_ui_evs
//   flutter build web --release --dart-define=PORTAL_SERVER_URL=http://localhost:8084
//   cd e2e && npm install && npx playwright test
const PARTICIPANT = 'DEV-001-002';

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

  // The issue button renders inline on the participant's card (notConnected).
  const issueBtn = page.locator(byId(`issue-${PARTICIPANT}`)).first();
  await issueBtn.waitFor({ state: 'attached', timeout: 30_000 });
  await issueBtn.click();

  // Issuance flips the participant to "pending" — the list re-renders
  // reactively and the Show Code button appears (proving the dispatch +
  // projection + reactive UI refresh all completed end-to-end in the browser).
  const showCodeBtn = page.locator(byId(`showcode-${PARTICIPANT}`)).first();
  await showCodeBtn.waitFor({ state: 'attached', timeout: 30_000 });
  await showCodeBtn.click();

  // The Show Code dialog reads the persistent participant_record.linking_code
  // and exposes it on the semantics tree (value -> aria-label on web).
  const codeNode = page.locator(byId(`linking-code-${PARTICIPANT}`)).first();
  await codeNode.waitFor({ state: 'attached', timeout: 30_000 });
  const code = await readSemanticValue(page, `linking-code-${PARTICIPANT}`);
  console.log('issued linking code =', code);

  // Server prefix + 8 non-ambiguous chars (e.g. CAYYFYXCVQ).
  expect(code).toMatch(/^[A-Z]{2}[A-Z0-9]{8}$/);

  await page.screenshot({
    path: 'test-results/portal-issue.png',
    fullPage: true,
  });
});
