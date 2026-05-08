// test/client/server_inspector_pane_test.dart
import 'dart:convert';

import 'package:action_permissions_demo/client/http_client.dart';
import 'package:action_permissions_demo/client/server_inspector_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _emptySnap = <String, Object?>{
  'events': <Object?>[],
  'matrixGrants': <Object?>[],
  'directory': <Object?>[],
  'idempotency': <Object?>[],
  'lastDispatchTrace': null,
};

DemoHttpClient _client(http.Response Function(http.Request req) handle) {
  return DemoHttpClient(inner: MockClient((req) async => handle(req)));
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ServerInspectorPane', () {
    testWidgets('shows progress indicator before first poll resolves', (
      tester,
    ) async {
      // The MockClient resolves immediately, so we need a snapshot to
      // arrive then settle. Verify the progress indicator was at least
      // pumped once before settle. We use plain `pump()` rather than
      // `pumpAndSettle` because the pane runs a periodic Timer that
      // never settles.
      final client = _client(
        (req) => http.Response(
          jsonEncode(_emptySnap),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      );
      await tester.pumpWidget(
        _wrap(
          ServerInspectorPane(
            httpClient: client,
            pollInterval: const Duration(hours: 1),
          ),
        ),
      );
      // Right after pumpWidget, the future has not yet resolved.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Let the inspect() future complete and setState rebuild.
      await tester.pump();
      await tester.pump();
      expect(find.text('Event Log (0)'), findsOneWidget);
    });

    testWidgets('renders sections for a populated snapshot', (tester) async {
      final populated = <String, Object?>{
        'events': <Object?>[
          <String, Object?>{
            'eventId': 'e1',
            'eventType': 'help_request',
            'aggregateType': 'help_ticket',
            'aggregateId': 'agg-uuid-1',
            'actionInvocationId': 'inv-1',
            'initiatorUserId': 'green-user-1',
            'initiatorRole': 'GreenTeam',
          },
        ],
        'matrixGrants': <Object?>[
          <String, Object?>{'role': 'GreenTeam', 'permission': 'help.ask'},
        ],
        'directory': <Object?>[
          <String, Object?>{
            'userId': 'green-user-1',
            'role': 'GreenTeam',
            'activeSite': 'green-workspace',
          },
        ],
        'idempotency': <Object?>[
          <String, Object?>{
            'actionName': 'PressRedAlarmAction',
            'principalUserId': 'green-user-1',
            'idempotencyKey': 'k1',
            'expiresAt': DateTime.utc(2026, 5, 9).toIso8601String(),
          },
        ],
        'lastDispatchTrace': <String, Object?>{
          'actionInvocationId': 'inv-1',
          'actionName': 'RequestHelpAction',
          'stages': <String>['lookup', 'parse', 'execute'],
        },
      };
      final client = _client(
        (req) => http.Response(
          jsonEncode(populated),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      );
      await tester.pumpWidget(
        _wrap(
          ServerInspectorPane(
            httpClient: client,
            pollInterval: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Event Log (1)'), findsOneWidget);
      expect(find.text('Matrix Grants (1)'), findsOneWidget);
      expect(find.text('User Directory (1)'), findsOneWidget);
      expect(find.text('Idempotency Cache (1)'), findsOneWidget);
      expect(find.text('Last Dispatch Trace'), findsOneWidget);
      expect(find.textContaining('GreenTeam  →  help.ask'), findsOneWidget);
      expect(find.text('RequestHelpAction'), findsOneWidget);
      expect(find.text('  • lookup'), findsOneWidget);
    });

    testWidgets('shows error message on bad response', (tester) async {
      final client = _client((req) => http.Response('boom', 500));
      await tester.pumpWidget(
        _wrap(
          ServerInspectorPane(
            httpClient: client,
            pollInterval: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // Still in the loading state with an error message.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('error:'), findsOneWidget);
    });
  });
}
