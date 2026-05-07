# Data Sync Strategy: FCM + Polling Fallback

## Problem

The app lacks a push-based mechanism to trigger data sync. Currently data is only fetched on user-initiated actions. We need the server to signal the client when data changes, and the client to react by fetching differential updates via existing API endpoints.

## Architecture Overview

Two sync triggers feeding a single sync pipeline:

```
┌──────────────────────────────────────────────────────────────┐
│                         SERVER                                │
│                                                              │
│  DB Write/Event ──→ FCM Admin SDK ──→ data-only message      │
│                                   ──→ notification message   │
│                                                              │
│  fcm_tokens table: (user_id, device_id, token, updated_at)  │
└──────────────────────┬───────────────────────────────────────┘
                       │ FCM (APNs on iOS / FCM on Android)
                       ▼
┌──────────────────────────────────────────────────────────────┐
│                         CLIENT                                │
│                                                              │
│  ┌─────────────────┐                                         │
│  │ FirebaseMessaging│──┐                                     │
│  │  onMessage       │  │                                     │
│  │  onBackgroundMsg │  │     ┌────────────────────┐          │
│  └─────────────────┘  ├────→│   SyncController    │          │
│                        │     │                    │          │
│  ┌─────────────────┐  │     │  1. Read lastSync  │          │
│  │ PollingService   │──┘     │  2. Call diff APIs │          │
│  │  Timer.periodic  │       │  3. Merge state    │          │
│  │  (fallback only) │       │  4. Write lastSync │          │
│  └─────────────────┘       └────────────────────┘          │
│         ▲                                                    │
│         │ activated by SyncController                        │
│         │ when FCM unavailable                               │
└──────────────────────────────────────────────────────────────┘
```

## 1. FCM Integration (Primary Trigger)

### 1.1 Message Types

| Type | FCM Field | Payload | Purpose |
| --- | --- | --- | --- |
| Silent data push | `data` only (no `notification`) | `{ "type": "sync", "entity": "questionnaire", "timestamp": "..." }` | Wake app, trigger diff sync — no user-visible notification |
| Visible notification | `notification`  • optional `data` | `{ "title": "...", "body": "..." }` | User-facing alert (new assignment, reminder, etc.) |

### 1.2 Client-Side FCM Handling (Flutter)

**Package:** `firebase_messaging` + `firebase_core`

```
FirebaseMessaging.instance
  ├── getToken()              → register with server
  ├── onTokenRefresh          → re-register with server
  ├── onMessage               → foreground: trigger SyncController.sync()
  └── onBackgroundMessage     → isolate: trigger SyncController.sync()
```

**Background isolate constraints:**

- No access to UI, no `BuildContext`
- Must use top-level function annotated `@pragma('vm:entry-point')`
- Can access SharedPreferences or local DB for `lastSyncTimestamp`
- Network calls allowed — diff fetch runs in background

### 1.3 Token Lifecycle

```
App launch
  → FirebaseMessaging.instance.getToken()
  → POST /devices/register { token, platform, device_id }
  → Server upserts fcm_tokens table

onTokenRefresh stream
  → Same POST, server replaces stale token

Logout or device unenroll
  → DELETE /devices/{device_id}
  → Server removes token row
```

### 1.4 Server-Side FCM Dispatch

On relevant DB event (new questionnaire published, config change, etc.):

```
1. Query fcm_tokens for target user(s) or device(s)
2. Build FCM message:
   - data-only for silent sync trigger
   - notification + data for user-facing alerts
3. Send via Firebase Admin SDK (batch API for multi-device)
4. Handle errors:
   - messaging/registration-token-not-registered → delete stale token
   - messaging/quota-exceeded → backoff, rely on client polling
```

## 2. Polling (Fallback Trigger)

### 2.1 When Polling Activates

Polling is **not always running**. `SyncController` manages the lifecycle:

| Condition | Polling State |
| --- | --- |
| FCM permission granted AND token registered | **OFF** |
| FCM permission denied | **ON** |
| FCM token registration failed | **ON** |
| No sync event received in `2 * pollingInterval` | **ON** (safety net) |
| App returns to foreground after > N minutes | Single immediate poll |

### 2.2 Implementation

