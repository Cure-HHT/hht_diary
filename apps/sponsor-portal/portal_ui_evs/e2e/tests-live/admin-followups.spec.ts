import { test, expect } from '@playwright/test';
import { byId } from '../helpers';
import { login } from './_login';

// Live verification of the CUR-1483 follow-ups:
// 1. Header: sponsor logo + Settings link render in the new layout.
// 2. Users page: the SysOp-ONLY seeded account (sysop@reference.local) is
//    invisible to an Administrator but visible to a SystemOperator viewer.
//
// Requires the local stack: PORTAL_AUTH_MODE=session ./deployment/local-stack/local-stack portal

test('admin: new header chrome renders; SysOp-only row is hidden', async ({
  page,
}) => {
  await login(page, 'admin@reference.local', 'example');

  // --- header: Settings link + sponsor logo --------------------------------
  await page
    .locator(byId('appbar-settings'))
    .first()
    .waitFor({ state: 'attached', timeout: 30_000 });
  await page
    .getByRole('img', { name: 'Sponsor logo' })
    .first()
    .waitFor({ state: 'attached', timeout: 30_000 });

  // --- Users tab: table renders, SysOp-only account absent ------------------
  await page.locator(byId('tab-user-accounts')).first().click();
  await page
    .locator(byId('user-actions-admin@reference.local'))
    .first()
    .waitFor({ state: 'attached', timeout: 30_000 });
  await expect(page.getByText('sysop@reference.local')).toHaveCount(0);
  // Sanity: regular accounts still listed.
  await expect(page.getByText('cra@reference.local').first()).toBeAttached();

  await page.screenshot({
    path: 'test-results/admin-followups-header.png',
    fullPage: false,
  });
});

test('sysop: SysOp-only row IS visible to an operator viewer', async ({
  page,
}) => {
  await login(page, 'sysop@reference.local', 'example');

  await page.locator(byId('tab-user-accounts')).first().click();
  await page
    .getByText('sysop@reference.local')
    .first()
    .waitFor({ state: 'attached', timeout: 30_000 });
});
