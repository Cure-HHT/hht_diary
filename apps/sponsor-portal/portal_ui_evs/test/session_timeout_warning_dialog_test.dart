// Verifies: DIARY-GUI-portal-session-expiry/A+B
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/session_timeout_controller.dart';
import 'package:portal_ui_evs/src/session_timeout_warning_dialog.dart';

void main() {
  testWidgets('renders the countdown and extends on Stay signed in', (
    tester,
  ) async {
    var kept = 0;
    var signedOut = 0;
    final c = SessionTimeoutController(
      idleTimeout: const Duration(minutes: 10),
      warningLead: const Duration(seconds: 60),
      onKeepAlive: () async => kept++,
      onExpired: () async {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionTimeoutWarningDialog(
            controller: c,
            onSignOut: () => signedOut++,
          ),
        ),
      ),
    );

    expect(find.textContaining('Session'), findsWidgets);
    await tester.tap(find.byKey(const Key('stay-signed-in-button')));
    await tester.pump();
    expect(kept, 1, reason: 'Stay signed in fires the keep-alive');
    expect(signedOut, 0, reason: 'Stay signed in must not trigger sign-out');

    await tester.tap(find.byKey(const Key('sign-out-button')));
    await tester.pump();
    expect(signedOut, 1, reason: 'Sign out button invokes onSignOut callback');
    expect(kept, 1, reason: 'Sign out must not fire keep-alive');
    c.dispose();
  });
}
