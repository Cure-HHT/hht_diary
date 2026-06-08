import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(font: AppFontFamily.inter),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(24), child: child),
    ),
  );
}

void main() {
  group('AppTextField', () {
    testWidgets('renders the label and required asterisk', (tester) async {
      await tester.pumpWidget(
        _harness(const AppTextField(label: 'Email', required: true)),
      );
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('*'), findsOneWidget);
    });

    testWidgets('omits the required asterisk when not required', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const AppTextField(label: 'Notes')));
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('*'), findsNothing);
    });

    testWidgets('fires onChanged immediately when no debounce is set', (
      tester,
    ) async {
      final changes = <String>[];
      await tester.pumpWidget(_harness(AppTextField(onChanged: changes.add)));
      await tester.enterText(find.byType(TextFormField), 'hello');
      expect(changes, equals(['hello']));
    });

    testWidgets('debounces onChanged when onChangedDebounce is set', (
      tester,
    ) async {
      final changes = <String>[];
      await tester.pumpWidget(
        _harness(
          AppTextField(
            onChanged: changes.add,
            onChangedDebounce: const Duration(milliseconds: 100),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'a');
      await tester.enterText(find.byType(TextFormField), 'ab');
      await tester.enterText(find.byType(TextFormField), 'abc');
      // No fire yet — debounce timer hasn't elapsed.
      expect(changes, isEmpty);
      await tester.pump(const Duration(milliseconds: 150));
      // Only the last value fires.
      expect(changes, equals(['abc']));
    });

    testWidgets('semanticId emits a Semantics identifier with textField role', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const AppTextField(label: 'Email', semanticId: 'login.email')),
      );
      final node = tester.getSemantics(find.byType(AppTextField));
      expect(node.identifier, equals('login.email'));
      expect(node.flagsCollection.isTextField, isTrue);
    });

    testWidgets('no Semantics wrapper when semanticId is null', (tester) async {
      await tester.pumpWidget(_harness(const AppTextField(label: 'Email')));
      final node = tester.getSemantics(find.byType(AppTextField));
      expect(node.identifier, isEmpty);
    });

    group('.search', () {
      testWidgets('shows the magnifier prefix', (tester) async {
        await tester.pumpWidget(_harness(AppTextField.search()));
        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('shows clear button when text is non-empty', (tester) async {
        await tester.pumpWidget(_harness(AppTextField.search()));
        expect(find.byIcon(Icons.close), findsNothing);
        await tester.enterText(find.byType(TextFormField), 'query');
        await tester.pump();
        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('clearing fires onChanged with empty string', (tester) async {
        final changes = <String>[];
        await tester.pumpWidget(
          _harness(
            AppTextField.search(
              onChanged: changes.add,
              debounce: Duration.zero,
            ),
          ),
        );
        await tester.enterText(find.byType(TextFormField), 'query');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        expect(changes.last, equals(''));
      });
    });
  });
}
