# Clinical Trial Portal UI

Flutter Web application for the Clinical Trial Sponsor Portal.

## Purpose

The portal UI is a web-based management interface for clinical trial sponsors. It enables:
- **Authentication**: Login via Google Identity Platform (Firebase Auth)
- **User Management**: Create and manage portal users (Administrators)
- **Patient Overview**: Monitor patient engagement and compliance
- **Site Management**: View and manage clinical trial sites
- **Audit Access**: Read-only compliance views (Auditors)

## Requirements Implemented

- REQ-p00009: Sponsor-Specific Web Portals
- REQ-p00024: Portal User Roles and Permissions
- REQ-d00028: Portal Frontend Framework
- REQ-d00031: Identity Platform Integration
- REQ-d00034: Login Page Implementation
- REQ-d00035: Admin Dashboard Implementation

## Architecture

### Technology Stack

- **Framework**: Flutter 3.24+ (Web)
- **Language**: Dart 3.5+
- **Authentication**: Google Identity Platform (Firebase Auth)
- **HTTP Client**: http package for API calls
- **Routing**: go_router
- **State Management**: provider
- **UI**: Material Design 3

### Project Structure

```
portal-ui/
├── lib/
│   ├── main.dart                     # App entry point
│   ├── services/
│   │   ├── auth_service.dart         # Firebase Auth integration
│   │   └── api_client.dart           # HTTP client for portal API
│   ├── router/
│   │   └── app_router.dart           # Route configuration
│   ├── theme/
│   │   └── portal_theme.dart         # Material Design 3 theme
│   ├── widgets/
│   │   ├── portal_app_bar.dart       # App bar with user info
│   │   └── portal_drawer.dart        # Navigation drawer
│   └── pages/
│       ├── login_page.dart           # Email/password login
│       ├── admin/
│       │   ├── admin_dashboard_page.dart
│       │   └── user_management_tab.dart
│       ├── investigator/
│       │   └── investigator_dashboard_page.dart
│       └── auditor/
│           └── auditor_dashboard_page.dart
├── web/
│   ├── index.html                    # Web entry point
│   └── manifest.json                 # PWA manifest
├── test/                             # Unit/widget tests
└── pubspec.yaml                      # Dependencies
```

## User Roles

| Role            | Access Level                                    |
|-----------------|-------------------------------------------------|
| Administrator   | User management, all data access                |
| Developer Admin | Full access including dev tools                 |
| Investigator    | Assigned sites only, patient management         |
| Sponsor         | All sites, read/write access                    |
| Auditor         | All sites, read-only access                     |
| Analyst         | All sites, data analysis access                 |

## Running Locally

### Prerequisites

- Flutter 3.24+ installed (`flutter --version`)
- Chrome browser
- Portal server running (see portal_server README)
- Firebase emulator OR real Firebase project

### Option 1: Local Development with Firebase Emulator

```bash
# 1. Start Firebase emulator
cd tools/dev-env
docker-compose -f docker-compose.firebase.yml up -d

# 2. Create test user in Firebase emulator UI
# Open http://localhost:4000/auth
# Add user: mike.bushe@anspar.org with any password

# 3. Start portal server
cd apps/sponsor-portal/portal_server
doppler run -- dart run bin/server.dart

# 4. Run Flutter app
cd apps/sponsor-portal/portal-ui
flutter run -d chrome \
  --dart-define=PORTAL_API_URL=http://localhost:8080 \
  --dart-define=USE_FIREBASE_EMULATOR=true
```

### Option 2: Development without Emulator (Real Firebase)

```bash
cd apps/sponsor-portal/portal-ui

# Run with real Firebase project
flutter run -d chrome \
  --dart-define=PORTAL_API_URL=http://localhost:8080
```

### Environment Variables

Pass via `--dart-define` at build/run time:

| Variable               | Description                    | Default                    |
|------------------------|--------------------------------|----------------------------|
| `PORTAL_API_URL`       | Portal server URL              | `http://localhost:8080`    |
| `USE_FIREBASE_EMULATOR`| Use Firebase Auth emulator     | `false`                    |

