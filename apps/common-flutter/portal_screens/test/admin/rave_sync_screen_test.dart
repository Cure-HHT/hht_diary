import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    RaveSyncView? status,
    bool isLoading = false,
    VoidCallback? onUnwedge,
    bool unwedging = false,
  }) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(font: AppFontFamily.inter),
        home: Scaffold(
          body: RaveSyncScreen(
            status: status,
            isLoading: isLoading,
            onUnwedge: onUnwedge,
            unwedging: unwedging,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('healthy status renders the OK banner + detail rows', (
    tester,
  ) async {
    await pump(
      tester,
      status: const RaveSyncView(
        health: RaveSyncHealth.ok,
        lastSuccessAt: '2026-06-13T10:00:00Z',
        sitesCount: 3,
        participantsCount: 12,
      ),
    );
    expect(find.text('RAVE Sync'), findsOneWidget);
    expect(find.text('Sync healthy'), findsOneWidget);
    expect(find.text('Last successful sync'), findsOneWidget);
    expect(find.textContaining('3 sites, 12 participants'), findsOneWidget);
  });

  testWidgets('locked status renders the locked banner', (tester) async {
    await pump(
      tester,
      status: const RaveSyncView(
        health: RaveSyncHealth.locked,
        consecutiveAuthFailures: 3,
      ),
    );
    expect(find.text('Locked — sync is wedged'), findsOneWidget);
    expect(find.text('3'), findsWidgets); // consecutive auth failures
  });

  testWidgets('null/empty status reads as healthy', (tester) async {
    await pump(tester, status: null);
    expect(find.text('Sync healthy'), findsOneWidget);
    // Timestamps fall back to em-dash.
    expect(find.textContaining('—'), findsWidgets);
  });

  testWidgets('Unwedge hidden when onUnwedge is null', (tester) async {
    await pump(
      tester,
      status: const RaveSyncView(health: RaveSyncHealth.locked),
    );
    expect(find.text('Unwedge RAVE Sync'), findsNothing);
  });

  testWidgets('Unwedge shown + fires when onUnwedge provided', (tester) async {
    var fired = 0;
    await pump(
      tester,
      status: const RaveSyncView(health: RaveSyncHealth.locked),
      onUnwedge: () => fired++,
    );
    expect(find.text('Unwedge RAVE Sync'), findsOneWidget);
    await tester.tap(find.text('Unwedge RAVE Sync'));
    expect(fired, 1);
  });

  testWidgets('Unwedge disabled while unwedging', (tester) async {
    await pump(
      tester,
      status: const RaveSyncView(health: RaveSyncHealth.locked),
      onUnwedge: () {},
      unwedging: true,
    );
    // loading swaps the label for a spinner; assert the button is disabled.
    final button = tester.widget<AppButton>(
      find.byWidgetPredicate(
        (w) => w is AppButton && w.semanticId == 'rave-unwedge',
      ),
    );
    expect(button.onPressed, isNull, reason: 'disabled mid-dispatch');
  });

  testWidgets('loading shows a spinner before the first emission', (
    tester,
  ) async {
    await pump(tester, status: null, isLoading: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
