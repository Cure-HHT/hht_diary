// Tests for browser storage injectable behavior.
//
// Verifies the clearStorage injection contract in AuthService.
// Timer-based inactivity timeout tests live in auth_service_test.dart.
//
// On Chrome (flutter test --platform chrome) the real clearBrowserStorage from
// browser_storage_web.dart can be injected and exercised against a live browser.
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00083: Client-Side Storage Clearing
//   REQ-p01044-J/K/L/M: clear all client-side storage on logout

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponsor_portal_ui/services/auth_service.dart';

void main() {
  group('clearStorage injectable', () {
    test('default no-op completes without error on signOut', () async {
      // AuthService default clearStorage is a no-op (web impl injected by main.dart).
      final auth = AuthService(firebaseAuth: MockFirebaseAuth());
      await expectLater(auth.signOut(), completes);
      auth.dispose();
    });

    test('custom clearStorage is called during explicit signOut', () async {
      var called = false;
      final auth = AuthService(
        firebaseAuth: MockFirebaseAuth(),
        clearStorage: () async {
          called = true;
        },
      );

      await auth.signOut();

      expect(called, isTrue);
      auth.dispose();
    });
  });
}
