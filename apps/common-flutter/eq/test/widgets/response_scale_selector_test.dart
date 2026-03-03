// IMPLEMENTS REQUIREMENTS:
//   REQ-p01070: NOSE HHT Questionnaire UI

import 'package:eq/eq.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trial_data_types/trial_data_types.dart';

import '../test_helpers.dart';

void main() {
  const options = [
    ResponseScaleOption(value: 0, label: 'No problem'),
    ResponseScaleOption(value: 1, label: 'Mild problem'),
    ResponseScaleOption(value: 2, label: 'Moderate problem'),
    ResponseScaleOption(value: 3, label: 'Severe problem'),
    ResponseScaleOption(value: 4, label: 'As bad as possible'),
  ];

  testWidgets('displays all options', (tester) async {
    await tester.pumpWidget(
      wrapWithMaterialApp(
        ResponseScaleSelector(options: options, onSelected: (_) {}),
      ),
    );

    expect(find.text('No problem'), findsOneWidget);
    expect(find.text('Mild problem'), findsOneWidget);
    expect(find.text('Moderate problem'), findsOneWidget);
    expect(find.text('Severe problem'), findsOneWidget);
    expect(find.text('As bad as possible'), findsOneWidget);
  });

  testWidgets('calls onSelected when tapped', (tester) async {
    int? selectedValue;
    await tester.pumpWidget(
      wrapWithMaterialApp(
        ResponseScaleSelector(
          options: options,
          onSelected: (v) => selectedValue = v,
        ),
      ),
    );

    await tester.tap(find.text('Moderate problem'));
    expect(selectedValue, 2);
  });

  testWidgets('highlights selected option', (tester) async {
    await tester.pumpWidget(
      wrapWithMaterialApp(
        ResponseScaleSelector(
          options: options,
          selectedValue: 3,
          onSelected: (_) {},
        ),
      ),
    );

    // The selected option should show a checked radio icon
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    // The rest should show unchecked
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(4));
  });
}