## Testing

### Running Tests

```bash
cd apps/sponsor-portal/portal-ui

# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/services/auth_service_test.dart
```

### Widget Tests

```bash
# Run widget tests
flutter test test/widgets/

# Run integration tests (requires Chrome)
flutter test integration_test/
```

### Test Structure

| Directory           | Description                            |
|---------------------|----------------------------------------|
| `test/`             | Unit and widget tests                  |
| `test/services/`    | Service layer tests                    |
| `test/widgets/`     | Widget tests                           |
| `integration_test/` | End-to-end tests (requires Chrome)     |

## Building

### Development Build

```bash
flutter build web --dart-define=PORTAL_API_URL=http://localhost:8080
```

### Production Build

```bash
flutter build web --release \
  --dart-define=PORTAL_API_URL=https://portal-api.sponsor.com
```

Output: `build/web/` (deploy to any static hosting)

## Deployment

### Cloud Run (Recommended)

The portal UI is deployed alongside the portal server in a single container:

1. Build Flutter web: `flutter build web --release`
2. Copy `build/web/` to container's nginx directory
3. Nginx serves static files + proxies API requests

See `apps/sponsor-portal/portal-container/` for container setup.

### Static Hosting

Deploy `build/web/` to:
- **Netlify**: Configure `_redirects` for SPA routing
- **Vercel**: Configure `vercel.json` for SPA routing
- **Cloudflare Pages**: Configure `_redirects`
- **Firebase Hosting**: Configure `firebase.json` rewrites

## Authentication Flow

### Login Process

1. User enters email/password on login page
2. `AuthService.signIn()` calls Firebase Auth SDK
3. Firebase validates credentials, returns ID token
4. `AuthService` calls `GET /api/v1/portal/me` with token
5. Server validates token, returns user info with role
6. `AuthService` stores user, triggers navigation
7. `AppRouter` redirects to role-appropriate dashboard

### Password Reset

Users can reset their password via Firebase:

```dart
// In login page
await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
```

This sends an email with a reset link (requires Firebase email service configured).

### Email Verification

To require verified emails:

```dart
// Check verification status after login
if (!user.emailVerified) {
  await user.sendEmailVerification();
  // Show "check your email" message
}
```

## API Endpoints

The portal UI communicates with these server endpoints:

| Endpoint                         | Method | Description               |
|----------------------------------|--------|---------------------------|
| `/api/v1/portal/me`              | GET    | Get current user info     |
| `/api/v1/portal/users`           | GET    | List all users (Admin)    |
| `/api/v1/portal/users`           | POST   | Create user (Admin)       |
| `/api/v1/portal/users/:id`       | PATCH  | Update user (Admin)       |
| `/api/v1/portal/sites`           | GET    | List clinical sites       |

## Troubleshooting

### "User not authorized" after login

- Ensure email exists in `portal_users` database table
- Check that seed_data.sql was applied (sponsor-specific repo)
- Verify email matches exactly (case-sensitive)

### Firebase emulator not working

- Check emulator is running: `docker ps | grep firebase`
- Verify `USE_FIREBASE_EMULATOR=true` is set
- Check emulator UI at http://localhost:4000

### CORS errors

- Ensure portal server is running
- Check `PORTAL_API_URL` points to correct server
- Server should allow `*` origin in development

### Build errors

```bash
flutter clean
flutter pub get
flutter build web
```

### Hot reload not working

- Use `flutter run -d chrome` for development
- Press `r` for hot reload, `R` for hot restart

## Dependencies

- `firebase_core`: Firebase initialization
- `firebase_auth`: Firebase Auth SDK
- `http`: HTTP client for API calls
- `go_router`: Declarative routing
- `provider`: State management
- `flutter_svg`: SVG asset support

## Related Documentation

- [Portal Server README](../portal_server/README.md) - Backend API
- [Portal Functions README](../portal_functions/README.md) - Handler implementations
- [Database README](../../../database/README.md) - Schema details
- [Firebase Setup](../../../tools/dev-env/firebase/README.md) - Emulator configuration