```dart
class PollingService {
  Timer? _timer;
  final Duration interval; // default 15 min, server-configurable

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => SyncController.sync());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  bool get isActive => _timer?.isActive ?? false;
}
```

### 2.3 Battery / Network Considerations

- `Timer.periodic` is paused by OS when app is suspended — acceptable, sync catches up on resume
- No `WorkManager` or `background_fetch` needed — polling is a foreground fallback, FCM handles background
- Skip poll if `connectivity` reports no connection

## 3. SyncController (Unified Sync Pipeline)

Both FCM and polling feed into the same `SyncController`:

```dart
class SyncController {
  static Future<void> sync() async {
    final lastSync = await _readLastSyncTimestamp();

    // Call existing diff endpoints with since= parameter
    final results = await Future.wait([
      api.getUpdatedQuestionnaires(since: lastSync),
      api.getUpdatedSchedules(since: lastSync),
      api.getUpdatedConfig(since: lastSync),
    ]);

    await _mergeResults(results);
    await _writeLastSyncTimestamp(DateTime.now().toUtc());

    // Reset safety-net timer since sync succeeded
    _lastSyncTime = DateTime.now();
  }
}
```

**Key points:**

- Uses **existing API endpoints** — no new endpoints required
- `lastSyncTimestamp` persisted in SharedPreferences or local DB
- Concurrent fetch of independent entities via `Future.wait`
- Idempotent — safe to call multiple times (duplicate triggers do not cause issues)

## 4. Permission-Aware Switching Logic

```dart
class SyncManager {
  final PollingService _polling;
  final SyncController _sync;

  Future<void> initialize() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    final isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized;

    if (isAuthorized) {
      await _registerFcmToken();
      _polling.stop();
    } else {
      _polling.start();
    }

    // Safety net: always monitor last sync time
    _startSafetyNetCheck();
  }

  void _startSafetyNetCheck() {
    Timer.periodic(Duration(minutes: 30), (_) {
      final gap = DateTime.now().difference(_sync.lastSyncTime);
      if (gap > Duration(minutes: 30)) {
        _sync.sync(); // force poll regardless of FCM status
      }
    });
  }

  // Called when user changes notification permission in OS settings
  void onPermissionChanged(bool granted) {
    if (granted) {
      _registerFcmToken();
      _polling.stop();
    } else {
      _polling.start();
    }
  }
}
```

## 5. Sequence Diagrams

### 5.1 FCM Path (Happy Path)

```
Server              FCM            Client (foreground)
  │                  │                  │
  │─ data msg ──────→│                  │
  │                  │─ onMessage ─────→│
  │                  │                  │── read lastSync
  │                  │                  │── GET /api?since=T
  │←─────────────────│──────────────────│
  │─ diff response ─→│─────────────────→│
  │                  │                  │── merge + update UI
```

### 5.2 FCM Path (Background)

```
Server              FCM            Client (suspended)
  │                  │                  │
  │─ data msg ──────→│                  │
  │                  │─ wake isolate ──→│
  │                  │                  │── read lastSync (DB)
  │                  │                  │── GET /api?since=T
  │                  │                  │── write to local DB
  │                  │                  │── (no UI update)
  │                  │     User opens app
  │                  │                  │── read local DB → UI
```

### 5.3 Polling Fallback

```
Client (FCM denied)
  │
  │── Timer fires (every 15m)
  │── GET /api?since=T
  │── merge response
  │── update UI if foreground
  │── reset timer
```

## 6. Server-Side Changes Summary

| Change | Detail |
| --- | --- |
| `fcm_tokens` table | `(user_id, device_id, token, platform, created_at, updated_at)` |
| Token registration endpoint | `POST /devices/register`, `DELETE /devices/{id}` |
| FCM dispatch service | Firebase Admin SDK, triggered on DB events |
| Stale token cleanup | Remove tokens on 404 from FCM, periodic sweep |

## 7. Client-Side Changes Summary

| Component | Responsibility |
| --- | --- |
| `SyncManager` | Orchestrates FCM vs polling, permission checks |
| `SyncController` | Executes diff fetch via existing APIs, merges state |
| `PollingService` | `Timer.periodic` fallback, started or stopped by `SyncManager` |
| FCM handlers | `onMessage`, `onBackgroundMessage`, token lifecycle |
| `lastSyncTimestamp` | Persisted locally, used as `since` param |