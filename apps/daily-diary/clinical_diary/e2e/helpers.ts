/**
 * Flutter-web semantics helpers for Playwright e2e tests.
 *
 * CanvasKit renders to a single <canvas> with no conventional DOM, so all
 * automation targets the Flutter accessibility/semantics tree. Each Flutter
 * `Semantics(identifier: 'kebab-name', ...)` annotation surfaces as a
 * `flt-semantics-identifier` attribute on a node under `flt-semantics-host`.
 *
 * Force-enabling the semantics tree on web is done once at app boot via
 * `SemanticsBinding.instance.ensureSemantics()` in main.dart (CUR-1307).
 * Tests must never assume the tree is enabled by default.
 */

import { Page } from '@playwright/test';

// ---------------------------------------------------------------------------
// Selector factory
// ---------------------------------------------------------------------------

/**
 * Return a CSS attribute selector for a Flutter semantics identifier.
 *
 * Usage:  page.locator(byId('font-selector'))
 *
 * Every `Semantics(identifier: 'foo', ...)` widget surfaces as
 * `<flt-semantics flt-semantics-identifier="foo" ...>` under the
 * semantics host.
 */
export const byId = (id: string): string =>
  `[flt-semantics-identifier="${id}"]`;

// ---------------------------------------------------------------------------
// Boot / readiness
// ---------------------------------------------------------------------------

/**
 * Wait for the Flutter CanvasKit semantics host to mount.
 *
 * GOTCHA — wait ATTACHED, not VISIBLE: Flutter intentionally renders
 * `flt-semantics-host` hidden (off-screen, opacity 0) so screen-reader users
 * get the accessibility tree without a second visible overlay. Waiting for
 * `state: 'visible'` therefore times out even when Flutter is fully booted.
 */
export async function waitForFlutter(page: Page): Promise<void> {
  await page.waitForSelector('flt-semantics-host', {
    timeout: 60_000,
    state: 'attached',
  });
}

// ---------------------------------------------------------------------------
// Debugging aid
// ---------------------------------------------------------------------------

/**
 * Console-dump the outerHTML of every node that carries a
 * `flt-semantics-identifier` attribute.
 *
 * Useful when a `byId(...)` selector misses: call this to see what
 * identifiers are actually present in the semantics DOM at that moment
 * (e.g., before/after opening a dropdown overlay).
 *
 * @param label  Short label shown in the console header so you can tell
 *               dumps apart when several appear in a single test run.
 */
export async function dumpIds(page: Page, label: string): Promise<void> {
  const ids = await page.evaluate(() =>
    Array.from(document.querySelectorAll('[flt-semantics-identifier]')).map(
      (e) => (e as HTMLElement).outerHTML,
    ),
  );
  console.log(`\n=== [${label}] ${ids.length} flt-semantics-identifier nodes ===`);
  for (const html of ids) console.log(html);
  console.log(`=== end [${label}] ===\n`);
}

// ---------------------------------------------------------------------------
// Reading semantics values
// ---------------------------------------------------------------------------

/**
 * Read the semantic value exposed by the node identified by `id`.
 *
 * Returns `null` if the node is absent or carries no meaningful text.
 *
 * GOTCHA — which attribute carries the value depends on the node's role:
 * - Role-bearing nodes (buttons, text inputs, etc.) expose their
 *   `Semantics(value:)` as `aria-label`.
 * - Leaf / non-interactive nodes expose the value as the element's
 *   TEXT CONTENT (inside a nested `<span>`), NOT as `aria-label`.
 *
 * This helper tries `aria-label` first so it works for both cases; it
 * falls back to `textContent` so you do not need to know which rendering
 * the engine chose at any given Flutter/CanvasKit version.
 */
export async function readSemanticValue(
  page: Page,
  id: string,
): Promise<string | null> {
  const node = page.locator(byId(id));
  const aria = await node.getAttribute('aria-label');
  if (aria != null && aria.trim() !== '') return aria.trim();
  const text = (await node.textContent())?.trim();
  return text != null && text !== '' ? text : null;
}

