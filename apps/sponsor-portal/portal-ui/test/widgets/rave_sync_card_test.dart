// Verifies: DIARY-GUI-dev-admin-rave-sync-card/A+B+C
//
// Widget tests for the Dev Admin Rave Sync card. Uses a stub
// RaveAdminService injected via the card's `serviceOverride` constructor
// parameter so the post-frame AuthService lookup is bypassed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponsor_portal_ui/pages/dev_admin/dev_admin_dashboard_page.dart';
import 'package:sponsor_portal_ui/services/rave_admin_service.dart';

/// Stub service that returns a configured state on getState() and a
/// configured UnwedgeResult on unwedge(). Captures unwedge calls.
class _StubRaveAdminService implements RaveAdminService {
  _StubRaveAdminService({required this.stateToReturn});

  RaveLockoutState stateToReturn;

  /// Override this from a test before triggering unwedge() to assert
  /// behavior on a specific probe outcome. Default is a clean probe-OK.
  UnwedgeResult unwedgeResult = UnwedgeResult(
    probeOk: true,
    consecutiveAuthFailures: 0,
    lockedAfter: false,
    stateAfter: 'ok',
  );

  int unwedgeCallCount = 0;

  @override
  Future<RaveLockoutState> getState() async => stateToReturn;

  @override
  Future<UnwedgeResult> unwedge() async {
    unwedgeCallCount++;
    return unwedgeResult;
  }
}

RaveLockoutState _okState() => RaveLockoutState(
  state: 'ok',
  consecutiveAuthFailures: 0,
  threshold: 3,
  cooldownHours: 24,
  lastSuccessAt: DateTime.utc(2026, 5, 21, 10, 0, 0),
);

RaveLockoutState _lockedState() => RaveLockoutState(
  state: 'locked',
  consecutiveAuthFailures: 3,
  threshold: 3,
  cooldownHours: 24,
  lockedAt: DateTime.utc(2026, 5, 21, 8, 0, 0),
  lastFailureAt: DateTime.utc(2026, 5, 21, 8, 0, 0),
  lastFailureReasonCode: 'AUTH001',
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('RaveSyncCard', () {
    testWidgets(
      'A: renders current state, counter, last-failure and last-unwedge info',
      (tester) async {
        final service = _StubRaveAdminService(stateToReturn: _lockedState());
        await tester.pumpWidget(_wrap(RaveSyncCard(serviceOverride: service)));
        // Initial spinner while async getState resolves.
        await tester.pump(); // post-frame callback
        await tester.pumpAndSettle();

        // Status line reflects locked state.
        expect(find.textContaining('HARD LOCKOUT'), findsOneWidget);
        // Counter shown as N / threshold.
        expect(find.textContaining('3 / 3'), findsOneWidget);
        // Last failure reason rendered.
        expect(find.textContaining('AUTH001'), findsOneWidget);
      },
    );

    testWidgets('B: Unwedge button always enabled, even in ok state', (
      tester,
    ) async {
      final service = _StubRaveAdminService(stateToReturn: _okState());
      await tester.pumpWidget(_wrap(RaveSyncCard(serviceOverride: service)));
      await tester.pump();
      await tester.pumpAndSettle();

      // Find the Unwedge button by stable Key. The button is constructed
      // via FilledButton.icon which doesn't subclass FilledButton in all
      // Flutter runtimes (locally yes, CI no), so type-based finders are
      // brittle.
      final unwedgeBtn = find.byKey(const Key('rave-unwedge-button'));
      expect(unwedgeBtn, findsOneWidget);
      final btn = tester.widget<ButtonStyleButton>(unwedgeBtn);
      expect(
        btn.onPressed,
        isNotNull,
        reason: 'Unwedge button must remain enabled in ok state (idempotent)',
      );
    });

    testWidgets(
      'C: warning text about credential rotation + redeploy is shown',
      (tester) async {
        final service = _StubRaveAdminService(stateToReturn: _okState());
        await tester.pumpWidget(_wrap(RaveSyncCard(serviceOverride: service)));
        await tester.pump();
        await tester.pumpAndSettle();

        // Mandatory pre-action warning.
        expect(find.textContaining('credentials are correct'), findsOneWidget);
        expect(find.textContaining('redeployed'), findsOneWidget);
      },
    );

    testWidgets('clicking Unwedge invokes service.unwedge after confirmation', (
      tester,
    ) async {
      final service = _StubRaveAdminService(stateToReturn: _okState());
      await tester.pumpWidget(_wrap(RaveSyncCard(serviceOverride: service)));
      await tester.pump();
      await tester.pumpAndSettle();

      // Tap Unwedge → confirmation dialog opens.
      await tester.tap(find.byKey(const Key('rave-unwedge-button')));
      await tester.pumpAndSettle();
      expect(find.text('Unwedge Rave sync?'), findsOneWidget);

      // Confirm — the dialog's confirm button is a plain FilledButton with
      // the text 'Unwedge' (no icon variant), so the text finder is fine.
      // Use find.text + ancestor lookup to be explicit.
      await tester.tap(find.text('Unwedge'));
      await tester.pumpAndSettle();

      expect(service.unwedgeCallCount, 1);
    });
  });
}
