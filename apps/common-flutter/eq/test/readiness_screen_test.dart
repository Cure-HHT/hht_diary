import 'package:eq/eq.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Verifies: DIARY-GUI-questionnaire-portal-sent-workflow/A+B+C
void main() {
  testWidgets('shows questionnaire name', (tester) async {
    final def = noseHhtDefinition();
    await tester.pumpWidget(
      wrapWithMaterialApp(
        ReadinessScreen(definition: def, onReady: () {}, onDefer: () {}),
      ),
    );

    expect(find.text('NOSE HHT Survey'), findsOneWidget);
  });

  testWidgets('shows estimated time', (tester) async {
    final def = noseHhtDefinition();
    await tester.pumpWidget(
      wrapWithMaterialApp(
        ReadinessScreen(definition: def, onReady: () {}, onDefer: () {}),
      ),
    );

    expect(find.text('Estimated time: 10-12 minutes'), findsOneWidget);
  });

  testWidgets('shows readiness message', (tester) async {
    final def = noseHhtDefinition();
    await tester.pumpWidget(
      wrapWithMaterialApp(
        ReadinessScreen(definition: def, onReady: () {}, onDefer: () {}),
      ),
    );

    expect(
      find.textContaining('Please ensure you have enough'),
      findsOneWidget,
    );
  });

  testWidgets('calls onReady when "I\'m ready" tapped', (tester) async {
    var readyCalled = false;
    final def = noseHhtDefinition();
    await tester.pumpWidget(
      wrapWithMaterialApp(
        ReadinessScreen(
          definition: def,
          onReady: () => readyCalled = true,
          onDefer: () {},
        ),
      ),
    );

    await tester.tap(find.text("I'm ready"));
    expect(readyCalled, isTrue);
  });

  testWidgets('calls onDefer when "Not now" tapped', (tester) async {
    var deferCalled = false;
    final def = noseHhtDefinition();
    await tester.pumpWidget(
      wrapWithMaterialApp(
        ReadinessScreen(
          definition: def,
          onReady: () {},
          onDefer: () => deferCalled = true,
        ),
      ),
    );

    await tester.tap(find.text('Not now'));
    expect(deferCalled, isTrue);
  });
}
