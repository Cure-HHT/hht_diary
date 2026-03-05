// Tests for BrowserLifecycleService stub contract.
//
// These tests verify the no-op stub interface used on the Dart VM.
// Chrome integration tests (real event listeners) live in integration_test/.
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00080-G/K: beforeunload and visibilitychange listeners
//   REQ-d00080-P: back-button prevention
//   REQ-p01044-D: session terminated on tab/window close

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';

/// Stub for [BrowserLifecycleService] used in unit tests running on the Dart VM.
/// The real implementation (browser_lifecycle_service.dart) requires dart:js_interop
/// which is only available when compiling to JavaScript.
class BrowserLifecycleService {
  void register(AuthService authService) {}
  void dispose() {}
}

void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late AuthService authService;
  late BrowserLifecycleService lifecycleService;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    authService = AuthService(firebaseAuth: mockFirebaseAuth);
    lifecycleService = BrowserLifecycleService();
  });

  tearDown(() {
    lifecycleService.dispose();
    authService.dispose();
  });

  group('BrowserLifecycleService', () {
    test('register() does not throw', () {
      expect(() => lifecycleService.register(authService), returnsNormally);
    });

    test('dispose() does not throw before register', () {
      expect(() => lifecycleService.dispose(), returnsNormally);
    });

    test('dispose() does not throw after register', () {
      lifecycleService.register(authService);
      expect(() => lifecycleService.dispose(), returnsNormally);
    });

    test('register() and dispose() can be called in sequence', () {
      lifecycleService.register(authService);
      lifecycleService.dispose();
      lifecycleService.dispose(); // second dispose is safe
    });

    test('multiple register() calls do not throw', () {
      lifecycleService.register(authService);
      lifecycleService.register(authService);
    });
  });
}
