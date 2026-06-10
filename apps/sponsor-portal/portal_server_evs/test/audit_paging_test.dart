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
