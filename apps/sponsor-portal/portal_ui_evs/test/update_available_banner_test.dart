import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/update_available_banner.dart';

void main() {
  Widget host({required bool visible, required VoidCallback onReload}) =>
      MaterialApp(
        home: Scaffold(
          body: UpdateAvailableBanner(
            visible: visible,
            onReload: onReload,
            child: const Text('body'),
          ),
        ),
      );

  // Verifies: DIARY-GUI-portal-stale-client-reload/A
  testWidgets('renders the strip and a Reload control when visible', (
    tester,
  ) async {
    await tester.pumpWidget(host(visible: true, onReload: () {}));
    expect(find.byKey(const Key('update-available-banner')), findsOneWidget);
    expect(find.text('A new version is available.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Reload'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('hidden when not visible', (tester) async {
    await tester.pumpWidget(host(visible: false, onReload: () {}));
    expect(find.byKey(const Key('update-available-banner')), findsNothing);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('Reload invokes the callback', (tester) async {
    var reloaded = 0;
    await tester.pumpWidget(host(visible: true, onReload: () => reloaded++));
    await tester.tap(find.widgetWithText(TextButton, 'Reload'));
    expect(reloaded, 1);
  });
}
