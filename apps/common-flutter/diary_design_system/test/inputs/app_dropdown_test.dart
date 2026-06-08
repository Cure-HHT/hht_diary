import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = [
  AppDropdownItem(value: 'a', label: 'Apple'),
  AppDropdownItem(
    value: 'b',
    label: 'Banana',
    description: 'Yellow elongated fruit',
  ),
];

Widget _harness(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(font: AppFontFamily.inter),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(24), child: child),
    ),
  );
}

void main() {
  group('AppDropdown', () {
    testWidgets('renders the label and required asterisk', (tester) async {
      await tester.pumpWidget(
        _harness(
          const AppDropdown<String>(
            label: 'Fruit',
            required: true,
            items: _items,
          ),
        ),
      );
      expect(find.text('Fruit'), findsOneWidget);
      expect(find.text('*'), findsOneWidget);
    });

    testWidgets('opens the popup on tap and selects an item', (tester) async {
      String? selected;
      await tester.pumpWidget(
        _harness(
          AppDropdown<String>(
            hintText: 'Pick a fruit',
            items: _items,
            onChanged: (v) => selected = v,
          ),
        ),
      );
      await tester.tap(find.text('Pick a fruit'));
      await tester.pumpAndSettle();
      // Popup is open — both labels should now be visible.
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
      await tester.tap(find.text('Banana'));
      await tester.pumpAndSettle();
      expect(selected, equals('b'));
    });

    testWidgets('shows a checkmark on the selected item in the popup', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const AppDropdown<String>(
            value: 'b',
            items: _items,
            hintText: 'Pick',
          ),
        ),
      );
      // Trigger field shows the selected label.
      expect(find.text('Banana'), findsOneWidget);
      // Open the popup.
      await tester.tap(find.text('Banana'));
      await tester.pumpAndSettle();
      // One checkmark visible (next to the selected item).
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    // Description rendering inside Material's DropdownButton popup is
    // constrained by kMinInteractiveDimension; a custom popup would be needed
    // to display both label and description per Figma. Tracked as an
    // iteration item; the AppDropdownItem.description field is preserved.

    testWidgets('semanticId emits identifier + selected label as value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const AppDropdown<String>(
            value: 'b',
            items: _items,
            hintText: 'Pick',
            semanticId: 'site.selector',
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(AppDropdown<String>));
      expect(node.identifier, equals('site.selector'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.value, equals('Banana'));
    });
  });
}
