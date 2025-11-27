// Service Worker for voice command handling and background tasks
const CACHE_NAME = 'nosebleed-tracker-v1';
const urlsToCache = [
  '/',
  '/static/js/bundle.js',
  '/static/css/main.css',
  '/manifest.json'
];

// Install event - cache resources
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(urlsToCache))
  );
});

// Fetch event - serve from cache when offline
self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        // Return cached version or fetch from network
        return response || fetch(event.request);
      })
  );
});

// Background sync for voice commands
self.addEventListener('sync', (event) => {
  if (event.tag === 'voice-command-record') {
    event.waitUntil(handleVoiceCommand());
  }
});

// Push notification for voice command triggers
self.addEventListener('push', (event) => {
  if (event.data) {
    const data = event.data.json();
    if (data.action === 'record-nosebleed') {
      event.waitUntil(
        self.registration.showNotification('Nosebleed Tracker', {
          body: 'Voice command detected: Recording nosebleed event',
          icon: '/icon-192.png',
          badge: '/icon-192.png',
          tag: 'voice-record',
          actions: [
            {
              action: 'open-app',
              title: 'Open App'
            },
            {
              action: 'dismiss',
              title: 'Dismiss'
            }
          ]
        })
      );
    }
  }
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  
  if (event.action === 'open-app') {
    event.waitUntil(
      clients.openWindow('/?action=record')
    );
  }
});

// Helper function to handle voice commands
async function handleVoiceCommand() {
  try {
    // Open the app with recording action
    const windowClients = await clients.matchAll({
      type: 'window',
      includeUncontrolled: true
    });
    
    if (windowClients.length > 0) {
      // Focus existing window and trigger recording
      const client = windowClients[0];
      client.focus();
      client.postMessage({ action: 'start-recording' });
    } else {
      // Open new window
      clients.openWindow('/?action=record');
    }
  } catch (error) {
    console.error('Error handling voice command:', error);
  }
}