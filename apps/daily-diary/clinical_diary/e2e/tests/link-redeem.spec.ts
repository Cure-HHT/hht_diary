import { test, expect } from '@playwright/test';
import { byId, waitForFlutter, dumpIds, clickMenuItem, blockRequests } from '../helpers';

// The PARTICIPANT (diary) side of the link loop, in a real browser against the
// live Postgres-backed portal_server_evs:
//   - issue a linking code (HTTP setup, as a coordinator would)
//   - open the diary, navigate Home -> user menu -> Link to Clinical Trial
//   - enter the two code halves + privacy consent, submit
//   - assert the success overlay (proving /link succeeded end-to-end via the UI)
//
// Requires the live server on :8084 (dev auth) with a fresh notConnected
// DEV-001-002 @ site-1 (the run-redeem-e2e.sh harness resets + reseeds).
const SERVER = 'http://localhost:8084';
const PARTICIPANT = 'DEV-001-002';

test('participant redeems a linking code in the diary UI', async ({ page, request }) => {
  // --- setup: a coordinator issues a code (read-free dispatched action) -------
  const issueRes = await request.post(`${SERVER}/actions`, {
    headers: { authorization: 'Bearer sc-1', 'content-type': 'application/json' },
    data: {
      actionName: 'ACT-PAT-001',
      rawInput: { siteId: 'site-1', participantId: PARTICIPANT },
      idempotencyKey: 'redeem-e2e',
    },
  });
  expect(issueRes.ok()).toBeTruthy();
  const issueBody = await issueRes.json();
  // DispatchSuccess carries `result`; an idempotency replay carries `cachedResult`.
  const code: string = (issueBody.result ?? issueBody.cachedResult).linkingCode;
  expect(code).toMatch(/^[A-Z]{2}[A-Z0-9]{8}$/);
  const code1 = code.slice(0, 5);
  const code2 = code.slice(5);

  // The diary's sponsor-config fetch isn't served by the EVS portal; block it so
  // the app boots to Home with defaults. The /link call is NOT blocked.
  await blockRequests(page, /sponsor\/config/);

  // --- drive the diary UI -----------------------------------------------------
  await page.goto('/');
  await waitForFlutter(page);

  // Home -> user menu -> "Link to Clinical Trial".
  await page.locator(byId('user-menu-button')).first().click();
  await clickMenuItem(page, { id: 'menu-enroll', text: 'Link to Clinical Trial' });
  await page.locator(byId('enroll-code1')).first().waitFor({ state: 'attached', timeout: 30_000 });
  await dumpIds(page, 'enroll-screen');

  // Fill the two code halves. Flutter-web text fields surface an <input> under
  // the semantics node; fill it directly (keyboard.type drops leading chars).
  await fillFlutterField(page, 'enroll-code1', code1);
  await fillFlutterField(page, 'enroll-code2', code2);

  // Privacy consent (the screen's single checkbox).
  await page.locator('flt-semantics-host [role="checkbox"]').first().click();

  // Submit.
  await page.getByRole('button', { name: /Link to Clinical Trial/i }).first().click();

  // Success overlay appears once /link returns the participant JWT + contract.
  await page.locator(byId('enroll-success')).first().waitFor({ state: 'attached', timeout: 30_000 });

  await page.screenshot({ path: 'test-results/diary-redeem.png', fullPage: true });
});

async function fillFlutterField(page, id: string, value: string): Promise<void> {
  // A Flutter-web text field under a Semantics(identifier) wrapper renders TWO
  // <input>s: a DISABLED placeholder on the wrapper node + the real editable
  // input in a nested flt-semantics node. Fill the enabled one.
  const input = page.locator(`${byId(id)} input:not([disabled])`).first();
  await input.waitFor({ state: 'attached', timeout: 15_000 });
  await input.fill(value);
}
