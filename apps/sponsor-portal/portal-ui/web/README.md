# Portal Web Static Assets

Static files copied into the Flutter web build output and served by nginx.

## Files

- `index.html` — page bootstrap. References `flutter_bootstrap.js` (Flutter 3.16+); does NOT call `loadServiceWorker`. Together with the build flag `--pwa-strategy=none` (set in the sibling repo's `portal-final.Dockerfile`), this is the "no SW for the portal" posture per `REQ-p01044-M` and `REQ-p00009`.
- `manifest.json` — descriptive PWA manifest. We do not register as a PWA.
- `flutter_service_worker.js` — self-unregistering Service Worker kill-switch. See below.

## `flutter_service_worker.js` — Why this file exists

The portal intentionally does not register a Service Worker. Historically the build emitted an empty 0-byte `flutter_service_worker.js`. An empty file is **not** a kill signal — browsers treat a SW script as updated only when its bytes differ from the cached copy, then run install/activate. An empty-200 reads as "no change" and any old SW stays put indefinitely.

This file replaces the empty placeholder with a tiny self-unregistering SW. The first time a browser with a stale SW fetches this script (on its ~24 h update check, or sooner with a hard reload), it sees byte-different content, treats it as a new SW, runs install + activate, and the activate handler unregisters the SW and reloads any open tabs. After that reload, the browser has no SW in control and Firebase Auth proceeds normally.

Surfaced by **CUR-1327** (Firebase Auth timeout on QA, traced to a stale SW intercepting `securetoken.googleapis.com`). Fixed by **CUR-1335**.

## Invariants

**DO NOT add a `fetch` handler.** Even a pass-through `event.respondWith(fetch(event.request))` re-introduces the connection-management surface that caused the original bug. The kill-switch must have `install` + `activate` handlers only.

**DO NOT edit the file casually.** Browsers cache the SW script. Any byte change triggers another `install`/`activate` cycle, which means another forced reload in every browser that has it cached. Unnecessary churn is visible to users mid-form.

**DO NOT register this SW from Dart.** `flutter_bootstrap.js` does not call `loadServiceWorker` and that must stay so. The kill-switch only activates in browsers where an OLD deploy's SW registration still exists. Fresh users never see it active.

## Removal horizon

Once we're confident no user still has a pre-CUR-1335 SW (~60–90 days post-deploy per ticket guidance), this file can be reduced to a one-line empty SW or deleted entirely. Before removing, audit Sentry / Cloud Logging for any remaining `TimeoutException after 0:00:05.000000` / `network-request-failed` reports tied to portal auth.

Until then: **byte-stable**.

## Related

- **CUR-1327** — bug surfaced (Firebase Auth timeout on QA portal).
- **CUR-1280** — in-app race fix; the Dart-side `_unregisterLeftoverServiceWorkers()` in `apps/sponsor-portal/portal-ui/lib/main.dart` is complementary. It handles the *next* boot's cleanup; the kill-switch handles the case where the *current* session is already booted under a stale SW that's hanging on requests in flight.
- `REQ-p00009` — portal always serves the latest deploy.
- `REQ-p01044-M` — no patient data recoverable from the browser after logout (SW caches could otherwise persist).
