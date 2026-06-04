import { test, expect } from '@playwright/test';
import {
  blockRequests,
  byId,
  clickMenuItem,
  dumpIds,
  readSemanticValue,
  selectFromFlutterDropdown,
  waitForFlutter,
} from '../helpers';

// The three font families exposed by FeatureFlagService.availableFonts
// (defaults — all three — are kept because the sponsor-config fetch is
// forced offline). `family` is FontOption.fontFamily (the dropdown value
// and identifier suffix); `display` is FontOption.displayName (the visible
// label, used as a text fallback if the overlay node merges away).
const FONTS: { family: string; display: string }[] = [
  { family: 'Roboto', display: 'Roboto (Default)' },
  { family: 'OpenDyslexic', display: 'OpenDyslexic' },
  { family: 'AtkinsonHyperlegible', display: 'Atkinson Hyperlegible' },
];

test('exercise all font options via the Flutter semantics tree', async ({
  page,
}) => {
  // Offline determinism: abort the sponsor-config fetch so the app keeps the
  // default availableFonts (all three). The dart-define dead port already
  // makes this fail; this is belt-and-suspenders.
  await blockRequests(page, /sponsor\/config/);

  await page.goto('/');
  await waitForFlutter(page);

  // HomeScreen mounts with no auth/login wall. Wait for the identified user
  // menu button, then open it.
  await page.waitForSelector(byId('user-menu-button'), { timeout: 60_000 });
  await page.locator(byId('user-menu-button')).click();

  // The popup menu renders into an overlay. Click the accessibility item.
  await clickMenuItem(page, {
    id: 'menu-accessibility',
    text: 'Accessibility & Preferences',
  });

  // Land on Settings — wait for the font selector to mount.
  await page.waitForSelector(byId('font-selector'), { timeout: 30_000 });

  // Sanity: dump the settings-screen identifiers once for the record.
  await dumpIds(page, 'settings-loaded');

  for (const { family, display } of FONTS) {
    await selectFromFlutterDropdown(page, {
      selectorId: 'font-selector',
      optionId: `font-option-${family}`,
      optionText: display,
    });

    // Assert the machine-readable readout reports the newly-active family.
    await expect
      .poll(async () => readSemanticValue(page, 'active-font'), {
        timeout: 15_000,
      })
      .toBe(family);

    await page.screenshot({
      path: `test-results/font-${family}.png`,
      fullPage: true,
    });
  }
});
