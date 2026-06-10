import { test, expect, Page } from '@playwright/test';
import { byId, waitForFlutter } from '../helpers';

// Live verification of server-side audit-log paging (CUR-1425): log in as
// the seeded admin under session auth, open Audit Logs, confirm the
// pagination header reports the server's true total, then jump to the LAST
// page — the oldest events in the store — which only works if the screen
// pages through the full event log instead of a fetched snapshot.
//
// Requires the local stack: PORTAL_AUTH_MODE=session ./deployment/local-stack/local-stack portal

const ADMIN_EMAIL = 'admin@reference.local';
const ADMIN_PASSWORD = 'example';
const PAGE_SIZE = 8;

async function fillField(page: Page, id: string, value: string): Promise<void> {
  // Flutter-web text fields render a disabled placeholder <input> on the
  // wrapper plus the real editable input nested; target the enabled one.
  // fill() sets the DOM value but Flutter's input bridge can miss the
  // synthetic event (the DOM then LOOKS right while Flutter's controller is
  // empty), so always type with real key events.
  const input = page.locator(`${byId(id)} input:not([disabled])`).first();
  await input.waitFor({ state: 'attached', timeout: 15_000 });
  for (let attempt = 0; attempt < 3; attempt++) {
    await input.click();
    // Flutter needs a beat to attach its editing session after focus; keys
    // typed before that are swallowed.
    await page.waitForTimeout(400);
    await page.keyboard.press('ControlOrMeta+a');
    await page.keyboard.press('Delete');
    await input.pressSequentially(value, { delay: 30 });
    if ((await input.inputValue()) === value) return;
  }
  throw new Error(`could not type into ${id}`);
}

test('audit log pages through the full event log to the oldest entry', async ({
  page,
}) => {
  await page.goto('/');
  await waitForFlutter(page);

  // --- session-auth login ---------------------------------------------------
  await fillField(page, 'login-email', ADMIN_EMAIL);
  await fillField(page, 'login-password', ADMIN_PASSWORD);
  // The submit button enables only once Flutter's controllers hold both
  // values — the real signal that the typed text reached Flutter state.
  // (Flutter semantics "buttons" are flt-semantics nodes with role=button +
  // aria-disabled, not <button> tags.)
  const submit = page
    .locator(`${byId('login-submit')}[role="button"]:not([aria-disabled="true"])`)
    .first();
  await submit.waitFor({ state: 'attached', timeout: 15_000 });
  await submit.click();

  // --- open the Audit Logs tab ----------------------------------------------
  const auditTab = page.getByRole('button', { name: /Audit Log/ }).first();
  await auditTab.waitFor({ state: 'attached', timeout: 30_000 });
  await auditTab.click();

  // --- page 1 reports the server's true total -------------------------------
  // Anchor on the audit screen's subtitle first — the Users screen has its
  // own "Viewing ..." header that would match too early.
  await page
    .getByText('View system activity and changes.')
    .first()
    .waitFor({ state: 'attached', timeout: 30_000 });
  // The audit log's total is 200+ on the seeded stack (3+ digits), unlike
  // the 7-user Users table.
  const header = page.getByText(/Viewing 1-\d+ of \d{3,}/).first();
  await header.waitFor({ state: 'attached', timeout: 30_000 });
  const headerText = (await header.textContent())!;
  const total = Number(headerText.match(/of (\d+)/)![1]);
  console.log('pagination header:', headerText, '-> total', total);
  expect(total).toBeGreaterThan(200); // the seeded stack has 200+ events

  // --- jump to the last page = the OLDEST entries ---------------------------
  const lastPage = Math.ceil(total / PAGE_SIZE);
  await page.getByRole('button', { name: String(lastPage), exact: true })
    .first()
    .click();

  const lastStart = (lastPage - 1) * PAGE_SIZE + 1;
  const lastHeader = page
    .getByText(new RegExp(`Viewing ${lastStart}-${total} of ${total}`))
    .first();
  await lastHeader.waitFor({ state: 'attached', timeout: 30_000 });
  console.log('last page header:', await lastHeader.textContent());

  await page.screenshot({
    path: 'test-results/audit-last-page.png',
    fullPage: true,
  });
});
