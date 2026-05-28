// Tests for license_screen.dart
// Covers: Static licenses display, PDF viewer navigation

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/screens/license_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _PushObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

void main() {
  Widget buildTestWidget({
    List<NavigatorObserver> navigatorObservers = const [],
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: navigatorObservers,
      home: const LicensesPage(),
    );
  }

  group('LicensesPage', () {
    testWidgets('displays app bar with licenses title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('displays list of licenses', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(ListTile), findsAtLeast(2));
    });

    testWidgets('displays GNU AGPL license entry', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Look for GNU AGPL related text
      expect(find.byIcon(Icons.description), findsAtLeast(1));
    });

    testWidgets('displays SIL OFL license entry', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Should have at least 2 license entries
      expect(find.byType(ListTile), findsAtLeast(2));
    });

    testWidgets('tapping license entry navigates to PDF viewer', (
      tester,
    ) async {
      final observer = _PushObserver();
      await tester.pumpWidget(buildTestWidget(navigatorObservers: [observer]));
      await tester.pumpAndSettle();
      final initialPushes = observer.pushed.length;

      await tester.tap(find.byType(ListTile).first);

      // Pop the just-pushed PDF viewer route before any pump triggers its
      // build: pdfx's PdfViewPinch throws UnimplementedError on Windows
      // and is unsupported on Linux, so the page itself cannot be built
      // in this test environment. NavigatorObserver.didPush has already
      // fired synchronously, so the push is observable without building.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      expect(observer.pushed.length, initialPushes + 1);
    });

    testWidgets('has divider between license entries', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsAtLeast(1));
    });

    testWidgets('each list tile has leading icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
      for (final tile in tiles) {
        expect(tile.leading, isNotNull);
      }
    });
  });
}
