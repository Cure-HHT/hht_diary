// test/client/action_buttons_panel_test.dart
import 'dart:convert';

import 'package:action_permissions_demo/client/action_buttons_panel.dart';
import 'package:action_permissions_demo/client/hacker_mode_toggle.dart';
import 'package:action_permissions_demo/client/http_client.dart';
import 'package:action_permissions_demo/client/permission_snapshot_cache.dart';
import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

DemoHttpClient _fakeClient(http.Response Function(http.Request req) handler) {
  final mock = MockClient((req) async => handler(req));
  return DemoHttpClient(inner: mock);
}

void main() {
  group('ActionButtonsPanel', () {
    testWidgets('all 7 buttons disabled when cache empty and hacker off', (
      tester,
    ) async {
      final cache = PermissionSnapshotCache();
      final mode = HackerMode();
      final client = _fakeClient((req) => http.Response('{}', 200));
      final entries = <DispatchHistoryEntry>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButtonsPanel(
              cache: cache,
              hackerMode: mode,
              http: client,
              onDispatched: entries.add,
            ),
          ),
        ),
      );
      for (final btn in tester.widgetList<ElevatedButton>(
        find.byType(ElevatedButton),
      )) {
        expect(btn.onPressed, isNull);
      }
    });

    testWidgets('GreenTeam cache enables 4 of 7 buttons', (tester) async {
      final cache = PermissionSnapshotCache()
        ..update(
          userId: 'green-user-1',
          principalRole: 'GreenTeam',
          principalUserId: 'green-user-1',
          principalActiveSite: 'green-workspace',
          permissions: <String>{
            'help.ask',
            'notes.write.green',
            'buttons.press.green',
            'buttons.press.red',
          },
        );
      final mode = HackerMode();
      final client = _fakeClient((req) => http.Response('{}', 200));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButtonsPanel(
              cache: cache,
              hackerMode: mode,
              http: client,
              onDispatched: (_) {},
            ),
          ),
        ),
      );
      final enabledCount = tester
          .widgetList<ElevatedButton>(find.byType(ElevatedButton))
          .where((b) => b.onPressed != null)
          .length;
      expect(enabledCount, 4);
      expect(
        tester.widgetList<ElevatedButton>(find.byType(ElevatedButton)).length,
        7,
      );
    });

    testWidgets('hacker mode enables every button', (tester) async {
      final cache = PermissionSnapshotCache();
      final mode = HackerMode()..set(true);
      final client = _fakeClient((req) => http.Response('{}', 200));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButtonsPanel(
              cache: cache,
              hackerMode: mode,
              http: client,
              onDispatched: (_) {},
            ),
          ),
        ),
      );
      for (final btn in tester.widgetList<ElevatedButton>(
        find.byType(ElevatedButton),
      )) {
        expect(btn.onPressed, isNotNull);
      }
    });

    testWidgets('Press Green dispatches and reports a history entry', (
      tester,
    ) async {
      final cache = PermissionSnapshotCache()
        ..update(
          userId: 'green-user-1',
          principalRole: 'GreenTeam',
          principalUserId: 'green-user-1',
          principalActiveSite: 'green-workspace',
          permissions: <String>{'buttons.press.green'},
        );
      final mode = HackerMode();
      late http.Request lastRequest;
      final entries = <DispatchHistoryEntry>[];
      final client = _fakeClient((req) {
        lastRequest = req;
        return http.Response(
          jsonEncode(<String, Object?>{
            'kind': 'success',
            'actionInvocationId': '',
            'emittedEventIds': <String>['event-1'],
            'result': <String, Object?>{'eventId': 'event-1'},
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButtonsPanel(
              cache: cache,
              hackerMode: mode,
              http: client,
              onDispatched: entries.add,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Press Green'));
      await tester.pumpAndSettle();

      expect(entries, hasLength(1));
      expect(entries.first.response, isA<DispatchResponseSuccess>());
      expect(lastRequest.url.path, '/dispatch');
      final body = jsonDecode(lastRequest.body) as Map<String, Object?>;
      expect(body['actionName'], 'PressGreenButtonAction');
      expect(body['userId'], 'green-user-1');
    });

    testWidgets(
      'Provision User button is present and gated by users.provision',
      (tester) async {
        // Admin cache holds users.provision -> button enabled.
        final adminCache = PermissionSnapshotCache()
          ..update(
            userId: 'admin-user',
            principalRole: 'Admin',
            principalUserId: 'admin-user',
            principalActiveSite: null,
            permissions: <String>{'users.provision'},
          );
        final mode = HackerMode();
        final client = _fakeClient((req) => http.Response('{}', 200));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ActionButtonsPanel(
                cache: adminCache,
                hackerMode: mode,
                http: client,
                onDispatched: (_) {},
              ),
            ),
          ),
        );
        expect(find.text('Provision User'), findsOneWidget);
        final btn = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('Provision User'),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(btn.onPressed, isNotNull);
      },
    );

    testWidgets('GreenTeam cache disables Provision User', (tester) async {
      final cache = PermissionSnapshotCache()
        ..update(
          userId: 'green-user-1',
          principalRole: 'GreenTeam',
          principalUserId: 'green-user-1',
          principalActiveSite: 'green-workspace',
          permissions: <String>{
            'help.ask',
            'notes.write.green',
            'buttons.press.green',
            'buttons.press.red',
          },
        );
      final mode = HackerMode();
      final client = _fakeClient((req) => http.Response('{}', 200));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButtonsPanel(
              cache: cache,
              hackerMode: mode,
              http: client,
              onDispatched: (_) {},
            ),
          ),
        ),
      );
      final btn = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Provision User'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(btn.onPressed, isNull);
    });
  });
}
