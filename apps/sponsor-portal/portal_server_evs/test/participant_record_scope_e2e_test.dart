// Verifies: DIARY-DEV-portal-reaction-server/C — a StudyCoordinator's live
//   participant_record subscription is narrowed to the participants at the
//   coordinator's own site (row-level read scope), so a site-bound coordinator
//   never receives participant rows from other sites over the reaction WS.
//
// This exercises the REAL booted portal server end-to-end: it binds the boot
// router to an ephemeral port and speaks the reaction WS wire protocol
// (auth -> subscribe -> snapshots -> end_of_replay), exactly as the Flutter-web
// portal client does. The narrowing MECHANISM (containment expansion) is covered
// by the reaction library's own tests; this test verifies that OUR portal wiring
// registers the participant_record ViewScopeBinding AND passes the registry into
// ReactionHandlers — i.e. the binding is actually in force on the live server.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import 'link_ingest_harness.dart';

void main() {
  test(
    'site-bound coordinator only sees own-site participants over the WS',
    () async {
      final h = await bootPortal(dbName: 'participant-record-scope');
      // A participant at the coordinator's site, and one at a DIFFERENT site.
      await seedParticipant(h.eventStore,
          participantId: 'P-Z', siteId: 'site-Z');
      await seedParticipant(h.eventStore,
          participantId: 'P-Y', siteId: 'site-Y');
      await seedCoordinator(h.eventStore, userId: 'coord-z', siteId: 'site-Z');

      // Bind the real boot router on an ephemeral port and open a real WS.
      final server = await shelf_io.serve(h.boot.router.call, 'localhost', 0);
      addTearDown(() async {
        await server.close(force: true);
        await h.dispose();
      });

      final ws = await WebSocket.connect(
        'ws://localhost:${server.port}/subscriptions',
      );
      final participantIds = <String>{};
      final replayDone = Completer<void>();
      ws.listen((data) {
        final msg = jsonDecode(data as String) as Map<String, Object?>;
        switch (msg['type']) {
          case 'snapshot':
          case 'delta':
            final value = msg['value'] as Map<String, Object?>?;
            final id = value?['participant_id'] ?? value?['aggregateId'];
            if (id is String) participantIds.add(id);
          case 'end_of_replay':
            if (!replayDone.isCompleted) replayDone.complete();
        }
      });

      ws.add(jsonEncode({'type': 'auth', 'credential': 'coord-z'}));
      // Small gap so auth_ok is processed before the subscribe (matches client).
      await Future<void>.delayed(const Duration(milliseconds: 100));
      ws.add(jsonEncode({
        'type': 'subscribe',
        'subscriptionId': 'sub-1',
        'viewName': 'participant_record',
      }));

      await replayDone.future.timeout(const Duration(seconds: 5));
      await ws.close();

      // The coordinator at site-Z must see P-Z and MUST NOT see P-Y (site-Y) or
      // any dev-seeded participants at site-1/2/3.
      expect(participantIds, contains('P-Z'));
      expect(participantIds, isNot(contains('P-Y')));
      expect(
        participantIds,
        equals(<String>{'P-Z'}),
        reason: 'participant_record subscription must be row-scoped to the '
            "coordinator's site; saw cross-site rows: $participantIds",
      );
    },
  );
}
