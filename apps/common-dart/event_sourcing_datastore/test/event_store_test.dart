import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

class _Fixture {
  _Fixture({
    required this.eventStore,
    required this.backend,
    required this.securityContexts,
    required this.entryTypes,
    required this.syncCalls,
  });

  final EventStore eventStore;
  final SembastBackend backend;
  final SembastSecurityContextStore securityContexts;
  final EntryTypeRegistry entryTypes;
  final List<DateTime> syncCalls;
}

Future<_Fixture> _setup({
  List<EntryTypeDefinition>? defs,
  DateTime? now,
}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'es-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  final registry = EntryTypeRegistry();
  // Auto-register every reserved system entry type (security-context
  // lifecycle plus REQ-d00129-J/K/L/M and REQ-d00138-H per-sweep audit)
  // so direct EventStore tests don't have to enumerate them by hand.
  for (final defn in kSystemEntryTypes) {
    registry.register(defn);
  }
  final effectiveDefs = defs ?? [_simpleDef('epistaxis_event')];
  for (final def in effectiveDefs) {
    registry.register(def);
  }
  // Seed view_target_versions for diary_entries so the materializer's
  // default targetVersionFor resolves the entry types we plan to append.
  // (Unit-style EventStore tests bypass bootstrapAppendOnlyDatastore.)
  await backend.transaction((txn) async {
    for (final def in effectiveDefs) {
      if (!def.materialize) continue;
      await backend.writeViewTargetVersionInTxn(
        txn,
        'diary_entries',
        def.id,
        def.registeredVersion,
      );
    }
  });
  final securityContexts = SembastSecurityContextStore(backend: backend);
  final syncCalls = <DateTime>[];
  final eventStore = EventStore(
    backend: backend,
    entryTypes: registry,
    source: const Source(
      hopId: 'mobile-device',
      identifier: 'device-1',
      softwareVersion: 'clinical_diary@1.0.0',
    ),
    securityContexts: securityContexts,
    materializers: const [DiaryEntriesMaterializer(promoter: identityPromoter)],
    syncCycleTrigger: () async {
      syncCalls.add(DateTime.now());
    },
    clock: now == null ? null : () => now,
  );
  return _Fixture(
    eventStore: eventStore,
    backend: backend,
    securityContexts: securityContexts,
    entryTypes: registry,
    syncCalls: syncCalls,
  );
}

EntryTypeDefinition _simpleDef(String id) => EntryTypeDefinition(
  id: id,
  registeredVersion: 1,
  name: id,
  widgetId: 'w',
  widgetConfig: const <String, Object?>{},
);

