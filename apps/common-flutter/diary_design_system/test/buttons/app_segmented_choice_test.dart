import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child, {Size size = const Size(320, 640)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: buildAppTheme(font: AppFontFamily.inter),
      home: Scaffold(
        body: SizedBox(width: size.width, child: child),
      ),
    ),
  );
}

void main() {
  group('AppSegmentedChoice', () {
    const options = [
      AppChoiceOption(value: 0, label: 'Yes'),
      AppChoiceOption(value: 1, label: 'No'),
      AppChoiceOption(value: 2, label: "Don't remember"),
    ];

    testWidgets('renders one AppButton per option', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppSegmentedChoice<int>(
            options: options,
            value: null,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(AppButton), findsNWidgets(3));
    });

    testWidgets(
      'default (equal-width) lays segments out in a Row, not a Wrap',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            AppSegmentedChoice<int>(
              options: options,
              value: null,
              onChanged: (_) {},
            ),
          ),
        );
        expect(find.byType(Wrap), findsNothing);
        expect(find.byType(Expanded), findsNWidgets(3));
      },
    );

    // CUR-1491: shrinkLabelToFit keeps the equal-width segment layout but
    // scales a long label like "Don't remember" down (smaller font) so it
    // fits its third of the row on one line instead of truncating to
    // "Don't re...".
    testWidgets('shrinkLabelToFit shows the full "Don\'t remember" label '
        'scaled to fit, without truncation, on a narrow screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _harness(
          AppSegmentedChoice<int>(
            options: options,
            value: null,
            shrinkLabelToFit: true,
            onChanged: (_) {},
          ),
        ),
      );

      // The equal-width layout is unchanged — segments stay a Row of three
      // Expanded thirds (no Wrap, no resizing).
      expect(find.byType(Wrap), findsNothing);
      expect(find.byType(Expanded), findsNWidgets(3));
      // Each segment label is wrapped in a scale-down FittedBox.
      expect(find.byType(FittedBox), findsNWidgets(3));
      // The full label renders on a single line without ellipsis truncation
      // (it is scaled down rather than cut off).
      expect(find.text("Don't remember"), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text("Don't remember"),
      );
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'the full label must render scaled, not ellipsis-truncated',
      );
    });

    testWidgets('fires onChanged with the tapped option value', (tester) async {
      int? tapped;
      await tester.pumpWidget(
        _harness(
          AppSegmentedChoice<int>(
            options: options,
            value: null,
            shrinkLabelToFit: true,
            onChanged: (v) => tapped = v,
          ),
        ),
      );
      await tester.tap(find.text("Don't remember"));
      await tester.pump();
      expect(tapped, 2);
    });
  });
}
