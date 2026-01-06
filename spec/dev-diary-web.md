# Web Diary Application Implementation

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-12-27
**Status**: Draft

> **See**: prd-diary-web.md for product requirements
> **See**: dev-app.md for mobile app implementation patterns
> **See**: dev-security.md for security implementation details

---

## Executive Summary

This specification defines the implementation details for the Web Diary application, a browser-based companion to the mobile Clinical Diary app. The Web Diary uses Flutter Web for the frontend, a custom HHT Diary Auth service for authentication (avoiding Identity Platform for GDPR compliance), and Firestore for data storage.

**Technology Stack**:
- **Frontend**: Flutter Web (Dart)
- **Authentication**: Custom HHT Diary Auth service on Cloud Run
- **Database**: Firestore (same collections as mobile app)
- **Hosting**: Firebase Hosting or Cloud Run
- **Password Hashing**: Argon2id (client-side before transmission)

## Status

Web security does not have the hardware-level safety that mobile apps allow.  The web app needs to have a review of
it's security posture.

The lack of a local database conflicts with REQ-p01001: Offline Event Queue with Automatic Synchronization

---

# REQ-d00077: Web Diary Frontend Framework

**Level**: Dev | **Implements**: p01042 | **Status**: Draft

The Web Diary SHALL be implemented using Flutter Web, reusing the same codebase as mobile with limited additions.

Implementation SHALL include:
- Flutter Web application
- Shared widget library with mobile app for consistent UI patterns
- Material Design 3 theming with sponsor-specific customization
- Responsive layout supporting desktop and tablet viewports
- Service worker disabled (no offline caching for security)

```dart
// main.dart - Web-specific initialization
void main() {
  // Disable service worker for security (no offline caching)
  if (html.window.navigator.serviceWorker != null) {
    html.window.navigator.serviceWorker!.getRegistrations().then((registrations) {
      for (var registration in registrations) {
        registration.unregister();
      }
    });
  }

  runApp(const ClinicalDiaryApp());
}
```

**Rationale**: Flutter Web enables code sharing with the mobile app. Disabling service workers prevents cached data from persisting beyond the session.

**Acceptance Criteria**:
- Application loads in Chrome, Firefox, Safari, Edge (latest 2 versions)
- No service worker registered
- Sponsor theming applied after authentication
- Responsive layout adapts to viewport width
- Shared components render consistently with mobile app

*End* *Web Diary Frontend Framework* | **Hash**: 4a806386

---

# REQ-d00080: Web Session Management Implementation

**Level**: Dev | **Implements**: p01044 | **Status**: Draft

TODO - is this true for mobile too?  if so, we should just remove or move this.

The Web Diary SHALL implement client-side session management with inactivity timeout, browser close detection, and complete session termination.

Implementation SHALL include:
- Inactivity timer tracking user interactions (mouse, keyboard, touch)
- Warning modal displayed 30 seconds before timeout
- Session extension on user confirmation
- Browser `beforeunload` event handler for tab/window close
- `visibilitychange` event handler for tab switching
- Complete storage clearing on logout

```dart
// Session manager implementation
class WebSessionManager {
  static const defaultTimeoutMinutes = 2;
  Timer? _inactivityTimer;
  Timer? _warningTimer;

  void startSession(int timeoutMinutes) {
    _resetInactivityTimer(timeoutMinutes);
    _registerEventListeners();
    _registerBeforeUnload();
  }

  void _registerEventListeners() {
    // Reset timer on any user interaction
    html.document.onMouseMove.listen((_) => _resetInactivityTimer());
    html.document.onKeyDown.listen((_) => _resetInactivityTimer());
    html.document.onTouchStart.listen((_) => _resetInactivityTimer());
    html.document.onClick.listen((_) => _resetInactivityTimer());
  }

  void _registerBeforeUnload() {
    html.window.onBeforeUnload.listen((event) {
      clearAllStorage();
    });
  }

  void clearAllStorage() {
    html.window.localStorage.clear();
    html.window.sessionStorage.clear();
    // Clear cookies by setting expiry in past
    _clearCookies();
  }
}
```

**Rationale**: Aggressive session management protects patient data on shared computers. Multiple event listeners ensure the timer resets on any user activity, while beforeunload provides last-chance cleanup.

