import { test, expect } from '@playwright/test';
import { byId, waitForFlutter } from '../helpers';
import { recordEpistaxis } from '../diary-actions';

// Smoke: can we drive ONE finalized epistaxis entry through the real diary UI
// (text-driven, no identifiers) against the live local-stack portal?
test('smoke: record one epistaxis entry via UI', async ({ page }) => {
  page.on('console', (m) => console.log(`[browser:${m.type()}] ${m.text()}`));
  page.on('requestfailed', (r) => console.log(`[reqfail] ${r.method()} ${r.url()} ${r.failure()?.errorText}`));
  await page.goto('/');
  await waitForFlutter(page);
  await page.waitForSelector(byId('user-menu-button'), { state: 'attached', timeout: 60_000 });
  await page.screenshot({ path: 'test-results/smoke-home.png', fullPage: true });

  await recordEpistaxis(page, { startBackSteps: 2, intensity: 'Spotting' });

  await page.screenshot({ path: 'test-results/smoke-after-record.png', fullPage: true });
  // Got back to Home without a save-failure snackbar.
  await expect(page.getByText('Failed to save')).toHaveCount(0);
});
