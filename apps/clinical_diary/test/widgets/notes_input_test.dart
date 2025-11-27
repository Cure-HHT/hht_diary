// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/widgets/notes_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotesInput', () {
    testWidgets('displays title text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesInput(
              notes: '',
              onNotesChange: (_) {},
              onBack: () {},
              onNext: () {},
            ),
          ),
        ),
      );

      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('displays required message when isRequired is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesInput(
              notes: '',
              onNotesChange: (_) {},
              onBack: () {},
              onNext: () {},
              isRequired: true,
            ),
          ),
        ),
      );

      expect(
        find.text('Required for clinical trial participants'),
        findsOneWidget,
      );
    });

    testWidgets('does not display required message when isRequired is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesInput(
              notes: '',
              onNotesChange: (_) {},
              onBack: () {},
              onNext: () {},
              isRequired: false,
            ),
          ),
        ),
      );

      expect(
        find.text('Required for clinical trial participants'),
        findsNothing,
      );
    });

    testWidgets('displays hint text in text field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesInput(
              notes: '',
              onNotesChange: (_) {},
              onBack: () {},
              onNext: () {},
            ),
          ),
        ),
      );

      expect(
        find.text('Add any additional details about this nosebleed...'),
        findsOneWidget,
      );
    });

    testWidgets('displays initial notes value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesInput(
              notes: 'Initial note content',
              onNotesChange: (_) {},
              onBack: () {},
              onNext: () {},
            ),
          ),
        ),
      );

      expect(find.text('Initial note content'), findsOneWidget);
    });

    testWidgets('calls onNotesChange when text is entered', (tester) async {
      String? changedNotes;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesInput(
              notes: '',
              onNotesChange: (value) => changedNotes = value,
              onBack: () {},
              onNext: () {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'New note text');
      await tester.pump();

      expect(changedNotes, 'New note text');
    });

    testWidgets('calls onBack when Back button is pressed', (tester) async {
      var backPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesInput(
              notes: '',
              onNotesChange: (_) {},
              onBack: () => backPressed = true,
              onNext: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Back'));
      await tester.pump();

      expect(backPressed, true);
    });

    testWidgets('calls onNext when Next button is pressed with notes', (
      tester,
    ) async {
      var nextPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesInput(
              notes: 'Some notes',
              onNotesChange: (_) {},
              onBack: () {},
              onNext: () => nextPressed = true,
              isRequired: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(nextPressed, true);
    });

    testWidgets('Next button is disabled when required and notes are empty', (
      tester,
    ) async {
      var nextPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesInput(
              notes: '',
              onNotesChange: (_) {},
              onBack: () {},
              onNext: () => nextPressed = true,
              isRequired: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(nextPressed, false);
    });

    testWidgets(
      'Next button is enabled when not required and notes are empty',
      (tester) async {
        var nextPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotesInput(
                notes: '',
                onNotesChange: (_) {},
                onBack: () {},
                onNext: () => nextPressed = true,
                isRequired: false,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Next'));
        await tester.pump();

        expect(nextPressed, true);
      },
    );

    testWidgets('displays Back and Next buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesInput(
              notes: '',
              onNotesChange: (_) {},
              onBack: () {},
              onNext: () {},
            ),
          ),
        ),
      );

      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('text field expands to fill available space', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesInput(
              notes: '',
              onNotesChange: (_) {},
              onBack: () {},
              onNext: () {},
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.expands, true);
      expect(textField.maxLines, null);
    });
  });
}
