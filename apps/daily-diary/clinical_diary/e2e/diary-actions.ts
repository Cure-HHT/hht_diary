/**
 * Higher-level diary UI actions for the EVS lifecycle validation, layered on the
 * text/semantics primitives in helpers.ts. The epistaxis recording flow has no
 * Semantics(identifier) annotations, so these drive it by visible label
 * (l10n en): "Record Nosebleed", the time-dial nudge buttons (-15/-5/-1/+1/+5/+15),
 * "Set Start Time" / "Set End Time", and intensity labels (Spotting, ...).
 */
import { Page } from '@playwright/test';
import { byId, clickMenuItem } from './helpers';

/** Click a Flutter-web control by its visible text (semantics name). */
async function clickText(page: Page, text: string, opts: { exact?: boolean; nth?: number } = {}) {
  const loc = page.getByText(text, { exact: opts.exact ?? true });
  const target = opts.nth != null ? loc.nth(opts.nth) : loc.first();
  await target.waitFor({ state: 'attached', timeout: 20_000 });
  await target.click({ timeout: 10_000 });
}

async function clickButton(page: Page, name: RegExp) {
  const b = page.getByRole('button', { name }).first();
  await b.waitFor({ state: 'attached', timeout: 20_000 });
  await b.click({ timeout: 10_000 });
}

/**
 * Record ONE finalized epistaxis entry through the real UI.
 *
 * startBackSteps: number of "-15" min nudges applied to the start time (spaces
 * entries apart to avoid overlap). intensity: visible intensity label.
 * The reference sponsor has no review screen, so confirming the end time
 * auto-saves and returns to Home.
 */
export async function recordEpistaxis(
  page: Page,
  { startBackSteps = 2, intensity = 'Spotting' }: { startBackSteps?: number; intensity?: string } = {},
): Promise<void> {
  await clickText(page, 'Record Nosebleed');
  // Start-time dial: nudge start backward so the (later) end time stays in the past.
  for (let i = 0; i < startBackSteps; i++) await clickText(page, '-15');
  await clickButton(page, /Set Start Time/i);
  // Intensity step.
  await clickText(page, intensity);
  // End-time dial: nudge +5 so end > start, then confirm (auto-saves).
  await clickText(page, '+5');
  await clickButton(page, /Set End Time/i);
  // Back on Home (the recording screen popped).
  await page.waitForSelector(byId('user-menu-button'), { state: 'attached', timeout: 30_000 });
}

/** Redeem a linking code in the diary UI (Home -> menu -> Link to Clinical Trial). */
export async function redeemLinkingCode(page: Page, code: string): Promise<void> {
  const code1 = code.slice(0, 5);
  const code2 = code.slice(5);
  await page.locator(byId('user-menu-button')).first().click();
  await clickMenuItem(page, { id: 'menu-enroll', text: 'Link to Clinical Trial' });
  await page.locator(byId('enroll-code1')).first().waitFor({ state: 'attached', timeout: 30_000 });
  await page.locator(`${byId('enroll-code1')} input:not([disabled])`).first().fill(code1);
  await page.locator(`${byId('enroll-code2')} input:not([disabled])`).first().fill(code2);
  await page.locator('flt-semantics-host [role="checkbox"]').first().click();
  await clickButton(page, /Link to Clinical Trial/i);
  await page.locator(byId('enroll-success')).first().waitFor({ state: 'attached', timeout: 30_000 });
}
