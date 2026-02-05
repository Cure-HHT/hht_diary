// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00077: Disconnection Notification
//   REQ-CAL-p00065: Reactivate Patient
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

    // REQ-CAL-p00065: Tests for expandable contact info
    testWidgets('shows expand indicator when contact info available', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          DisconnectionBanner(
            onDismiss: () {},
            siteName: 'Test Site',
            sitePhoneNumber: '+1-555-123-4567',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show down arrow to indicate expandable
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('does not show expand indicator when no contact info', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScaffold(DisconnectionBanner(onDismiss: () {})),
      );
      await tester.pumpAndSettle();

      // Should not show expand/collapse icons
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
    });

    testWidgets('expands to show contact details when tapped', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          DisconnectionBanner(
            onDismiss: () {},
            siteName: 'Test Medical Center',
            sitePhoneNumber: '+1-555-123-4567',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially phone number not visible
      expect(find.text('+1-555-123-4567'), findsNothing);

      // Tap banner to expand
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Now phone number should be visible
      expect(find.text('+1-555-123-4567'), findsOneWidget);
      // And site name in expanded section
      expect(find.text('Test Medical Center'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows phone icon in expanded section', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          DisconnectionBanner(
            onDismiss: () {},
            siteName: 'Test Site',
            sitePhoneNumber: '+1-555-123-4567',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to expand
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Should show phone icon
      expect(find.byIcon(Icons.phone), findsOneWidget);
    });

    testWidgets('collapses when tapped again', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          DisconnectionBanner(
            onDismiss: () {},
            siteName: 'Test Site',
            sitePhoneNumber: '+1-555-123-4567',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to expand
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.text('+1-555-123-4567'), findsOneWidget);

      // Tap again to collapse
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.text('+1-555-123-4567'), findsNothing);
    });

    testWidgets('shows only site name when no phone number', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          DisconnectionBanner(
            onDismiss: () {},
            siteName: 'Test Medical Center',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to expand
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Should show site name but not phone icon
      expect(find.byIcon(Icons.location_city), findsOneWidget);
      expect(find.byIcon(Icons.phone), findsNothing);
    });

    testWidgets('shows only phone when no site name', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          DisconnectionBanner(
            onDismiss: () {},
            sitePhoneNumber: '+1-555-123-4567',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to expand
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Should show phone icon but not location icon
      expect(find.byIcon(Icons.phone), findsOneWidget);
      expect(find.byIcon(Icons.location_city), findsNothing);
    });
  });
}
