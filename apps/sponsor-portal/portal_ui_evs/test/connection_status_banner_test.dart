// Verifies: DIARY-GUI-portal-transport-status/A+B — the banner is hidden while
//   Connected, shown (over the retained child) while Reconnecting/Disconnected,
//   and self-clears when the transport reconnects.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/connection_status_banner.dart';
import 'package:reaction/reaction.dart';

void main() {
  testWidgets(
    'hidden when Connected; shown when Reconnecting/Disconnected; clears on reconnect',
    (tester) async {
      final ctrl = StreamController<ConnectionStatus>();
      addTearDown(ctrl.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBanner(
              statusStream: ctrl.stream,
              initial: const Connected(),
              child: const Text('body-content'),
            ),
          ),
        ),
      );

      final banner = find.byKey(const Key('connection-status-banner'));

      // Connected: no banner, content present.
      expect(banner, findsNothing);
      expect(find.text('body-content'), findsOneWidget);

      // Reconnecting: banner appears, content still present.
      ctrl.add(const Reconnecting());
      await tester.pumpAndSettle();
      expect(banner, findsOneWidget);
      expect(find.textContaining('Reconnecting'), findsOneWidget);
      expect(find.text('body-content'), findsOneWidget);

      // Disconnected: banner stays, copy switches.
      ctrl.add(const Disconnected());
      await tester.pumpAndSettle();
      expect(banner, findsOneWidget);
      expect(find.textContaining('Disconnected'), findsOneWidget);

      // Reconnected: banner clears.
      ctrl.add(const Connected());
      await tester.pumpAndSettle();
      expect(banner, findsNothing);
      expect(find.text('body-content'), findsOneWidget);
    },
  );
}
