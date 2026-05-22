// Implements: REQ-p00009
// Implements: REQ-p01044-M
//
// Self-unregistering kill-switch Service Worker.
//
// The portal deliberately does NOT register a SW (see web/index.html
// REQ annotations; build uses --pwa-strategy=none in the sibling repo's
// portal-final.Dockerfile). This file exists solely to unregister any SW
// left behind by earlier deploys that did register one. Browsers fetch
// /flutter_service_worker.js periodically (~24 h) for any active SW at
// this scope; on a byte-different file the browser runs install/activate.
// activate unregisters the SW and reloads any open tabs, after which the
// browser has no SW in control and Firebase Auth proceeds normally.
//
// DO NOT add a fetch handler — even a pass-through
// event.respondWith(fetch(event.request)) re-introduces the
// connection-management surface that caused the original bug (CUR-1327).
//
// DO NOT casually edit this file — any byte change triggers another
// install/activate cycle (and forced reload) in every browser that has
// it cached. See web/README.md for rationale and the ~60-90 day removal
// horizon.

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    await self.registration.unregister();
    const clients = await self.clients.matchAll({ type: 'window' });
    clients.forEach((client) => client.navigate(client.url));
  })());
});