**Acceptance Criteria**:
- Timer resets on mouse move, keypress, touch, click
- Warning appears at 30-second mark before timeout
- User can extend session from warning modal
- Browser close triggers storage clearing
- Tab switching to other apps does not trigger logout (only close)
- Back button after logout shows login page, not cached data

*End* *Web Session Management Implementation* | **Hash**: c917a5ad

---

TODO - move to dev-app.md

# REQ-d00082: Password Hashing Implementation

**Level**: Dev | **Implements**: p01043, p01046 | **Status**: Draft

Passwords SHALL be hashed client-side before network transmission using Argon2id, with server-side verification using the same algorithm.

Implementation SHALL include:
- Client-side hashing using `argon2` Dart package (WASM build for web)
- Argon2id variant with OWASP-recommended parameters
- Salt generated per-user and stored with hash
- Hash transmitted to server (never plaintext password)
- Server verifies by re-hashing with stored salt

```dart
// Client-side password hashing
import 'package:argon2/argon2.dart';

class PasswordHasher {
  // OWASP recommended parameters for Argon2id
  static const int memory = 65536;    // 64 MB
  static const int iterations = 3;
  static const int parallelism = 4;
  static const int hashLength = 32;

  static Future<String> hashPassword(String password, String salt) async {
    final argon2 = Argon2BytesGenerator();
    final params = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      utf8.encode(salt),
      desiredKeyLength: hashLength,
      iterations: iterations,
      memory: memory,
      lanes: parallelism,
    );

    argon2.init(params);
    final result = Uint8List(hashLength);
    argon2.generateBytes(utf8.encode(password), result, 0, hashLength);

    return base64Encode(result);
  }
}

// Registration flow
// 1. Client generates random salt
// 2. Client hashes password with salt
// 3. Client sends: username, hash, salt, linkingCode, appUuid
// 4. Server stores: username, hash, salt, sponsorId, ...

// Login flow
// 1. Client sends: username, password (plaintext for now - see note)
// 2. Server retrieves salt for username
// 3. Server hashes provided password with stored salt
// 4. Server compares hashes
```

**Note**: For login, the password must be sent to retrieve the salt. Use TLS for transport security. Alternative: implement SRP (Secure Remote Password) protocol for zero-knowledge proof.

**Rationale**: Client-side hashing ensures plaintext passwords are never transmitted (except for salt retrieval). Argon2id is the current recommended password hashing algorithm, resistant to GPU and side-channel attacks.

**Acceptance Criteria**:
- Password never stored or logged in plaintext
- Argon2id hash computed before network transmission (registration)
- Hash parameters meet OWASP recommendations
- Salt unique per user, stored alongside hash
- Password change re-hashes with new salt

*End* *Password Hashing Implementation* | **Hash**: 05136a5d

---

# REQ-d00083: Browser Storage Clearing

**Level**: Dev | **Implements**: p01044 | **Status**: Draft

The Web Diary SHALL clear all browser storage mechanisms on logout, session timeout, and browser close to prevent data persistence.

Implementation SHALL include:
- Clear localStorage
- Clear sessionStorage
- Clear all cookies (set expiry to past)
- Clear IndexedDB databases
- Clear Cache Storage (service worker caches)
- Navigate to login page after clearing

```dart
// Comprehensive storage clearing
class StorageClearer {
  static Future<void> clearAllStorage() async {
    // Clear Web Storage API
    html.window.localStorage.clear();
    html.window.sessionStorage.clear();

    // Clear all cookies
    _clearAllCookies();

    // Clear IndexedDB (if used)
    await _clearIndexedDB();

    // Clear Cache Storage
    await _clearCacheStorage();
  }

  static void _clearAllCookies() {
    final cookies = html.document.cookie?.split(';') ?? [];
    for (final cookie in cookies) {
      final name = cookie.split('=')[0].trim();
      // Set expiry in the past to delete
      html.document.cookie = '$name=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/';
      // Also clear for current domain
      html.document.cookie = '$name=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/; domain=${html.window.location.hostname}';
    }
  }

  static Future<void> _clearIndexedDB() async {
    final databases = await html.window.indexedDB?.databases();
    if (databases != null) {
      for (final db in databases) {
        html.window.indexedDB?.deleteDatabase(db['name'] as String);
      }
    }
  }

  static Future<void> _clearCacheStorage() async {
    final cacheNames = await html.window.caches?.keys();
    if (cacheNames != null) {
      for (final name in cacheNames) {
        await html.window.caches?.delete(name);
      }
    }
  }
}
```

