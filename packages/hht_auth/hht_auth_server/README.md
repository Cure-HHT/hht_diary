# HHT Auth Server

Server-side authentication service for HHT Diary Web Application (Cloud Run deployment).

## Overview

This package implements a custom authentication service that avoids Firebase Auth/Google Identity Platform for GDPR compliance. It provides JWT-based authentication with password hashing, rate limiting, and multi-sponsor support.

## Implements Requirements

- **REQ-d00078**: HHT Diary Auth Service (JWT generation, validation, routing)
- **REQ-d00079**: Linking Code Pattern Matching (sponsor identification from codes)
- **REQ-d00081**: User Document Schema (Firestore user storage)
- **REQ-d00082**: Password Hashing (Argon2id server-side verification)

## Features

### Core Services

1. **JWT Service** (`JwtService`)
   - RS256-signed JSON Web Tokens
   - 15-minute token expiry (configurable)
   - Token generation, verification, and refresh
   - Bearer token extraction from headers

2. **Rate Limiter** (`RateLimiter`)
   - 5 attempts per minute per key (default)
   - Sliding window rate limiting
   - Per-key tracking (IP + username combination)
   - Automatic cleanup of expired entries

3. **Argon2 Verifier** (`Argon2Verifier`)
   - Argon2id password hash verification
   - OWASP-recommended parameters (64MB, 3 iterations, 4 parallelism)
   - Server-side verification of client-hashed passwords

### Repository Interfaces

1. **UserRepository**
   - User CRUD operations
   - Failed attempt tracking
   - Account lockout management
   - Username uniqueness per sponsor

2. **SponsorPatternRepository**
   - Sponsor pattern management
   - Linking code prefix matching
   - 5-minute pattern cache
   - Active/decommissioned status

## Testing

This package was built using **Test-Driven Development (TDD)**. All services have comprehensive test coverage:

```bash
# Run all tests
dart test

# Run specific test suite
dart test test/src/services/jwt_service_test.dart
dart test test/src/services/rate_limiter_test.dart
dart test test/src/services/argon2_verifier_test.dart
```

### Test Coverage

- **JWT Service**: 15 tests
  - Token generation with correct claims
  - Token verification (valid, expired, invalid)
  - Token refresh
  - Bearer header extraction

- **Rate Limiter**: 13 tests
  - Request limit enforcement
  - Independent key tracking
  - Window expiry and reset
  - Remaining attempts calculation

- **Argon2 Verifier**: 9 tests
  - Password verification (correct, incorrect)
  - Salt handling
  - Unicode support
  - Deterministic hashing

## Fake Implementations

For testing, use the fake repository implementations:

```dart
import 'package:hht_auth_server/testing.dart';

test('example', () async {
  final userRepo = FakeUserRepository();
  final patternRepo = FakeSponsorPatternRepository();

  // Use fakes in your tests
});
```

## Configuration

Server configuration is loaded from environment variables:

```bash
HOST=0.0.0.0
PORT=8080
JWT_PRIVATE_KEY=<PEM-encoded RSA private key>
JWT_PUBLIC_KEY=<PEM-encoded RSA public key>
JWT_ISSUER=hht-auth-service
FIRESTORE_PROJECT_ID=<GCP project ID>
FIRESTORE_API_KEY=<Firestore API key>
RATE_LIMIT_MAX_ATTEMPTS=5
RATE_LIMIT_WINDOW_MINUTES=1
ACCOUNT_LOCKOUT_MINUTES=15
```

## Architecture

```
lib/
├── src/
│   ├── services/
│   │   ├── jwt_service.dart          # JWT token operations
│   │   ├── rate_limiter.dart         # Rate limiting
│   │   └── argon2_verifier.dart      # Password verification
│   ├── repositories/
│   │   ├── user_repository.dart      # User data interface
│   │   └── sponsor_pattern_repository.dart  # Sponsor patterns
│   └── config/
│       └── server_config.dart        # Environment config
├── testing/
│   ├── fake_user_repository.dart     # In-memory fake
│   └── fake_sponsor_pattern_repository.dart
├── hht_auth_server.dart              # Main library export
└── testing.dart                      # Testing utilities export

test/
└── src/
    └── services/
        ├── jwt_service_test.dart
        ├── rate_limiter_test.dart
        └── argon2_verifier_test.dart
```

## Next Steps

To complete the full implementation, the following components need to be added:

### Middleware (to be implemented)
- `auth_middleware.dart` - JWT verification middleware
- `rate_limit_middleware.dart` - Rate limiting middleware
- `cors_middleware.dart` - CORS headers

### Route Handlers (to be implemented)
- `register_handler.dart` - POST /auth/register
- `login_handler.dart` - POST /auth/login
- `refresh_handler.dart` - POST /auth/refresh
- `validate_linking_code_handler.dart` - POST /auth/validate-linking-code
- `change_password_handler.dart` - POST /auth/change-password

### Firestore Implementations (to be implemented)
- `firestore_user_repository.dart` - Real Firestore user repository
- `firestore_sponsor_pattern_repository.dart` - Real Firestore pattern repository

### Server Entry Point (to be implemented)
- `bin/server.dart` - Main server entry point
- Shelf router setup
- Middleware pipeline
- Health check endpoint

## API Endpoints

Once route handlers are implemented, the service will expose:

```
POST /auth/validate-linking-code
  Body: { "linkingCode": "..." }
  Response: LinkingCodeValidation JSON

POST /auth/register
  Body: RegistrationRequest JSON
  Response: { "token": AuthToken JSON }

POST /auth/login
  Body: LoginRequest JSON
  Response: { "token": AuthToken JSON }

POST /auth/refresh
  Headers: Authorization: Bearer <jwt>
  Response: { "token": AuthToken JSON }

POST /auth/change-password
  Headers: Authorization: Bearer <jwt>
  Body: { "currentPassword": "...", "newPasswordHash": "...", "newSalt": "..." }
  Response: { "success": true }

GET /health
  Response: { "status": "healthy" }
```

## Dependencies

- `hht_auth_core` - Shared models and interfaces
- `shelf` - HTTP server framework
- `shelf_router` - HTTP routing
- `dart_jsonwebtoken` - JWT operations (RS256)
- `pointycastle` - Cryptography (Argon2id)
- `firedart` - Firestore client for Dart
- `uuid` - UUID generation

## Deployment

This service is designed for deployment on Google Cloud Run:

1. Build Docker container
2. Configure environment variables (see Configuration)
3. Deploy to Cloud Run with:
   - Min instances: 0 (scale to zero)
   - Max instances: 10
   - CPU: Always allocated
   - Memory: 512Mi
   - Timeout: 60s

## Security Considerations

- **Password Security**: Passwords are hashed client-side with Argon2id before transmission
- **Rate Limiting**: 5 attempts per minute prevents brute force attacks
- **Account Lockout**: 15 minutes after 5 failed attempts
- **JWT Expiry**: Tokens expire after 15 minutes (must be refreshed)
- **Transport Security**: HTTPS required (enforced by Cloud Run)
- **CORS**: Configured for web client origin only

## License

Internal use only - Clinical Trial Diary Platform
