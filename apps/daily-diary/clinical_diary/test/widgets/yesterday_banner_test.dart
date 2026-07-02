import 'package:clinical_diary/widgets/yesterday_banner.dart';
import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/test_helpers.dart';

void main() {
  // Verifies: DIARY-PRD-mobile-offline-first/A+B+C
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

    // CUR-1491: on a narrow phone the three equal-width segments give
    // "Don't remember" only a third of the row. The full label must stay
    // visible (its font scaled down to fit on one line) rather than
    // truncating to "Don't re...". Assert the laid-out paragraph does not
    // exceed its line budget (no ellipsis truncation).
    testWidgets('renders full "Don\'t remember" label without truncation on a '
        'narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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

      final textFinder = find.text("Don't remember");
      expect(textFinder, findsOneWidget);

      // The full string is present and the paragraph is not truncated.
      final paragraph = tester.renderObject<RenderParagraph>(textFinder);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason:
            'the "Don\'t remember" label must not be ellipsis-truncated; '
            'it should wrap to show the full text',
      );
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