**Rationale**: Complete storage clearing prevents the next user on a shared computer from accessing any patient data. Multiple storage mechanisms must be cleared as browsers persist data in various locations.

**Acceptance Criteria**:
- localStorage empty after logout
- sessionStorage empty after logout
- No cookies remain after logout
- IndexedDB databases deleted after logout
- Browser back button shows login page, not cached content
- No patient data recoverable via browser dev tools

*End* *Browser Storage Clearing* | **Hash**: d5857410

---
TODO - remove or move to dev-app.md
# REQ-d00084: Sponsor Configuration Loading

**Level**: Dev | **Implements**: p01042, p01043 | **Status**: Draft

After successful authentication, the Web Diary SHALL load sponsor-specific configuration by fetching it directly from the Sponsor Portal using the portal URL provided in the authentication token.

Implementation SHALL include:
- Sponsor Portal URL obtained from auth token after login
- Sponsor configuration fetched directly from Sponsor Portal API
- Configuration cached in memory only (not persisted)
- Theme applied based on sponsor branding from portal response
- Session timeout configured per sponsor settings from portal

```dart
// Auth token includes portal URL (from linking code pattern match)
class AuthToken {
  final String sub;
  final String username;
  final String sponsorId;
  final String sponsorUrl;  // Sponsor Portal base URL
  final String appUuid;
  final DateTime iat;
  final DateTime exp;
}

// Sponsor configuration fetched from Sponsor Portal
class SponsorConfig {
  final String sponsorId;
  final String sponsorName;
  final int sessionTimeoutMinutes;   // Default 2, range 1-30
  final SponsorBranding branding;
}

class SponsorBranding {
  final String logoUrl;
  final String primaryColor;      // Hex color
  final String secondaryColor;    // Hex color
  final String? welcomeMessage;
}

// Post-login initialization
Future<void> initializeSponsorContext(AuthToken token) async {
  // Fetch sponsor config directly from Sponsor Portal
  final configUrl = '${token.sponsorUrl}/api/diary/config';
  final response = await http.get(Uri.parse(configUrl));
  final config = SponsorConfig.fromJson(jsonDecode(response.body));

  // Apply branding
  applyTheme(config.branding);

  // Start session with sponsor's timeout
  sessionManager.startSession(config.sessionTimeoutMinutes);
}
```

**Rationale**: Fetching sponsor configuration directly from the Sponsor Portal simplifies the auth service (which only needs to provide the portal URL) and ensures the client always gets the latest sponsor configuration. The Sponsor Portal already manages sponsor-specific data including branding, making it the authoritative source.

**Acceptance Criteria**:
- Portal URL available in auth token after successful login
- Sponsor config fetched from Sponsor Portal within 1 second
- Branding (logo, colors) applied immediately after fetch
- Session timeout uses sponsor-configured value
- Config not persisted to browser storage
- Graceful fallback if portal config fetch fails (use defaults)

*End* *Sponsor Configuration Loading* | **Hash**: 5a79a42d

---

## Security Considerations

**Transport Security**:
- All communication over HTTPS (TLS 1.3)
- HSTS headers enabled on all endpoints
- Certificate pinning not applicable for web

**Content Security Policy**:
```
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'wasm-unsafe-eval';
  style-src 'self' 'unsafe-inline';
  connect-src 'self' https://*.googleapis.com https://*.firebaseio.com;
  img-src 'self' data: https:;
  frame-ancestors 'none';
```

**Cookie Security**:
- All cookies set with `Secure`, `HttpOnly`, `SameSite=Strict`
- Session cookies only (no persistent cookies)

---

## References

- **Product Requirements**: prd-diary-web.md
- **Mobile App Implementation**: dev-app.md
- **Security Implementation**: dev-security.md
- **OWASP Password Storage**: https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
- **Argon2 Specification**: https://github.com/P-H-C/phc-winner-argon2

---

## Revision History

| Version | Date | Changes | Author |
| --- | --- | --- | --- |
| 1.0 | 2025-12-05 | Initial Web Diary implementation specification | CUR-423 |

---

**Document Classification**: Internal Use - Development Specification
**Review Frequency**: Quarterly or when modifying web diary implementation
**Owner**: Development Team
