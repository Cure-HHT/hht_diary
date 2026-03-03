// IMPLEMENTS REQUIREMENTS:
//   REQ-p01070: NOSE HHT Questionnaire UI

import 'package:eq/eq.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trial_data_types/trial_data_types.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('displays preamble content', (tester) async {
    await tester.pumpWidget(
      wrapWithMaterialApp(
        PreambleScreen(
          preamble: const PreambleItem(
            id: 'test',
            content: 'Test preamble text',
          ),
          currentIndex: 0,
          totalCount: 3,
          onContinue: () {},
        ),
      ),
    );

    expect(find.text('Test preamble text'), findsOneWidget);
  });

  testWidgets('shows page indicator', (tester) async {
    await tester.pumpWidget(
      wrapWithMaterialApp(
        PreambleScreen(
          preamble: const PreambleItem(id: 'test', content: 'Content'),
          currentIndex: 1,
          totalCount: 3,
          onContinue: () {},
        ),
      ),
    );

    expect(find.text('2 of 3'), findsOneWidget);
  });

  testWidgets('hides page indicator when only 1 preamble', (tester) async {
    await tester.pumpWidget(
      wrapWithMaterialApp(
        PreambleScreen(
          preamble: const PreambleItem(id: 'test', content: 'Content'),
          currentIndex: 0,
          totalCount: 1,
          onContinue: () {},
        ),
      ),
    );

    expect(find.text('1 of 1'), findsNothing);
  });

  testWidgets('calls onContinue when Continue tapped', (tester) async {
    var continueCalled = false;
    await tester.pumpWidget(
      wrapWithMaterialApp(
        PreambleScreen(
          preamble: const PreambleItem(id: 'test', content: 'Content'),
          currentIndex: 0,
          totalCount: 1,
          onContinue: () => continueCalled = true,
        ),
      ),
    );

    await tester.tap(find.text('Continue'));
    expect(continueCalled, isTrue);
  });
}
