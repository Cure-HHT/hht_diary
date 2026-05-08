// test/client/request_history_panel_test.dart
import 'package:action_permissions_demo/client/action_buttons_panel.dart';
import 'package:action_permissions_demo/client/request_history_panel.dart';
import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DispatchHistoryEntry _success(String name) => DispatchHistoryEntry(
  request: DispatchRequest(
    actionName: name,
    rawInput: const <String, Object?>{},
  ),
  response: const DispatchResponseSuccess(
    actionInvocationId: '',
    emittedEventIds: <String>['e1'],
    result: <String, Object?>{},
  ),
  at: DateTime(2026, 5, 8, 12, 0, 0),
);

DispatchHistoryEntry _denied(String name, String kind, {String? perm}) =>
    DispatchHistoryEntry(
      request: DispatchRequest(
        actionName: name,
        rawInput: const <String, Object?>{},
      ),
      response: DispatchResponseDenied(
        denialKind: kind,
        actionInvocationId: '',
        errorClass: 'X',
        errorMessageSanitized: 'oops',
        permissionDenied: perm,
      ),
      at: DateTime(2026, 5, 8, 12, 0, 1),
    );

DispatchHistoryEntry _hit(String name) => DispatchHistoryEntry(
  request: DispatchRequest(
    actionName: name,
    rawInput: const <String, Object?>{},
  ),
  response: const DispatchResponseIdempotencyHit(
    actionInvocationId: '',
    priorEventIds: <String>['e0'],
    priorResult: <String, Object?>{},
  ),
  at: DateTime(2026, 5, 8, 12, 0, 2),
);

Widget _scaffold(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('RequestHistoryPanel', () {
    testWidgets('empty state shows placeholder', (tester) async {
      await tester.pumpWidget(
        _scaffold(const RequestHistoryPanel(entries: <DispatchHistoryEntry>[])),
      );
      expect(find.text('(no dispatches yet)'), findsOneWidget);
    });

    testWidgets('renders success / denied / hit with their labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        _scaffold(
          RequestHistoryPanel(
            entries: <DispatchHistoryEntry>[
              _success('A'),
              _denied('B', 'authorization_denied', perm: 'p.x'),
              _hit('C'),
            ],
          ),
        ),
      );
      expect(find.textContaining('A  →  success'), findsOneWidget);
      expect(find.textContaining('B  →  authorization_denied'), findsOneWidget);
      expect(find.textContaining('C  →  idempotency hit'), findsOneWidget);
      expect(find.text('permission: p.x'), findsOneWidget);
    });

    testWidgets('most recent first', (tester) async {
      final entries = <DispatchHistoryEntry>[
        _success('first'),
        _success('second'),
        _success('third'),
      ];
      await tester.pumpWidget(_scaffold(RequestHistoryPanel(entries: entries)));
      // Find the y-positions of each line; the most recent ('third')
      // should be highest on screen (smallest dy).
      double yOf(String text) =>
          tester.getTopLeft(find.textContaining(text)).dy;
      expect(yOf('third'), lessThan(yOf('second')));
      expect(yOf('second'), lessThan(yOf('first')));
    });
  });
}
