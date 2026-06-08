import { test, expect } from '@playwright/test';
import { byId, waitForFlutter } from '../helpers';
import { redeemLinkingCode } from '../diary-actions';

// Verifies: DIARY-DEV-pluggable-push-transport/C+D — a portal-originated
// lifecycle change reaches the diary in REAL TIME over the local-push WebSocket
// (PUSH_MODE=local), with the periodic /state poll stretched so the update can
// ONLY have been push-delivered.
//
// Isolation: the diary's foreground reconcile fires on app-resume, connectivity
// transitions, the periodic poll, AND push. This spec fires NONE of the first
// three after linking — no reload(), no focus/online events — and the runner
// builds with --dart-define=DIARY_SYNC_PERIODIC_SECONDS=<huge> so the periodic
// poll cannot fire during the test. A "Disconnected from Study" banner that
// appears in-place after the portal action is therefore proof the WS push
// delivered it (contrast p1-lifecycle, which deliberately fires those triggers
// to exercise the POLL backup path).
//
// Preconditions (set by scripts/run-push-e2e.sh): web bundle built with
// env=local (LocalSocketPushReceiver active) + a huge poll interval; portal up
// with PUSH_MODE=local; a fresh single-use P1_CODE for PARTICIPANT @ SITE.
const PORTAL = process.env.PORTAL || 'http://localhost:8080';
const SITE = process.env.SITE || 'site-1';
const P1 = process.env.PARTICIPANT || '';
const CODE = process.env.P1_CODE || '';
const K = process.env.KEY_PREFIX || P1;
const SC_BEARER = process.env.SC_BEARER || 'sc@reference.local';

const DISCONNECT_BANNER = 'Disconnected from Study';

test('push transport: portal disconnect reaches the diary over WS with no poll', async ({
  page,
  request,
}) => {
  expect(CODE, 'P1_CODE env must be set').not.toEqual('');
  page.on('console', (m) => console.log(`[b:${m.type()}] ${m.text()}`));

  const sc = async (actionName: string, rawInput: object, key: string) => {
    const r = await request.post(`${PORTAL}/actions`, {
      headers: {
        authorization: `Bearer ${SC_BEARER}`,
        'content-type': 'application/json',
      },
      data: { actionName, rawInput, idempotencyKey: key },
    });
    const txt = await r.text();
    console.log(`[ACTION ${actionName}] ${r.status()} ${txt}`);
    expect(r.ok(), `${actionName} -> ${r.status()} ${txt}`).toBeTruthy();
    return txt;
  };

  await page.goto('/');
  await waitForFlutter(page);
  await page.waitForSelector(byId('user-menu-button'), {
    state: 'attached',
    timeout: 60_000,
  });

  // Link the participant.
  await redeemLinkingCode(page, CODE);

  // --- PRE-disconnect setup (NOT the delivery under test) ---
  // The enrollment screen returns to its entry point (not Home) on web, so a
  // single reload lands on Home and (re)establishes the push WS + registers the
  // device routing token. One connectivity/focus cycle then drains that token to
  // the portal projection so the dispatch reactor can find it. All of this runs
  // BEFORE the disconnect and reads /state=connected, so it cannot be what
  // delivers the (later) disconnect.
  await page.reload();
  await waitForFlutter(page);
  await page.waitForSelector(byId('user-menu-button'), {
    state: 'attached',
    timeout: 30_000,
  });
  await page.evaluate(() => window.dispatchEvent(new Event('offline')));
  await page.waitForTimeout(400);
  await page.evaluate(() => {
    window.dispatchEvent(new Event('online'));
    window.dispatchEvent(new Event('focus'));
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await page.waitForTimeout(8000); // token drains to portal + WS connects

  // Still connected (the setup read /state=connected, did not disconnect).
  await expect(
    page.getByText(DISCONNECT_BANNER, { exact: false }),
  ).toHaveCount(0);

  // Fire the portal disconnect. CRUCIAL: do not reload, focus, or toggle
  // connectivity — with the periodic poll stretched, the local-push WS is the
  // only live reconcile trigger.
  console.log('=== firing portal disconnect (push-only delivery) ===');
  await sc(
    'ACT-PAT-003',
    { siteId: SITE, participantId: P1, reason: 'push-transport e2e' },
    `pushdisc-${K}`,
  );

  // The banner appears in-place — push-delivered, since no poll/trigger fired.
  await expect(
    page.getByText(DISCONNECT_BANNER, { exact: false }).first(),
  ).toBeVisible({ timeout: 20_000 });
  console.log('PASS: disconnected banner appeared via WS push (no poll, no reload)');
  await page.screenshot({
    path: 'test-results/p2-push-disconnected.png',
    fullPage: true,
  });
});
