// Verifies: DIARY-GUI-portal-transport-status/A+B — the banner is hidden while
//   Connected, shown (over the retained child) once the transport DROPS after
//   having connected, and self-clears on reconnect. It stays suppressed on a
//   fresh load that has never connected (pre-connect Disconnected), so the
//   "showing last data received" copy is never shown before there is any data.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/connection_status_banner.dart';
import 'package:reaction/reaction.dart';

void main() {
  Widget host(Stream<ConnectionStatus> stream, ConnectionStatus initial) =>
      MaterialApp(
        home: Scaffold(
          body: ConnectionStatusBanner(
            statusStream: stream,
            initial: initial,
            child: const Text('body-content'),
          ),
        ),
      );

  final banner = find.byKey(const Key('connection-status-banner'));

  testWidgets(
    'Connected start: hidden; drop shows banner; reconnect clears it',
    (tester) async {
      final ctrl = StreamController<ConnectionStatus>();
      addTearDown(ctrl.close);
      await tester.pumpWidget(host(ctrl.stream, const Connected()));

      // Connected: no banner, content present.
      expect(banner, findsNothing);
      expect(find.text('body-content'), findsOneWidget);

      // Reconnecting: banner appears, content retained.
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

  testWidgets(
    'fresh load (never connected) stays banner-free until first connect',
    (tester) async {
      final ctrl = StreamController<ConnectionStatus>();
      addTearDown(ctrl.close);
      // Seed the pre-connect state RemoteConnection actually starts in.
      await tester.pumpWidget(host(ctrl.stream, const Disconnected()));

      // Never connected yet: no banner despite Disconnected initial/stream.
      expect(banner, findsNothing);
      ctrl.add(const Disconnected());
      await tester.pumpAndSettle();
      expect(banner, findsNothing);

      // First successful connect: still no banner.
      ctrl.add(const Connected());
      await tester.pumpAndSettle();
      expect(banner, findsNothing);

      // A genuine drop AFTER connecting now surfaces the banner.
      ctrl.add(const Reconnecting());
      await tester.pumpAndSettle();
      expect(banner, findsOneWidget);
    },
  );
}
