import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/stale_client.dart';

void main() {
  const client = '1.4.0+abc1234';
  const newer = '1.5.0+def5678';

  group('isClientStale', () {
    // Verifies: DIARY-GUI-portal-stale-client-reload/A
    test('true when server portal_ui_version differs from this bundle', () {
      expect(
        isClientStale(
          clientVersion: client,
          serverVersions: const {'portal_ui_version': newer},
        ),
        isTrue,
      );
    });

    test('false when server reports the same version (matched build)', () {
      expect(
        isClientStale(
          clientVersion: client,
          serverVersions: const {'portal_ui_version': client},
        ),
        isFalse,
      );
    });

    test('false when this bundle has no compiled version (local dev run)', () {
      expect(
        isClientStale(
          clientVersion: '',
          serverVersions: const {'portal_ui_version': newer},
        ),
        isFalse,
      );
    });

    test(
      'false when /health omits portal_ui_version (unreachable/partial)',
      () {
        expect(
          isClientStale(
            clientVersion: client,
            serverVersions: const {'deploy': '47'},
          ),
          isFalse,
        );
      },
    );

    test('false when portal_ui_version is empty', () {
      expect(
        isClientStale(
          clientVersion: client,
          serverVersions: const {'portal_ui_version': ''},
        ),
        isFalse,
      );
    });
  });

  group('decideStaleClientAction', () {
    // AC: older build + authenticated -> reload BANNER (prompt, not auto).
    // Verifies: DIARY-GUI-portal-stale-client-reload/A+C
    test('older build, authenticated -> banner', () {
      expect(
        decideStaleClientAction(
          clientVersion: client,
          serverVersions: const {'portal_ui_version': newer},
          authenticated: true,
          autoReloadAlreadyTried: false,
        ),
        StaleClientAction.banner,
      );
    });

    // AC: older build + login screen (unauthenticated) -> auto-reload.
    // Verifies: DIARY-GUI-portal-stale-client-reload/B
    test('older build, login screen -> reload', () {
      expect(
        decideStaleClientAction(
          clientVersion: client,
          serverVersions: const {'portal_ui_version': newer},
          authenticated: false,
          autoReloadAlreadyTried: false,
        ),
        StaleClientAction.reload,
      );
    });

    // AC: never auto-reload an authenticated user, even after a prior reload.
    // Verifies: DIARY-GUI-portal-stale-client-reload/C
    test('authenticated never reloads regardless of guard state', () {
      expect(
        decideStaleClientAction(
          clientVersion: client,
          serverVersions: const {'portal_ui_version': newer},
          authenticated: true,
          autoReloadAlreadyTried: true,
        ),
        StaleClientAction.banner,
      );
    });

    // Loop guard: a reload that came back still-stale must NOT reload again.
    // Verifies: DIARY-DEV-portal-legacy-sw-eviction/B
    test('login screen, auto-reload already tried -> banner (no loop)', () {
      expect(
        decideStaleClientAction(
          clientVersion: client,
          serverVersions: const {'portal_ui_version': newer},
          authenticated: false,
          autoReloadAlreadyTried: true,
        ),
        StaleClientAction.banner,
      );
    });

    // AC: reloading lands on the new build -> no further action.
    test('matched version -> none (authenticated or not)', () {
      for (final authed in [true, false]) {
        expect(
          decideStaleClientAction(
            clientVersion: client,
            serverVersions: const {'portal_ui_version': client},
            authenticated: authed,
            autoReloadAlreadyTried: false,
          ),
          StaleClientAction.none,
        );
      }
    });
  });
}
