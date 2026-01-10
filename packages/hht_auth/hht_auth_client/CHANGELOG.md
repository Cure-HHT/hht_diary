# Changelog

All notable changes to the hht_auth_client package will be documented in this file.

## [0.1.0] - 2025-12-04

### Added - Initial Implementation

#### Core Authentication (REQ-d00078)
- WebAuthService: HTTP-based auth service client
- AuthHttpClient: HTTP client with automatic JWT token injection
- Support for registration, login, token refresh, password change
- Linking code validation
- Sponsor configuration retrieval

#### Session Management (REQ-d00080)
- WebSessionManager: Configurable session timeout (1-30 minutes, default 2)
- InactivityTracker: User activity monitoring (mouse, keyboard, touch)
- Session state transitions (inactive → active → warning → expired)
- Warning notification 30 seconds before expiry
- Session extension on user activity

#### Password Security (REQ-d00082)
- Argon2PasswordHasher: Client-side Argon2id implementation
- OWASP-recommended parameters (64MB memory, 3 iterations, 4 parallelism)
- Cryptographically secure salt generation
- Constant-time password verification (timing attack prevention)
- Base64 encoding for hash and salt

#### Storage Clearing (REQ-d00083)
- StorageClearer: Comprehensive browser storage cleanup
- localStorage clearing
- sessionStorage clearing
- Cookie deletion (multiple domain variations)
- IndexedDB database deletion
- Cache Storage clearing

#### Sponsor Configuration (REQ-d00084)
- SponsorConfigLoader: HTTP-based config fetching
- In-memory caching (no persistence)
- Dynamic sponsor configuration loading

#### Storage
- WebTokenStorage: In-memory token storage (no localStorage for security)

#### State Management
- AuthState: Immutable state model
- AuthStateNotifier: Base state management logic
- SignalsAuthAdapter: Signals integration
- RiverpodAuthAdapter: Riverpod integration with providers

#### Testing Utilities
- FakeWebSessionManager: Controllable fake for testing
- MockHttpClient: Mock HTTP responses for testing

### Testing
- 51+ comprehensive unit tests across 4 test files
- TDD approach (red-green-refactor) throughout implementation
- Test coverage for all core components

### Documentation
- Comprehensive README with usage examples
- Inline documentation for all public APIs
- Implementation summary with architecture details
- This changelog

### Dependencies
- hht_auth_core: Core models and interfaces
- http: HTTP client
- pointycastle: Argon2id implementation
- signals_core: Signals state management
- flutter_riverpod: Riverpod state management

### Security Features
- In-memory token storage only (no localStorage)
- Client-side password hashing before network transmission
- Comprehensive browser storage clearing on logout
- Constant-time password comparison
- Automatic JWT token injection
- Configurable session timeout

### Browser Compatibility
- Chrome (latest 2 versions)
- Firefox (latest 2 versions)
- Safari (latest 2 versions)
- Edge (latest 2 versions)

## [Unreleased]

### Planned
- Browser-specific tests for StorageClearer
- Integration tests for complete authentication flows
- Performance benchmarks for Argon2id hashing
- Additional WebSessionManager tests for timer behavior
- Cross-browser testing automation
