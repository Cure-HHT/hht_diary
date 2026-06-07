import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import { byId, waitForFlutter } from '../helpers';
import { recordEpistaxis, redeemLinkingCode } from '../diary-actions';

// Full happy-path lifecycle for participant P1, driven through the REAL diary
// web UI, with the portal-side lifecycle actions dispatched via the request
// fixture (as the Study Coordinator) at the correct moments relative to the
// trial-start watermark. Server-side assertions (event-store contents) are done
// from bash psql after this run; this spec drives + captures.
const PORTAL = 'http://localhost:8080';
const SITE = 'site-1';
const P1 = process.env.PARTICIPANT || 'REF-001-001';
const CODE = process.env.P1_CODE || '';
const K = process.env.KEY_PREFIX || P1; // unique idempotency-key namespace

test('P1 full participant lifecycle (record -> link -> trial -> sync -> not-participating)', async ({ page, request }) => {
  expect(CODE, 'P1_CODE env must be set').not.toEqual('');
  const ingestPosts: string[] = [];
  page.on('console', (m) => console.log(`[b:${m.type()}] ${m.text()}`));
  page.on('response', async (resp) => {
    const u = resp.url();
    if (u.includes('/api/v1/user/link') && resp.request().method() === 'POST') {
      try {
        const j = await resp.json();
        fs.writeFileSync('test-results/p1-link.json', JSON.stringify(j, null, 2));
        console.log('[CAPTURED /link] keys=' + Object.keys(j).join(','));
      } catch (e) { console.log('[link capture failed] ' + e); }
    }
    if (u.includes('/ingest/batch')) {
      ingestPosts.push(`${resp.status()} ${u}`);
      console.log(`[INGEST] ${resp.status()} ${u}`);
    }
  });

  const sc = async (actionName: string, rawInput: object, key: string) => {
    const r = await request.post(`${PORTAL}/actions`, {
      headers: { authorization: 'Bearer sc@reference.local', 'content-type': 'application/json' },
      data: { actionName, rawInput, idempotencyKey: key },
    });
    const txt = await r.text();
    console.log(`[ACTION ${actionName}] ${r.status()} ${txt}`);
    return { status: r.status(), txt };
  };

  await page.goto('/');
  await waitForFlutter(page);
  await page.waitForSelector(byId('user-menu-button'), { state: 'attached', timeout: 60_000 });

  // ---- STEP 2: record 2 entries BEFORE linking (must NOT sync) ----
  console.log('=== STEP 2: pre-link entries ===');
  await recordEpistaxis(page, { startBackSteps: 6, intensity: 'Dripping' });
  await recordEpistaxis(page, { startBackSteps: 10, intensity: 'Spotting' });
  await page.screenshot({ path: 'test-results/p1-step2-prelink.png', fullPage: true });

  // ---- STEP 5: redeem the linking code in the diary UI ----
  console.log('=== STEP 5: redeem linking code ===');
  await redeemLinkingCode(page, CODE);
  await page.screenshot({ path: 'test-results/p1-step5-linked.png', fullPage: true });

  // ---- STEP 6: SC starts the trial ("Send EQ") -> opens sync watermark ----
  console.log('=== STEP 6: start trial ===');
  await sc('ACT-PAT-002', { siteId: SITE, participantId: P1 }, `start-${K}`);
  // Force a boot reconcile so the trial-start watermark is adopted deterministically.
  await page.reload();
  await waitForFlutter(page);
  await page.waitForSelector(byId('user-menu-button'), { state: 'attached', timeout: 60_000 });
  await page.waitForTimeout(10000);

  // ---- STEP 8: record 3 entries AFTER trial start (must sync) ----
  console.log('=== STEP 8: post-trial entries (sync) ===');
  await recordEpistaxis(page, { startBackSteps: 2, intensity: 'Pouring' });
  await recordEpistaxis(page, { startBackSteps: 3, intensity: 'Steady stream' });
  await recordEpistaxis(page, { startBackSteps: 4, intensity: 'Dripping quickly' });
  // Fire a drain trigger: installDiarySyncTriggers drains on connectivity
  // none->connected and on app-resume. Simulate both from the browser so the
  // outbound FIFO drains now rather than waiting for the 15-min periodic.
  for (let i = 0; i < 3; i++) {
    await page.evaluate(() => {
      window.dispatchEvent(new Event('offline'));
    });
    await page.waitForTimeout(400);
    await page.evaluate(() => {
      window.dispatchEvent(new Event('online'));
      window.dispatchEvent(new Event('focus'));
      document.dispatchEvent(new Event('visibilitychange'));
    });
    await page.waitForTimeout(4000);
  }
  await page.waitForTimeout(4000); // allow drains to complete
  await page.screenshot({ path: 'test-results/p1-step8-synced.png', fullPage: true });
  console.log('[ingestPosts] ' + JSON.stringify(ingestPosts));

  // ---- STEP 11: SC disconnects then marks not-participating (study complete) ----
  console.log('=== STEP 11: disconnect + mark not-participating ===');
  await sc('ACT-PAT-003', { siteId: SITE, participantId: P1, reason: 'study period complete' }, `disc-${K}`);
  await sc('ACT-PAT-005', { siteId: SITE, participantId: P1, reason: 'completed study period' }, `mnp-${K}`);
  // Force a boot reconcile so the diary observes not-participating + unlocks (STEP 12).
  await page.reload();
  await waitForFlutter(page);
  await page.waitForSelector(byId('user-menu-button'), { state: 'attached', timeout: 60_000 });
  await page.waitForTimeout(4000);
  await page.screenshot({ path: 'test-results/p1-step12-reverted.png', fullPage: true });

  fs.writeFileSync('test-results/p1-ingest-posts.json', JSON.stringify(ingestPosts, null, 2));
});
