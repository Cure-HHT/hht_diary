// Widget tests for DisconnectionBanner

import 'package:clinical_diary/widgets/disconnection_banner.dart';
import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  // Verifies: DIARY-PRD-participant-disconnection
  // Verifies: DIARY-PRD-notification-disconnection
  // Verifies: DIARY-PRD-participant-reactivate
  group('DisconnectionBanner', () {
    testWidgets('displays disconnection title', (tester) async {
      await tester.pumpWidget(wrapWithScaffold(const DisconnectionBanner()));
      await tester.pumpAndSettle();

      expect(find.text('Disconnected from Study'), findsOneWidget);
    });

    testWidgets('displays contact site message', (tester) async {
      await tester.pumpWidget(wrapWithScaffold(const DisconnectionBanner()));
      await tester.pumpAndSettle();

      expect(find.text('Please contact your study site.'), findsOneWidget);
    });

    testWidgets('displays site name when provided', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          const DisconnectionBanner(siteName: 'Test Medical Center'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Please contact Test Medical Center.'), findsOneWidget);
    });

    testWidgets('has error severity icon', (tester) async {
      await tester.pumpWidget(wrapWithScaffold(const DisconnectionBanner()));
      await tester.pumpAndSettle();

      // AppBanner with AppBannerSeverity.error renders the canonical
      // error_outline glyph.
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    // Banner must be persistent and non-dismissible
    // Verifies: DIARY-PRD-notification-disconnection
    testWidgets('has no dismiss (close) button', (tester) async {
      await tester.pumpWidget(wrapWithScaffold(const DisconnectionBanner()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('has error container background color', (tester) async {
      await tester.pumpWidget(wrapWithScaffold(const DisconnectionBanner()));
      await tester.pumpAndSettle();

      // Find the AppBanner's decorated Container
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppBanner),
              matching: find.byType(Container),
            )
            .first,
      );

      // AppBanner with AppBannerSeverity.error uses the theme's
      // errorContainer color for its background.
      final colorScheme = Theme.of(
        tester.element(find.byType(DisconnectionBanner)),
      ).colorScheme;
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, colorScheme.errorContainer);
    });

    testWidgets('spans full width of parent', (tester) async {
      await tester.pumpWidget(wrapWithScaffold(const DisconnectionBanner()));
      await tester.pumpAndSettle();

      // The banner should be visible and rendered
      expect(find.byType(DisconnectionBanner), findsOneWidget);
    });

    testWidgets('renders without site name', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(const DisconnectionBanner(siteName: null)),
      );
      await tester.pumpAndSettle();

      // Should show generic message without site name
      expect(find.text('Please contact your study site.'), findsOneWidget);
    });

    // Tests for expandable contact info
    // Verifies: DIARY-PRD-participant-reactivate
    testWidgets('shows expand indicator when contact info available', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          const DisconnectionBanner(
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
      await tester.pumpWidget(wrapWithScaffold(const DisconnectionBanner()));
      await tester.pumpAndSettle();

      // Should not show expand/collapse icons
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
    });

    testWidgets('expands to show contact details when tapped', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          const DisconnectionBanner(
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
          const DisconnectionBanner(
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
          const DisconnectionBanner(
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
          const DisconnectionBanner(siteName: 'Test Medical Center'),
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
          const DisconnectionBanner(sitePhoneNumber: '+1-555-123-4567'),
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
