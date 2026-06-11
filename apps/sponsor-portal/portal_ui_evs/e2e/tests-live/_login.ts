import { Page } from '@playwright/test';
import { byId, waitForFlutter } from '../helpers';

/// Session-auth login against the live local stack.
///
/// Flutter-web text-field gotchas baked in: fill() sets the DOM value but
/// Flutter's input bridge can miss the synthetic event, and keys typed
/// before the editing session attaches are swallowed — so click, settle,
/// type real keystrokes, verify, retry.
export async function fillField(
  page: Page,
  id: string,
  value: string,
): Promise<void> {
  const input = page.locator(`${byId(id)} input:not([disabled])`).first();
  await input.waitFor({ state: 'attached', timeout: 15_000 });
  for (let attempt = 0; attempt < 3; attempt++) {
    await input.click();
    await page.waitForTimeout(400);
    await page.keyboard.press('ControlOrMeta+a');
    await page.keyboard.press('Delete');
    await input.pressSequentially(value, { delay: 30 });
    if ((await input.inputValue()) === value) return;
  }
  throw new Error(`could not type into ${id}`);
}

export async function login(
  page: Page,
  email: string,
  password: string,
): Promise<void> {
  await page.goto('/');
  await waitForFlutter(page);
  await fillField(page, 'login-email', email);
  await fillField(page, 'login-password', password);
  // The submit button enables only once Flutter's controllers hold both
  // values (flt-semantics node with role=button + aria-disabled).
  const submit = page
    .locator(`${byId('login-submit')}[role="button"]:not([aria-disabled="true"])`)
    .first();
  await submit.waitFor({ state: 'attached', timeout: 15_000 });
  await submit.click();
}
