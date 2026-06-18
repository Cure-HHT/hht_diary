// IMPLEMENTS REQUIREMENTS:
//   REQ-d00006: Mobile App Build and Release Process
//   REQ-o00043: Automated Deployment Pipeline
//
// Minimal, deterministic on-device smoke coverage for Firebase Test Lab.
// This intentionally uses synthetic/unlinked local state and does not require
// patient credentials, participant identifiers, or production data.

import 'dart:io';

import 'package:clinical_diary/main.dart' as app;
import 'package:clinical_diary/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String description,
  Duration timeout = const Duration(minutes: 2),
  Duration interval = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(interval);
    if (condition()) {
      return;
    }
  }

  fail('Timed out waiting for $description');
}

void main() {
  // The normal Clinical Diary CI discovers every integration_test/*_test.dart
  // target and runs it on a desktop platform. This smoke test is intentionally
  // device-only because it starts the full app and captures a Test Lab
  // screenshot. Register a skipped placeholder on desktop before initializing
  // the integration-test binding so Linux/macOS/Windows CI cannot hang here.
  if (!Platform.isAndroid && !Platform.isIOS) {
    test(
      'Clinical Diary Firebase Test Lab smoke test is device-only',
      () {},
      skip: 'Runs only on Android or iOS Firebase Test Lab devices.',
    );
    return;
  }

  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Clinical Diary starts and renders the Home screen', (
    WidgetTester tester,
  ) async {
    app.main();

    await _pumpUntil(tester, () {
      final homeScreenFound = find.byType(HomeScreen).evaluate().isNotEmpty;
      final bootstrapErrorFound = find
          .textContaining('Failed to initialize storage')
          .evaluate()
          .isNotEmpty;

      return homeScreenFound || bootstrapErrorFound;
    }, description: 'the Home screen or a bootstrap error');

    expect(
      find.textContaining('Failed to initialize storage'),
      findsNothing,
      reason: 'The device-local datastore must initialize successfully.',
    );
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);

    // Android screenshots require converting the Flutter surface first.
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
    }

    await binding.takeScreenshot('firebase_test_lab_home');

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
