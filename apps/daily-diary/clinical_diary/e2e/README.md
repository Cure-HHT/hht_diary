# clinical_diary Playwright e2e foundation

A Playwright end-to-end harness that drives the **clinical_diary Flutter-web
build** via the accessibility/semantics tree.

Flutter's CanvasKit renderer produces a single `<canvas>` with no
conventional DOM, so tests cannot target CSS classes or element IDs the way a
React test would. Instead, every widget you want to automate gets a
`Semantics(identifier: 'kebab-name', ...)` annotation, which the Flutter
engine emits as a `flt-semantics-identifier` attribute on a node under the
hidden `flt-semantics-host` element.

## How to run

```sh
# From the clinical_diary root:
scripts/run-e2e.sh
```

That script: runs `flutter pub get`, builds the web bundle with
`DIARY_API_BASE` pointed at a dead port (offline determinism), starts a local
static server, installs npm deps, then runs Playwright against Chromium.

**First-time browser install:**

```sh
cd e2e
npm install
npx playwright install chromium
```

Pass extra Playwright flags after the script name (e.g.
`scripts/run-e2e.sh --headed` or `scripts/run-e2e.sh tests/fonts.spec.ts`).

**Offline vs. lifecycle:** `scripts/run-e2e.sh` builds the bundle *offline*
(sponsor-config forced to a dead port) for the self-contained specs (`fonts`,
`link-redeem`, `_smoke-record`). The full **participant-lifecycle** spec
(`tests/p1-lifecycle.spec.ts`) instead drives the diary against a **running**
EVS backend (`portal_server_evs`) and the portal-side Study-Coordinator
actions. It has its own one-command runner and instructions:
**[LIFECYCLE.md](LIFECYCLE.md)** (`scripts/run-lifecycle-e2e.sh`).

## How to add a new test

1. **Annotate target widgets** in `lib/` with
   `Semantics(identifier: 'kebab-name', ...)`.
   See the gotchas section below for the common pitfalls.

2. **Add `tests/<feature>.spec.ts`** importing helpers from `../helpers`:

   ```ts
   import { test, expect } from '@playwright/test';
   import { byId, waitForFlutter, readSemanticValue, /* ... */ } from '../helpers';

   test('my feature works', async ({ page }) => {
     await page.goto('/');
     await waitForFlutter(page);
     // ... navigate, interact, assert
   });
   ```

3. **Run:**

   ```sh
   scripts/run-e2e.sh tests/<feature>.spec.ts
   ```

## App-side seam already provided

`main.dart` calls `SemanticsBinding.instance.ensureSemantics()` on `kIsWeb`
at boot, so the semantics tree is always active for web builds — you do not
need to enable it per-test.

**Navigation hooks available for all tests:**

- `user-menu-button` — the icon button in the HomeScreen app bar that opens
  the user menu popup.
- `menu-accessibility` — the "Accessibility & Preferences" item inside that
  popup, which navigates to the Settings screen.

Typical preamble to reach Settings from any test:

```ts
await page.waitForSelector(byId('user-menu-button'), { timeout: 60_000 });
await page.locator(byId('user-menu-button')).click();
await clickMenuItem(page, { id: 'menu-accessibility', text: 'Accessibility & Preferences' });
await page.waitForSelector(byId('font-selector'), { timeout: 30_000 });
```

## Identifier naming convention

- **kebab-case**, **feature-prefixed**: `font-selector`, `font-option-<value>`,
  `user-menu-button`.
- The prefix groups related identifiers (`font-*`) and avoids collisions
  across features.
- The suffix after the prefix is the machine-readable value when the
  identifier varies by data (e.g. `font-option-Roboto`).

## Flutter-web semantics annotation gotchas

These are the rules that matter most; violating them produces identifiers that
are either invisible to Playwright or unreachable with a click.

**Buttons need `container: true, explicitChildNodes: true`.**
Without these flags the engine merges the identifier up into the parent or
drops it entirely. Wrap a `Semantics(identifier: ..., container: true,
explicitChildNodes: true, child: ...)` around interactive widgets.

**Readout / value nodes must have non-zero area.**
Flutter prunes zero-size semantics nodes from the tree. A `SizedBox(width: 1,
height: 1)` wrapper with `container: true` keeps the node alive so Playwright
can find it, even if the node is visually invisible.

**`Semantics(value:)` surfaces differently depending on node role.**
On role-bearing (interactive) nodes the value appears as `aria-label`.
On plain leaf nodes it appears as the element's text content (a nested
`<span>`), not as `aria-label`. Use `readSemanticValue(page, id)` from
`helpers.ts` — it tries both in the right order.

**Dropdown/menu overlays can duplicate an identifier.**
When a `DropdownButtonFormField` is open, the collapsed control and the open
overlay both carry the same `font-option-<x>` identifier. Use `.last()` on
the locator to reach the live overlay copy (overlay nodes mount after the
collapsed node). See `selectFromFlutterDropdown` in `helpers.ts`.

**Wait for `flt-semantics-host` ATTACHED, not visible.**
The semantics host is intentionally rendered off-screen / `opacity: 0`.
`waitForFlutter` uses `state: 'attached'` for this reason.

**Prefer `fill()` on inner `<input>` over `keyboard.type()`** for text
entry into Flutter web text fields — `keyboard.type()` can race with
CanvasKit's input handling on slow CI machines.

---

These annotations mirror the Downstream-trial findings in the substrate's
design doc:
`event_sourcing/docs/superpowers/specs/2026-06-02-playwright-ui-automation-design.md`.
