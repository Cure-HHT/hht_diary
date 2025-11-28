// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/widgets/delete_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeleteConfirmationDialog', () {
    testWidgets('displays dialog title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      DeleteConfirmationDialog(onConfirmDelete: (_) {}),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Record'), findsOneWidget);
    });

    testWidgets('displays instruction text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      DeleteConfirmationDialog(onConfirmDelete: (_) {}),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please select a reason for deleting this record:'),
        findsOneWidget,
      );
    });

    testWidgets('displays all reason options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      DeleteConfirmationDialog(onConfirmDelete: (_) {}),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Entered by mistake'), findsOneWidget);
      expect(find.text('Duplicate entry'), findsOneWidget);
      expect(find.text('Incorrect information'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('displays Cancel and Delete buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      DeleteConfirmationDialog(onConfirmDelete: (_) {}),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('Delete button is disabled when no reason selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      DeleteConfirmationDialog(onConfirmDelete: (_) {}),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      final deleteButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete'),
      );

      expect(deleteButton.onPressed, isNull);
    });

    testWidgets('Cancel button closes dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      DeleteConfirmationDialog(onConfirmDelete: (_) {}),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Record'), findsNothing);
    });

    testWidgets('selecting a reason enables Delete button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      DeleteConfirmationDialog(onConfirmDelete: (_) {}),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap on the Radio button for a reason (using InkWell tap area)
      final inkWell = find.ancestor(
        of: find.text('Entered by mistake'),
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWell.first);
      await tester.pumpAndSettle();

      final deleteButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete'),
      );

      expect(deleteButton.onPressed, isNotNull);
    });

    testWidgets('calls onConfirmDelete with selected reason', (tester) async {
      String? deletedReason;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => DeleteConfirmationDialog(
                    onConfirmDelete: (reason) => deletedReason = reason,
                  ),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Select a reason using InkWell tap area
      final inkWell = find.ancestor(
        of: find.text('Duplicate entry'),
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWell.first);
      await tester.pumpAndSettle();

      // Press delete
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deletedReason, 'Duplicate entry');
    });

    testWidgets('shows text field when Other is selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                height: 800,
                child: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => SingleChildScrollView(
                        child: DeleteConfirmationDialog(
                          onConfirmDelete: (_) {},
                        ),
                      ),
                    ),
                    child: const Text('Open Dialog'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // No text field initially
      expect(find.byType(TextField), findsNothing);

      // Select Other using InkWell tap area
      final inkWell = find.ancestor(
        of: find.text('Other'),
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWell.first);
      await tester.pumpAndSettle();

      // Text field should now be visible
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Please specify'), findsOneWidget);
    });

    testWidgets('Delete is disabled with Other selected but empty text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                height: 800,
                child: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => SingleChildScrollView(
                        child: DeleteConfirmationDialog(
                          onConfirmDelete: (_) {},
                        ),
                      ),
                    ),
                    child: const Text('Open Dialog'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Select Other using InkWell tap area
      final inkWell = find.ancestor(
        of: find.text('Other'),
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWell.first);
      await tester.pumpAndSettle();

      final deleteButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete'),
      );

      expect(deleteButton.onPressed, isNull);
    });

    testWidgets('static show method displays dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DeleteConfirmationDialog.show(
                  context: context,
                  onConfirmDelete: (_) {},
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Record'), findsOneWidget);
    });

    testWidgets('renders as AlertDialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      DeleteConfirmationDialog(onConfirmDelete: (_) {}),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}