// ---------------------------------------------------------------------------
// Navigation helpers
// ---------------------------------------------------------------------------

/**
 * Click a menu item that renders in a Flutter popup / overlay.
 *
 * Flutter popup menus mount their items in a separate overlay layer, so
 * the item may appear more than once in the semantics tree (the closed
 * control plus the open overlay copy). We always click the FIRST attached
 * occurrence; if the identifier-based click fails, fall back to the
 * visible text label.
 *
 * @param id    `flt-semantics-identifier` of the menu item (optional if
 *              you only have a text fallback, but prefer an identifier).
 * @param text  Visible label — used as a fallback when the identifier is
 *              absent or the node fails to receive the click.
 */
export async function clickMenuItem(
  page: Page,
  { id, text }: { id?: string; text: string },
): Promise<void> {
  let clicked = false;
  if (id) {
    const item = page.locator(byId(id));
    try {
      await item.first().waitFor({ state: 'attached', timeout: 8_000 });
      await item.first().click();
      clicked = true;
    } catch {
      await dumpIds(page, `menu-item-miss-${id}`);
    }
  }
  if (!clicked) {
    await page.getByText(text, { exact: false }).first().click();
  }
}

// ---------------------------------------------------------------------------
// Dropdown helper
// ---------------------------------------------------------------------------

/**
 * Select an option from a Flutter Material `DropdownButtonFormField`.
 *
 * GOTCHA — duplicate identifiers across collapsed + overlay nodes:
 * When the dropdown is collapsed, the currently-selected item keeps its
 * `font-option-<value>` identifier. When the overlay opens, a second
 * copy of the same node mounts. Clicking `.first()` would hit the
 * already-collapsed node (pointer-events off) and miss; `.last()` hits
 * the live overlay copy that actually receives pointer events.
 *
 * GOTCHA — open via visible text, not the container:
 * The `selectorId` container typically has `pointer-events: none`.
 * Opening the dropdown by clicking the visible selected label (the text
 * currently showing inside the collapsed button) is reliable;
 * clicking the container itself is not.
 *
 * @param selectorId  Identifier on the collapsed `DropdownButtonFormField`
 *                    container — used to scope the "open" click.
 * @param optionId    Identifier on the target option node
 *                    (`font-option-<value>` style).
 * @param optionText  Visible text of the target option — text fallback when
 *                    the option identifier is absent or misses.
 */
export async function selectFromFlutterDropdown(
  page: Page,
  {
    selectorId,
    optionId,
    optionText,
  }: { selectorId: string; optionId: string; optionText: string },
): Promise<void> {
  // Open the dropdown by clicking the visible selected label inside the
  // collapsed control (the container itself is pointer-events: none).
  await page.locator(byId(selectorId)).getByText(/.+/).first().click();

  // Click the target option in the overlay (.last() = overlay copy).
  const optionLocator = page.locator(byId(optionId));
  let clicked = false;
  try {
    await optionLocator.last().waitFor({ state: 'attached', timeout: 4_000 });
    await optionLocator.last().click({ timeout: 4_000 });
    clicked = true;
  } catch {
    await dumpIds(page, `dropdown-open-${optionId}`);
  }
  if (!clicked) {
    await page.getByText(optionText, { exact: false }).last().click();
  }
}

// ---------------------------------------------------------------------------
// Network helpers
// ---------------------------------------------------------------------------

/**
 * Abort all requests matching `pattern` to force offline / deterministic
 * behavior in tests.
 *
 * Example: block the sponsor-config fetch so the app keeps its default
 * feature-flag set rather than overriding it from the server.
 *
 *   await blockRequests(page, /sponsor\/config/);
 */
export async function blockRequests(
  page: Page,
  pattern: RegExp,
): Promise<void> {
  await page.route(pattern, (r) => r.abort());
}
