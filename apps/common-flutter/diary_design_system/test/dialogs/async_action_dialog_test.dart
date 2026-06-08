import 'dart:async';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AsyncActionDialog', () {
    testWidgets('transitions confirm → success on successful submit', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(font: AppFontFamily.inter),
          home: Scaffold(
            body: AsyncActionDialog<String>(
              onSubmit: () async => 'done',
              confirmBuilder: (ctx, submit) => AppDialog(
                title: 'Confirm',
                body: const Text('Ready?'),
                actions: [AppButton(label: 'Submit', onPressed: submit)],
              ),
              successBuilder: (ctx, result) =>
                  AppDialog(title: 'Success', body: Text('result: $result')),
              errorBuilder: (ctx, error, retry) =>
                  AppDialog(title: 'Error', body: Text(error.toString())),
            ),
          ),
        ),
      );
      expect(find.text('Confirm'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Success'), findsOneWidget);
      expect(find.text('result: done'), findsOneWidget);
    });

    testWidgets('default loading phase shows a CircularProgressIndicator', (
      tester,
    ) async {
      // Hold the future open so the loading phase is observable.
      final completer = Completer<String>();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(font: AppFontFamily.inter),
          home: Scaffold(
            body: AsyncActionDialog<String>(
              onSubmit: () => completer.future,
              confirmBuilder: (ctx, submit) => AppDialog(
                title: 'Confirm',
                body: const Text('Ready?'),
                actions: [AppButton(label: 'Submit', onPressed: submit)],
              ),
              successBuilder: (ctx, result) =>
                  AppDialog(title: 'Success', body: Text(result)),
              errorBuilder: (ctx, error, retry) =>
                  AppDialog(title: 'Error', body: Text(error.toString())),
            ),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Submit'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Resolve to leave a clean test state.
      completer.complete('done');
      await tester.pumpAndSettle();
    });

    testWidgets('transitions confirm → loading → error on submit failure', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(font: AppFontFamily.inter),
          home: Scaffold(
            body: AsyncActionDialog<String>(
              onSubmit: () async => throw StateError('boom'),
              confirmBuilder: (ctx, submit) => AppDialog(
                title: 'Confirm',
                body: const Text('Ready?'),
                actions: [AppButton(label: 'Submit', onPressed: submit)],
              ),
              successBuilder: (ctx, result) =>
                  AppDialog(title: 'Success', body: Text(result)),
              errorBuilder: (ctx, error, retry) => AppDialog(
                title: 'Error',
                body: Text(error.toString()),
                actions: [AppButton(label: 'Try again', onPressed: retry)],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Error'), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets('semanticId emits a Semantics identifier on the active phase', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(font: AppFontFamily.inter),
          home: Scaffold(
            body: AsyncActionDialog<String>(
              semanticId: 'disconnect.async',
              onSubmit: () async => 'ok',
              confirmBuilder: (ctx, submit) => AppDialog(
                title: 'Confirm',
                body: const Text('Ready?'),
                actions: [AppButton(label: 'Submit', onPressed: submit)],
              ),
              successBuilder: (ctx, result) =>
                  AppDialog(title: 'Success', body: Text(result)),
              errorBuilder: (ctx, error, retry) =>
                  AppDialog(title: 'Error', body: Text(error.toString())),
            ),
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(AsyncActionDialog<String>));
      expect(node.identifier, equals('disconnect.async'));
    });

    testWidgets('retry callback re-runs onSubmit', (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(font: AppFontFamily.inter),
          home: Scaffold(
            body: AsyncActionDialog<int>(
              onSubmit: () async {
                attempts++;
                if (attempts == 1) throw StateError('first attempt fails');
                return attempts;
              },
              confirmBuilder: (ctx, submit) => AppDialog(
                title: 'Confirm',
                body: const Text('Go'),
                actions: [AppButton(label: 'Submit', onPressed: submit)],
              ),
              successBuilder: (ctx, result) =>
                  AppDialog(title: 'Success', body: Text('attempts: $result')),
              errorBuilder: (ctx, error, retry) => AppDialog(
                title: 'Error',
                body: Text(error.toString()),
                actions: [AppButton(label: 'Retry', onPressed: retry)],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.widgetWithText(AppButton, 'Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Error'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Success'), findsOneWidget);
      expect(find.text('attempts: 2'), findsOneWidget);
    });
  });
}
