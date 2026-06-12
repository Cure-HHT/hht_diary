// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/widgets/yesterday_banner.dart';
import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('YesterdayBanner', () {
    testWidgets('displays yesterday date', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          YesterdayBanner(
            onNoNosebleeds: () {},
            onHadNosebleeds: () {},
            onDontRemember: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final dateStr = DateFormat('MMM d').format(yesterday);

      expect(find.textContaining(dateStr), findsOneWidget);
    });

    testWidgets('displays confirmation title', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          YesterdayBanner(
            onNoNosebleeds: () {},
            onHadNosebleeds: () {},
            onDontRemember: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Confirm Yesterday'), findsOneWidget);
    });

    testWidgets('displays question text', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          YesterdayBanner(
            onNoNosebleeds: () {},
            onHadNosebleeds: () {},
            onDontRemember: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Did you have nosebleeds?'), findsOneWidget);
    });

    testWidgets('displays Yes button', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          YesterdayBanner(
            onNoNosebleeds: () {},
            onHadNosebleeds: () {},
            onDontRemember: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Yes'), findsOneWidget);
    });

    testWidgets('displays No button', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          YesterdayBanner(
            onNoNosebleeds: () {},
            onHadNosebleeds: () {},
            onDontRemember: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No'), findsOneWidget);
    });

    testWidgets('displays Dont remember button', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          YesterdayBanner(
            onNoNosebleeds: () {},
            onHadNosebleeds: () {},
            onDontRemember: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Don't remember"), findsOneWidget);
    });

    testWidgets('calls onHadNosebleeds when Yes is tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          YesterdayBanner(
            onNoNosebleeds: () {},
            onHadNosebleeds: () => called = true,
            onDontRemember: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yes'));
      await tester.pump();

      expect(called, true);
    });

    testWidgets('calls onNoNosebleeds when No is tapped', (tester) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          YesterdayBanner(
            onNoNosebleeds: () => called = true,
            onHadNosebleeds: () {},
            onDontRemember: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('No'));
      await tester.pump();

      expect(called, true);
    });

    testWidgets('calls onDontRemember when Dont remember is tapped', (
      tester,
    ) async {
      var called = false;

      await tester.pumpWidget(
        wrapWithScaffold(
          YesterdayBanner(
            onNoNosebleeds: () {},
            onHadNosebleeds: () {},
            onDontRemember: () => called = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Don't remember"));
      await tester.pump();

      expect(called, true);
    });

    testWidgets('has three action buttons', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          YesterdayBanner(
            onNoNosebleeds: () {},
            onHadNosebleeds: () {},
            onDontRemember: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The Yes / No / Don't remember actions render via the design-system
      // AppSegmentedChoice, one AppButton per option.
      expect(find.bySubtype<AppSegmentedChoice<dynamic>>(), findsOneWidget);
      expect(find.byType(AppButton), findsNWidgets(3));
    });

    testWidgets('No button has check icon', (tester) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          YesterdayBanner(
            onNoNosebleeds: () {},
            onHadNosebleeds: () {},
            onDontRemember: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('has primary soft background from design tokens', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithScaffold(
          YesterdayBanner(
            onNoNosebleeds: () {},
            onHadNosebleeds: () {},
            onDontRemember: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(YesterdayBanner),
              matching: find.byType(Container),
            )
            .first,
      );

      // Banner surface comes from the AppSemanticColors theme extension.
      final semantic = Theme.of(
        tester.element(find.byType(YesterdayBanner)),
      ).extension<AppSemanticColors>()!;
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, semantic.primaryLightSoft);
    });
  });
}