void main() {
  group('EventStore.append', () {
    // Verifies: REQ-d00141-B — per-field append returns StoredEvent with
    // initiator / flowToken round-tripped.
    test(
      'REQ-d00141-B: returns StoredEvent with initiator + flowToken',
      () async {
        final fx = await _setup();
        final ev = await fx.eventStore.append(
          entryType: 'epistaxis_event',
          entryTypeVersion: 1,
          aggregateId: 'a',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {
            'answers': {'severity': 'mild'},
          },
          initiator: const UserInitiator('u1'),
          flowToken: 'flow:abc',
        );
        expect(ev, isNotNull);
        expect(ev!.initiator, const UserInitiator('u1'));
        expect(ev.flowToken, 'flow:abc');
        await fx.backend.close();
      },
    );

    // Verifies: REQ-d00137-C — event + security row commit atomically.
    test('REQ-d00137-C: append with security writes both rows', () async {
      final fx = await _setup();
      final ev = await fx.eventStore.append(
        entryType: 'epistaxis_event',
        entryTypeVersion: 1,
        aggregateId: 'a',
        aggregateType: 'DiaryEntry',
        eventType: 'finalized',
        data: const {'answers': {}},
        initiator: const UserInitiator('u1'),
        security: const SecurityDetails(ipAddress: '203.0.113.7'),
      );
      final ctx = await fx.securityContexts.read(ev!.eventId);
      expect(ctx, isNotNull);
      expect(ctx!.ipAddress, '203.0.113.7');
      await fx.backend.close();
    });

    // Verifies: REQ-d00137-C — no security row when security param is null.
    test('append without security writes only event row', () async {
      final fx = await _setup();
      final ev = await fx.eventStore.append(
        entryType: 'epistaxis_event',
        entryTypeVersion: 1,
        aggregateId: 'a',
        aggregateType: 'DiaryEntry',
        eventType: 'finalized',
        data: const {'answers': {}},
        initiator: const UserInitiator('u1'),
      );
      expect(await fx.securityContexts.read(ev!.eventId), isNull);
      await fx.backend.close();
    });

    // Verifies: REQ-d00140-C — def.materialize=false skips all materializers.
    test(
      'REQ-d00140-C: materialize=false entry type produces no view row',
      () async {
        final fx = await _setup(
          defs: [
            const EntryTypeDefinition(
              id: 'non_materialized',
              registeredVersion: 1,
              name: 'Non-Mat',
              widgetId: 'w',
              widgetConfig: <String, Object?>{},
              materialize: false,
            ),
          ],
        );
        final ev = await fx.eventStore.append(
          entryType: 'non_materialized',
          entryTypeVersion: 1,
          aggregateId: 'a',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        );
        expect(ev, isNotNull);
        final viewRow = await fx.backend.transaction(
          (txn) async => fx.backend.readViewRowInTxn(txn, 'diary_entries', 'a'),
        );
        expect(viewRow, isNull);
        await fx.backend.close();
      },
    );

    test('unknown eventType throws ArgumentError before I/O', () async {
      final fx = await _setup();
      await expectLater(
        fx.eventStore.append(
          entryType: 'epistaxis_event',
          entryTypeVersion: 1,
          aggregateId: 'a',
          aggregateType: 'DiaryEntry',
          eventType: 'bogus',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        ),
        throwsArgumentError,
      );
      expect(await fx.backend.findAllEvents(), isEmpty);
      await fx.backend.close();
    });

    test('unregistered entryType throws ArgumentError before I/O', () async {
      final fx = await _setup();
      await expectLater(
        fx.eventStore.append(
          entryType: 'weather_report',
          entryTypeVersion: 1,
          aggregateId: 'a',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
        ),
        throwsArgumentError,
      );
      await fx.backend.close();
    });

    // Verifies: REQ-d00136-E — flow_token participates in event_hash; changing
    // it changes the hash.
    test('REQ-d00136-E: flow_token participates in event_hash', () async {
      final fxA = await _setup(now: DateTime.utc(2026, 4, 22));
      final evA = await fxA.eventStore.append(
        entryType: 'epistaxis_event',
        entryTypeVersion: 1,
        aggregateId: 'a',
        aggregateType: 'DiaryEntry',
        eventType: 'finalized',
        data: const {
          'answers': {'x': 1},
        },
        initiator: const UserInitiator('u1'),
        flowToken: 'alpha',
      );
      final fxB = await _setup(now: DateTime.utc(2026, 4, 22));
      final evB = await fxB.eventStore.append(
        entryType: 'epistaxis_event',
        entryTypeVersion: 1,
        aggregateId: 'a',
        aggregateType: 'DiaryEntry',
        eventType: 'finalized',
        data: const {
          'answers': {'x': 1},
        },
        initiator: const UserInitiator('u1'),
        flowToken: 'beta',
      );
      expect(evA!.eventHash, isNot(evB!.eventHash));
      await fxA.backend.close();
      await fxB.backend.close();
    });
  });

  group('EventStore.clearSecurityContext', () {
    // Verifies: REQ-d00138-D — deletes security row and emits
    // security_context_redacted event with the correct fields.
    test(
      'REQ-d00138-D: deletes security row + emits redaction event',
      () async {
        final fx = await _setup();
        final ev = await fx.eventStore.append(
          entryType: 'epistaxis_event',
          entryTypeVersion: 1,
          aggregateId: 'a',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
          security: const SecurityDetails(ipAddress: '1.2.3.4'),
        );
        await fx.eventStore.clearSecurityContext(
          ev!.eventId,
          reason: 'GDPR request',
          redactedBy: const UserInitiator('admin-1'),
        );
        expect(await fx.securityContexts.read(ev.eventId), isNull);

        final events = await fx.backend.findAllEvents();
        final redactionEvent = events.last;
        expect(redactionEvent.entryType, 'security_context_redacted');
        expect(redactionEvent.aggregateType, 'security_context');
        // REQ-d00138-D (revised) + REQ-d00154-D: aggregateId is the install
        // UUID; the redacted subject's eventId moves into
        // data.subject_event_id.
        expect(redactionEvent.aggregateId, fx.eventStore.source.identifier);
        expect(redactionEvent.data['subject_event_id'], ev.eventId);
        expect(redactionEvent.initiator, const UserInitiator('admin-1'));
        expect(redactionEvent.data['reason'], 'GDPR request');
        await fx.backend.close();
      },
    );

    test(
      'REQ-d00138-D: missing eventId throws ArgumentError; no event emitted',
      () async {
        final fx = await _setup();
        await expectLater(
          fx.eventStore.clearSecurityContext(
            'nope',
            reason: 'oops',
            redactedBy: const UserInitiator('admin-1'),
          ),
          throwsArgumentError,
        );
        expect(await fx.backend.findAllEvents(), isEmpty);
        await fx.backend.close();
      },
    );
  });

  group('EventStore.applyRetentionPolicy', () {
    // Verifies: REQ-d00138-E/F — empty sweep emits no compact/purge
    // events. REQ-d00138-H — empty sweep DOES emit a per-sweep
    // retention_policy_applied audit. The audit is the timeline
    // record; the compact/purge events are gated on actual work.
    test('REQ-d00138-E+F+H: empty sweep emits per-sweep audit only', () async {
      final fx = await _setup(now: DateTime.utc(2030, 1, 1));
      final result = await fx.eventStore.applyRetentionPolicy();
      expect(result.compactedCount, 0);
      expect(result.purgedCount, 0);
      final events = await fx.backend.findAllEvents();
      // No compact / purge audit on a zero-effect sweep.
      expect(
        events.any((e) => e.entryType == kSecurityContextCompactedEntryType),
        isFalse,
      );
      expect(
        events.any((e) => e.entryType == kSecurityContextPurgedEntryType),
        isFalse,
      );
      // But the per-sweep retention_policy_applied audit fires
      // unconditionally (REQ-d00138-H).
      final perSweep = events
          .where((e) => e.entryType == kRetentionPolicyAppliedEntryType)
          .toList();
      expect(perSweep, hasLength(1));
      expect(perSweep.single.data['events_truncated'], 0);
      expect(perSweep.single.data['events_purged'], 0);
      await fx.backend.close();
    });

    // Verifies: REQ-d00138-B+E — compact sweep truncates and emits one
    // security_context_compacted event.
    test(
      'REQ-d00138-B+E: compact sweep truncates IP and emits compacted event',
      () async {
        final fixtureNow = DateTime.utc(2030, 1, 1);
        final fx = await _setup(now: fixtureNow);
        // Write an event from 2020 (well past the 90-day full retention
        // window but within 90+365 so it is compacted, not purged).
        final ev = await fx.eventStore.append(
          entryType: 'epistaxis_event',
          entryTypeVersion: 1,
          aggregateId: 'a',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const {'answers': {}},
          initiator: const UserInitiator('u1'),
          security: const SecurityDetails(ipAddress: '203.0.113.7'),
        );
        // Manually backdate the security row to ensure it's past
        // fullRetention.
        final backdated = EventSecurityContext(
          eventId: ev!.eventId,
          recordedAt: DateTime.utc(2029, 1, 1),
          ipAddress: '203.0.113.7',
        );
        await fx.backend.transaction((txn) async {
          await fx.securityContexts.upsertInTxn(txn, backdated);
        });

        final result = await fx.eventStore.applyRetentionPolicy();
        expect(result.compactedCount, 1);
        final events = await fx.backend.findAllEvents();
        final compacted = events.firstWhere(
          (e) => e.entryType == 'security_context_compacted',
        );
        expect(compacted.data['count'], 1);
        final ctx = await fx.securityContexts.read(ev.eventId);
        expect(ctx!.ipAddress, '203.0.113.0');
        await fx.backend.close();
      },
    );
  });
}
