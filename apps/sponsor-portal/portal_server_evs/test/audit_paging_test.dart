// Verifies: DIARY-DEV-audit-log-read/A+B
//
// Server-side paging + filtering of GET /audit. Paging must make the OLDEST
// event reachable however large the log grows (a 21 CFR Part 11 completeness
// property), `total` must report the true log size, and `q` must filter the
// whole log server-side — not just the fetched page.
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late PortalServerBoot boot;
  late int storeSize;
  late Set<int> allSequences;

  setUpAll(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('audit-paging.db');
    boot = await bootstrapPortalServer(
      backend: SembastBackend(database: db),
      raveClient: DevSeedRaveClient(),
    );
    // Three marker events with a recognisable automation initiator, so the
    // q-filter tests have a known target among the seed events. The entry
    // type must be one the store's EntryTypeRegistry already knows.
    for (var i = 0; i < 3; i++) {
      await boot.eventStore.append(
        entryType: 'user_tier_changed',
        aggregateType: 'portal_user',
        aggregateId: 'probe-$i',
        eventType: 'user_tier_changed',
        data: <String, Object?>{'user_id': 'probe-$i', 'tier': 'staff'},
        initiator: const AutomationInitiator(service: 'paging-probe'),
      );
    }
    // view=mine marker events: the authenticated principal's (admin-1's) OWN
    // participant actions (the `view=mine` scope), plus a PEER user's
    // participant action that view=mine must exclude (separation of duties).
    // admin-1 is the bearer getAudit uses, so principal.id == 'admin-1'.
    // Full linking-code payload so the linking-codes projection folds cleanly.
    Map<String, Object?> linkData(String pid) => <String, Object?>{
          'linking_code': 'CODE-$pid',
          'participant_id': pid,
          'site_id': 'site-1',
          'generated_by': 'admin-1',
          'expires_at': '2026-12-31T00:00:00.000Z',
          'purpose': 'link',
          'status': 'active',
          'mobile_linking_status': 'linking_in_progress',
        };
    for (final pid in const ['DEV-001-001', 'DEV-001-002']) {
      await boot.eventStore.append(
        entryType: 'participant_linking_code_issued',
        aggregateType: 'participant',
        aggregateId: pid,
        eventType: 'participant_linking_code_issued',
        data: linkData(pid),
        initiator: const UserInitiator('admin-1'),
      );
    }
    await boot.eventStore.append(
      entryType: 'participant_linking_code_issued',
      aggregateType: 'participant',
      aggregateId: 'DEV-001-003',
      eventType: 'participant_linking_code_issued',
      data: linkData('DEV-001-003'),
      initiator: const UserInitiator('peer-sc'),
    );

    final events = await boot.eventStore.backend.readEventsReverse().toList();
    storeSize = events.length;
    allSequences = events.map((e) => e.sequenceNumber).toSet();
  });

  tearDownAll(() => boot.dispose());

  Future<Map<String, Object?>> getAudit(String query) async {
    final resp = await boot.router(
      Request(
        'GET',
        Uri.parse('http://localhost/audit$query'),
        headers: const {'Authorization': 'Bearer admin-1'},
      ),
    );
    expect(resp.statusCode, 200);
    return jsonDecode(await resp.readAsString()) as Map<String, Object?>;
  }

  List<int> sequencesOf(Map<String, Object?> body) => [
        for (final row in body['rows'] as List) (row as Map)['sequence'] as int,
      ];

  test('offset paging walks the FULL log down to the oldest event', () async {
    // Page with a limit that does not divide the store size, so the last
    // page is a partial one — the shape the UI's final page produces.
    const limit = 7;
    final seen = <int>[];
    var offset = 0;
    while (true) {
      final body = await getAudit('?limit=$limit&offset=$offset');
      expect(body['total'], storeSize,
          reason: 'every page reports the true log size');
      final seqs = sequencesOf(body);
      if (seqs.isEmpty) break;
      seen.addAll(seqs);
      offset += limit;
      expect(offset < storeSize + limit, isTrue,
          reason: 'paging must terminate');
    }
    expect(seen.toSet(), allSequences,
        reason: 'paging reaches every event in the store, oldest included');
    expect(seen, hasLength(storeSize), reason: 'pages are disjoint');
    final sorted = [...seen]..sort((a, b) => b.compareTo(a));
    expect(seen, sorted,
        reason: 'reverse-chronological order is stable across pages');
  });

  test('offset beyond the end -> empty rows, count 0, true total', () async {
    final body = await getAudit('?limit=10&offset=${storeSize + 50}');
    expect(body['rows'], isEmpty);
    expect(body['count'], 0);
    expect(body['total'], storeSize);
  });

  test('limit and offset are clamped to sane bounds', () async {
    final zero = await getAudit('?limit=0');
    expect(sequencesOf(zero), hasLength(1), reason: 'limit clamps up to 1');

    final negativeLimit = await getAudit('?limit=-5');
    expect(sequencesOf(negativeLimit), hasLength(1));

    final negativeOffset = await getAudit('?limit=3&offset=-10');
    final baseline = await getAudit('?limit=3&offset=0');
    expect(sequencesOf(negativeOffset), sequencesOf(baseline),
        reason: 'negative offset behaves as offset 0');
  });

  test('response stays back-compatible: rows + count, count == rows.length',
      () async {
    final body = await getAudit('');
    expect(body['rows'], isA<List<Object?>>());
    expect(body['count'], (body['rows'] as List).length);
    expect(body['total'], storeSize);
    expect(body['offset'], 0);
  });

  group('q filters the whole log server-side', () {
    test('matches initiator label, reports the filtered total', () async {
      final body = await getAudit('?q=paging-probe');
      expect(body['total'], 3);
      expect(body['rows'], hasLength(3));
      for (final row in body['rows'] as List) {
        final initiator = (row as Map)['initiator'] as Map;
        expect(initiator['label'], 'paging-probe');
      }
    });

    test('is case-insensitive', () async {
      final body = await getAudit('?q=PAGING-PROBE');
      expect(body['total'], 3);
    });

    test('matches the entry type, including its space-separated form',
        () async {
      final raw = await getAudit('?q=user_tier_changed');
      expect(raw['total'], greaterThanOrEqualTo(3));
      // A user typing against the humanized Action column ("User Tier
      // Changed") must still hit the underscore-separated entry-type id.
      final humanized = await getAudit('?q=user%20tier%20changed');
      expect(humanized['total'], raw['total']);
    });

    test('pages within the filtered set', () async {
      final page2 = await getAudit('?q=paging-probe&limit=2&offset=2');
      expect(page2['rows'], hasLength(1));
      expect(page2['total'], 3);
    });

    test('no matches -> empty rows, total 0', () async {
      final body = await getAudit('?q=no-such-thing-xyz');
      expect(body['rows'], isEmpty);
      expect(body['total'], 0);
    });
  });

  group('site filters the log to one site', () {
    test(
        'returns site events by aggregate and participant events via the '
        'participant->site index; nothing else', () async {
      final body = await getAudit('?site=site-1&limit=1000');
      final rows = (body['rows'] as List).cast<Map<String, Object?>>();
      expect(rows, isNotEmpty);
      expect(body['total'], rows.length,
          reason: 'large limit -> total equals the filtered row count');
      // DevSeedRaveClient: site-1 hosts DEV-001-001 / DEV-001-002; site-2 and
      // site-3 host the others.
      for (final row in rows) {
        switch (row['aggregate_type']) {
          case 'site':
            expect(row['aggregate_id'], 'site-1');
          case 'participant':
            expect(row['aggregate_id'], startsWith('DEV-001-'));
          default:
            fail('site filter leaked aggregate_type=${row['aggregate_type']}');
        }
      }
      // The site's own sync event is reachable through the filter.
      expect(
        rows.any((r) =>
            r['entry_type'] == 'site_synced_from_edc' &&
            r['aggregate_id'] == 'site-1'),
        isTrue,
      );
      // And at least one participant event joined in via the index.
      expect(rows.any((r) => r['aggregate_type'] == 'participant'), isTrue);
    });

    test('composes with q', () async {
      final body = await getAudit('?site=site-1&q=site%20synced&limit=1000');
      final rows = (body['rows'] as List).cast<Map<String, Object?>>();
      expect(rows, isNotEmpty);
      for (final row in rows) {
        expect(row['entry_type'], 'site_synced_from_edc');
        expect(row['aggregate_id'], 'site-1');
      }
    });

    test('pages within the filtered set with an honest total', () async {
      final all = await getAudit('?site=site-1&limit=1000');
      final total = all['total']! as int;
      expect(total, greaterThan(1), reason: 'fixture has site + participants');
      final page2 = await getAudit('?site=site-1&limit=1&offset=1');
      expect(page2['rows'], hasLength(1));
      expect(page2['total'], total);
    });

    test('unknown site -> empty rows, total 0', () async {
      final body = await getAudit('?site=no-such-site');
      expect(body['rows'], isEmpty);
      expect(body['total'], 0);
    });
  });

  // Verifies: DIARY-DEV-audit-log-read/A — view=admin scopes the log
  //   to Administrator actions: every returned row carries an Action-Inventory
  //   action_name, and the automation probe events (user_tier_changed) are
  //   excluded.
  group('view=admin scopes to Administrator actions', () {
    test('every row has an action_name; automation events are excluded',
        () async {
      final body = await getAudit('?view=admin&limit=1000');
      for (final r in body['rows'] as List) {
        final row = r as Map;
        expect(row['action_name'], isNotNull,
            reason: 'admin-view rows must be Action-Inventory actions');
        expect(row['entry_type'], isNot('user_tier_changed'),
            reason: 'automation probe events must be filtered out');
      }
      // The automation probe sequences must not appear in the admin view.
      final adminSeqs = sequencesOf(body).toSet();
      final probe = await getAudit('?q=paging-probe&limit=1000');
      final probeSeqs = sequencesOf(probe).toSet();
      expect(probeSeqs, isNotEmpty);
      expect(adminSeqs.intersection(probeSeqs), isEmpty);
    });

    test('total reflects the filtered set, never more than the whole log',
        () async {
      final admin = await getAudit('?view=admin&limit=1000');
      final all = await getAudit('?limit=1000');
      expect((admin['total']! as int) <= (all['total']! as int), isTrue);
    });
  });

  // Verifies: DIARY-DEV-audit-log-read/A — view=mine scopes the log to the
  //   principal's OWN participant/questionnaire actions (separation of duties),
  //   and every returned row carries a participant_id for the Participant ID
  //   column (DIARY-GUI-audit-log-study-coordinator/A).
  group('view=mine scopes to the principal\'s own participant activity', () {
    test('returns only the principal\'s participant/questionnaire actions',
        () async {
      final body = await getAudit('?view=mine&limit=1000');
      final rows = (body['rows'] as List).cast<Map<String, Object?>>();
      expect(rows, isNotEmpty);
      expect(body['total'], rows.length);
      for (final row in rows) {
        // Own actions only: initiator is the authenticated principal.
        expect((row['initiator'] as Map)['label'], 'admin-1');
        // Scoped to participant/questionnaire/site aggregates...
        expect(
          row['aggregate_type'],
          anyOf('participant', 'questionnaire_instance', 'site'),
        );
        // ...and every participant/questionnaire row carries a participant_id.
        if (row['aggregate_type'] != 'site') {
          expect(row['participant_id'], isNotNull);
        }
      }
      // The two admin-1 markers are present; the peer-sc marker is excluded.
      final ids = {for (final r in rows) r['aggregate_id']};
      expect(ids, containsAll(<String>['DEV-001-001', 'DEV-001-002']));
      expect(ids.contains('DEV-001-003'), isFalse,
          reason: 'a peer user\'s action must not appear in view=mine');
    });

    test('participant filter narrows view=mine by participant id', () async {
      final body =
          await getAudit('?view=mine&participant=DEV-001-001&limit=1000');
      final rows = (body['rows'] as List).cast<Map<String, Object?>>();
      expect(rows, hasLength(1));
      expect(rows.single['participant_id'], 'DEV-001-001');
    });
  });

  test('paging params do not bypass the permission gate', () async {
    final resp = await boot.router(
      Request(
        'GET',
        Uri.parse('http://localhost/audit?limit=5&offset=5&q=x'),
        headers: const {'Authorization': 'Bearer sysop-1'},
      ),
    );
    expect(resp.statusCode, 403);
  });
}
