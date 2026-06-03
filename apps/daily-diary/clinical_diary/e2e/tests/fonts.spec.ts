import { test, expect, Page } from '@playwright/test';

// Selectors target Flutter's web semantics tree (force-enabled at boot in
// main.dart via `SemanticsBinding.instance.ensureSemantics()`). Each Flutter
// `Semantics(identifier:)` surfaces as a `flt-semantics-identifier`
// attribute under the flt-semantics-host.
const byId = (id: string) => `[flt-semantics-identifier="${id}"]`;

// Read the active-font readout. Flutter's web engine renders a leaf
// `Semantics(value:)` node's value as the node's TEXT content (a nested
// <span>), not as an `aria-label` attribute — that aria-label mapping only
// applies to nodes the engine assigns an interactive role/label to. So read
// aria-label first (in case the engine labels it), then fall back to the
// node's trimmed text content, which always carries the value.
const activeFontOf = async (page: Page, id: string): Promise<string | null> => {
  const node = page.locator(byId(id));
  const aria = await node.getAttribute('aria-label');
  if (aria != null && aria.trim() !== '') return aria.trim();
  const text = (await node.textContent())?.trim();
  return text != null && text !== '' ? text : null;
};

// The three font families exposed by FeatureFlagService.availableFonts
// (defaults — all three — are kept because the sponsor-config fetch is
// forced offline). `family` is FontOption.fontFamily (the dropdown VALUE
// and the identifier suffix); `display` is FontOption.displayName (the
// visible label, used as a text fallback if the overlay node merges away).
const FONTS: { family: string; display: string }[] = [
  { family: 'Roboto', display: 'Roboto (Default)' },
  { family: 'OpenDyslexic', display: 'OpenDyslexic' },
  { family: 'AtkinsonHyperlegible', display: 'Atkinson Hyperlegible' },
];

// Wait for CanvasKit to finish booting and the semantics DOM to exist.
// `flt-semantics-host` is intentionally rendered hidden (off-screen,
// opacity 0), so wait for it ATTACHED rather than visible.
async function waitForApp(page: Page) {
  await page.waitForSelector('flt-semantics-host', {
    timeout: 60_000,
    state: 'attached',
  });
}

// Dump the current set of identified semantics nodes — used when a selector
// misses, to understand the real DOM (esp. the dropdown overlay).
async function dumpIds(page: Page, label: string) {
  const ids = await page.evaluate(() =>
    Array.from(document.querySelectorAll('[flt-semantics-identifier]')).map(
      (e) => (e as HTMLElement).outerHTML,
    ),
  );
  console.log(`\n=== [${label}] ${ids.length} flt-semantics-identifier nodes ===`);
  for (const html of ids) console.log(html);
  console.log(`=== end [${label}] ===\n`);
}

// Select one font: open the dropdown, click its option (by identifier, with
// a visible-text fallback), then assert the active-font readout updates.
async function selectFont(page: Page, family: string, display: string) {
  // Open the dropdown. The collapsed DropdownButtonFormField shows the
  // currently-selected item, so its identified node carries the
  // font-option-<current> identifier; clicking the font-selector container
  // (pointer-events:none) is unreliable. Click the visible selected label to
  // open the Material dropdown overlay instead.
  await page.locator(byId('font-selector')).getByText(/.+/).first().click();

  // Once open, every option mounts in the dropdown overlay. The target
  // option may appear MORE THAN ONCE (the collapsed selected node persists),
  // so pick the one that is actually in the open menu by clicking the LAST
  // matching identified node (overlay nodes mount after the collapsed one).
  const optionById = page.locator(byId(`font-option-${family}`));
  let clicked = false;
  try {
    await optionById.last().waitFor({ state: 'attached', timeout: 4_000 });
    await optionById.last().click({ timeout: 4_000 });
    clicked = true;
  } catch {
    await dumpIds(page, `dropdown-open-${family}`);
  }
  if (!clicked) {
    // Fallback: click the visible label text inside the overlay.
    await page.getByText(display, { exact: false }).last().click();
  }

  // Assert the machine-readable readout reports the newly-active family.
  await expect
    .poll(async () => activeFontOf(page, 'active-font'), { timeout: 15_000 })
    .toBe(family);
}

test('exercise all font options via the Flutter semantics tree', async ({
  page,
}) => {
  // Offline determinism: abort the sponsor-config fetch so the app keeps the
  // default availableFonts (all three). The dart-define dead port already
  // makes this fail; this is belt-and-suspenders.
  await page.route(/sponsor\/config/, (r) => r.abort());

  await page.goto('/');
  await waitForApp(page);

  // HomeScreen mounts with no auth/login wall. Wait for the identified user
  // menu button, then open it.
  await page.waitForSelector(byId('user-menu-button'), { timeout: 60_000 });
  await page.locator(byId('user-menu-button')).click();

  // The popup menu renders into an overlay. Click the accessibility item.
  const accessibility = page.locator(byId('menu-accessibility'));
  try {
    await accessibility.first().waitFor({ state: 'attached', timeout: 8_000 });
    await accessibility.first().click();
  } catch {
    await dumpIds(page, 'user-menu-open');
    // Fallback: visible label of the accessibility item.
    await page
      .getByText('Accessibility & Preferences', { exact: false })
      .first()
      .click();
  }

  // Land on Settings — wait for the font selector to mount.
  await page.waitForSelector(byId('font-selector'), { timeout: 30_000 });

  // Sanity: dump the settings-screen identifiers once for the record.
  await dumpIds(page, 'settings-loaded');

  for (const { family, display } of FONTS) {
    await selectFont(page, family, display);
    await page.screenshot({
      path: `test-results/font-${family}.png`,
      fullPage: true,
    });
  }
});
