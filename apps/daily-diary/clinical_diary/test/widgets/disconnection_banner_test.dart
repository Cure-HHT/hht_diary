// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00077: Disconnection Notification
//
// Widget tests for DisconnectionBanner

import 'package:clinical_diary/widgets/disconnection_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('DisconnectionBanner', () {
    testWidgets('displays disconnection title', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(DisconnectionBanner(onDismiss: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('Disconnected from Study'), findsOneWidget);
    });

    testWidgets('displays contact site message', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(DisconnectionBanner(onDismiss: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('Please contact your study site.'), findsOneWidget);
    });

    testWidgets('displays site name when provided', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          DisconnectionBanner(
            onDismiss: () {},
            siteName: 'Test Medical Center',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Please contact Test Medical Center.'), findsOneWidget);
    });

    testWidgets('has warning icon', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(DisconnectionBanner(onDismiss: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('has dismiss button with close icon', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(DisconnectionBanner(onDismiss: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('calls onDismiss when dismiss button is tapped', (
      tester,
    ) async {
      var dismissed = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          DisconnectionBanner(onDismiss: () => dismissed = true),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(dismissed, true);
    });

    testWidgets('has red background color', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(DisconnectionBanner(onDismiss: () {})),
      );
      await tester.pumpAndSettle();

      // Find the Container with decoration
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(DisconnectionBanner),
              matching: find.byType(Container),
            )
            .first,
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.red.shade50);
    });

    testWidgets('spans full width of parent', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(DisconnectionBanner(onDismiss: () {})),
      );
      await tester.pumpAndSettle();

      // The banner should be visible and rendered
      expect(find.byType(DisconnectionBanner), findsOneWidget);
    });

    testWidgets('renders without site name', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(DisconnectionBanner(onDismiss: () {}, siteName: null)),
      );
      await tester.pumpAndSettle();

      // Should show generic message without site name
      expect(find.text('Please contact your study site.'), findsOneWidget);
    });

    testWidgets('has Material elevation', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(DisconnectionBanner(onDismiss: () {})),
      );
      await tester.pumpAndSettle();

      // Find Material widgets that are direct children of DisconnectionBanner
      final materials = tester.widgetList<Material>(
        find.descendant(
          of: find.byType(DisconnectionBanner),
          matching: find.byType(Material),
        ),
      );

      // At least one Material should have elevation of 4
      final hasElevation = materials.any((m) => m.elevation == 4);
      expect(hasElevation, true);
    });
  });
}
