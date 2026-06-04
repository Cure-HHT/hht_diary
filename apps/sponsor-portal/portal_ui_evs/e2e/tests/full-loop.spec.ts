import { test, expect, Page } from '@playwright/test';
import { byId, waitForFlutter, readSemanticValue, clickMenuItem } from '../helpers';

// The WHOLE link loop, UI to UI, in one real browser against the live
// Postgres-backed portal_server_evs:
//   PORTAL (coordinator)  : connect as sc-1 -> Participants -> Issue -> read code
//   DIARY  (participant)  : Home -> menu -> enter the code + consent -> submit
//   assert the diary success overlay (the code minted in the portal UI is the
//   one redeemed in the diary UI, end-to-end through both apps).
//
// Both web bundles must be served (portal :8010, diary :8000) and the server
// must be freshly seeded — orchestrated by scripts/run-full-loop-e2e.sh.
const PORTAL = 'http://localhost:8010';
const DIARY = 'http://localhost:8000';
const PARTICIPANT = 'DEV-001-002';

test('full link loop: portal issues a code, the diary redeems it', async ({
  browser,
}) => {
  // --- PORTAL: coordinator issues a code and reads it back from the UI -------
  const portal = await browser.newPage({ baseURL: PORTAL });
  await portal.goto('/');
  await waitForFlutter(portal);
  await portal.locator(byId('connect-as-sc-1')).first().click();
  const nav = portal.locator(byId('nav-participants')).first();
  await nav.waitFor({ state: 'attached', timeout: 30_000 });
  await nav.click();

  const issueBtn = portal.locator(byId(`issue-${PARTICIPANT}`)).first();
  await issueBtn.waitFor({ state: 'attached', timeout: 30_000 });
  await issueBtn.click();
  // Issuance flips the participant to pending; Show Code surfaces the persisted code.
  const showCode = portal.locator(byId(`showcode-${PARTICIPANT}`)).first();
  await showCode.waitFor({ state: 'attached', timeout: 30_000 });
  await showCode.click();
  const codeNode = portal.locator(byId(`linking-code-${PARTICIPANT}`)).first();
  await codeNode.waitFor({ state: 'attached', timeout: 30_000 });
  const code = (await readSemanticValue(portal, `linking-code-${PARTICIPANT}`))!;
  expect(code).toMatch(/^[A-Z]{2}[A-Z0-9]{8}$/);
  console.log('portal issued code =', code);

  // --- DIARY: participant redeems that exact code in the diary UI ------------
  const diary = await browser.newPage({ baseURL: DIARY });
  await diary.route(/sponsor\/config/, (r) => r.abort()); // boot Home with defaults
  await diary.goto('/');
  await waitForFlutter(diary);
  await diary.locator(byId('user-menu-button')).first().click();
  await clickMenuItem(diary, { id: 'menu-enroll', text: 'Link to Clinical Trial' });
  await diary
    .locator(byId('enroll-code1'))
    .first()
    .waitFor({ state: 'attached', timeout: 30_000 });

  await fillField(diary, 'enroll-code1', code.slice(0, 5));
  await fillField(diary, 'enroll-code2', code.slice(5));
  await diary.locator('flt-semantics-host [role="checkbox"]').first().click();
  await diary.getByRole('button', { name: /Link to Clinical Trial/i }).first().click();

  await diary
    .locator(byId('enroll-success'))
    .first()
    .waitFor({ state: 'attached', timeout: 30_000 });
  console.log('diary redeemed code =', code);

  await diary.screenshot({ path: 'test-results/full-loop-diary.png', fullPage: true });
});

async function fillField(page: Page, id: string, value: string): Promise<void> {
  // Flutter-web text fields render a disabled placeholder <input> on the
  // wrapper plus the real editable input nested; fill the enabled one.
  const input = page.locator(`${byId(id)} input:not([disabled])`).first();
  await input.waitFor({ state: 'attached', timeout: 15_000 });
  await input.fill(value);
}
