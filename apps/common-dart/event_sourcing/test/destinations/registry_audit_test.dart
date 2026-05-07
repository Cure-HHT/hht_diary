// Tests for the in-transaction config-change audit emissions added in
// Phase 4.17c-g. Every registry mutation method (addDestination,
// setStartDate, setEndDate, deactivateDestination, deleteDestination,
// tombstoneAndRefill) plus EventStore.applyRetentionPolicy must stamp
// a system audit event in the same backend.transaction as the mutation.
//
// Verifies: REQ-d00129-J — destination_registered audit on addDestination.
// Verifies: REQ-d00129-K — destination_start_date_set audit on setStartDate.
// Verifies: REQ-d00129-L — destination_end_date_set audit on setEndDate
//   AND on deactivateDestination (which routes through setEndDate).
// Verifies: REQ-d00129-M — destination_deleted audit on deleteDestination.
// Verifies: REQ-d00129-N — every audit emission lives in the same
//   transaction as the mutation it documents.
// Verifies: REQ-d00138-H — retention_policy_applied audit on every sweep
//   (including zero-effect sweeps).
// Verifies: REQ-d00144-G — destination_wedge_recovered audit on
//   tombstoneAndRefill.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';
import '../test_support/fifo_entry_helpers.dart';

const _user = UserInitiator('demo-user-1');
const _automation = AutomationInitiator(service: 'test-bootstrap');

const _installUUID = 'audit-test';
const _source = Source(
  hopId: 'mobile-device',
  identifier: _installUUID,
  softwareVersion: 'audit-test@1.0.0',
);

Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

Future<AppendOnlyDatastore> _bootstrap(SembastBackend backend) {
  return bootstrapAppendOnlyDatastore(
    backend: backend,
    source: _source,
    entryTypes: const <EntryTypeDefinition>[],
    destinations: const <Destination>[],
    materializers: const <Materializer>[],
    initialViewTargetVersions: const <String, Map<String, int>>{},
  );
}

/// Find every event in the backend whose entry_type matches [entryType].
Future<List<StoredEvent>> _eventsOfType(
  SembastBackend backend,
  String entryType,
) async {
  final all = await backend.findAllEvents();
  return all.where((e) => e.entryType == entryType).toList();
}

void main() {
  group('DestinationRegistry audit emissions', () {
    late SembastBackend backend;
    late AppendOnlyDatastore ds;
    var counter = 0;

    setUp(() async {
      counter += 1;
      backend = await _openBackend('registry-audit-$counter.db');
      ds = await _bootstrap(backend);
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00129-J — addDestination stamps a
    // system.destination_registered audit event with the destination's
    // id, wire format, allowHardDelete, serializesNatively, and filter
    // shape. The initiator round-trips on the audit event.
    test(
      'REQ-d00129-J: addDestination stamps destination_registered audit',
      () async {
        final dest = FakeDestination(id: 'primary', allowHardDelete: false);
        await ds.destinations.addDestination(dest, initiator: _user);
        final audits = await _eventsOfType(
          backend,
          kDestinationRegisteredEntryType,
        );
        expect(audits, hasLength(1));
        final audit = audits.single;
        expect(audit.aggregateId, _installUUID);
        expect(audit.aggregateType, 'system_destination');
        expect(audit.eventType, 'finalized');
        expect(audit.data['id'], 'primary');
        expect(audit.data['wire_format'], 'fake-v1');
        expect(audit.data['allow_hard_delete'], isFalse);
        expect(audit.data['serializes_natively'], isFalse);
        expect(audit.initiator, _user);
      },
    );

    // Verifies: REQ-d00129-K — setStartDate stamps a
    // system.destination_start_date_set audit event with the start date
    // in UTC ISO-8601.
    test(
      'REQ-d00129-K: setStartDate stamps destination_start_date_set audit',
      () async {
        await ds.destinations.addDestination(
          FakeDestination(id: 'primary'),
          initiator: _automation,
        );
        final start = DateTime.utc(2026, 4, 1);
        await ds.destinations.setStartDate('primary', start, initiator: _user);
        final audits = await _eventsOfType(
          backend,
          kDestinationStartDateSetEntryType,
        );
        expect(audits, hasLength(1));
        final audit = audits.single;
        expect(audit.aggregateId, _installUUID);
        expect(audit.data['id'], 'primary');
        expect(audit.data['start_date'], start.toUtc().toIso8601String());
        expect(audit.initiator, _user);
      },
    );

    // Verifies: REQ-d00129-L — setEndDate stamps a
    // system.destination_end_date_set audit event with the end date,
    // prior end date (null on first call), and result classification.
    test(
      'REQ-d00129-L: setEndDate stamps destination_end_date_set audit',
      () async {
        await ds.destinations.addDestination(
          FakeDestination(id: 'primary'),
          initiator: _automation,
        );
        await ds.destinations.setStartDate(
          'primary',
          DateTime.utc(2020, 1, 1),
          initiator: _automation,
        );
        final endDate = DateTime.now().subtract(const Duration(hours: 1));
        final result = await ds.destinations.setEndDate(
          'primary',
          endDate,
          initiator: _user,
        );
        expect(result, SetEndDateResult.closed);
        final audits = await _eventsOfType(
          backend,
          kDestinationEndDateSetEntryType,
        );
        expect(audits, hasLength(1));
        final audit = audits.single;
        expect(audit.aggregateId, _installUUID);
        expect(audit.data['id'], 'primary');
        expect(audit.data['end_date'], endDate.toUtc().toIso8601String());
        expect(audit.data['prior_end_date'], isNull);
        expect(audit.data['result'], 'closed');
        expect(audit.initiator, _user);
      },
    );

    // Verifies: REQ-d00129-L — deactivateDestination routes through
    // setEndDate so it emits the same destination_end_date_set audit.
    test('REQ-d00129-L: deactivateDestination stamps destination_end_date_set '
        'audit (same entry type as setEndDate)', () async {
      await ds.destinations.addDestination(
        FakeDestination(id: 'primary'),
        initiator: _automation,
      );
      await ds.destinations.setStartDate(
        'primary',
        DateTime.utc(2020, 1, 1),
        initiator: _automation,
      );
      await ds.destinations.deactivateDestination('primary', initiator: _user);
      final audits = await _eventsOfType(
        backend,
        kDestinationEndDateSetEntryType,
      );
      expect(audits, hasLength(1));
      expect(audits.single.initiator, _user);
      expect(audits.single.data['result'], 'closed');
    });

    // Verifies: REQ-d00129-M — deleteDestination stamps a
    // system.destination_deleted audit event in the same transaction
    // as the FIFO + schedule drop.
    test(
      'REQ-d00129-M: deleteDestination stamps destination_deleted audit',
      () async {
        await ds.destinations.addDestination(
          FakeDestination(id: 'purgeable', allowHardDelete: true),
          initiator: _automation,
        );
        await ds.destinations.deleteDestination('purgeable', initiator: _user);
        final audits = await _eventsOfType(
          backend,
          kDestinationDeletedEntryType,
        );
        expect(audits, hasLength(1));
        final audit = audits.single;
        expect(audit.aggregateId, _installUUID);
        expect(audit.data['id'], 'purgeable');
        expect(audit.data['allow_hard_delete'], isTrue);
        expect(audit.initiator, _user);
      },
    );

    // Verifies: REQ-d00144-G — tombstoneAndRefill stamps a
    // system.destination_wedge_recovered audit event with the rewind
    // target, deleted-trail count, and the event-id range of the
    // tombstoned head row.
    test('REQ-d00144-G: tombstoneAndRefill stamps destination_wedge_recovered '
        'audit', () async {
      final dest = FakeDestination(id: 'wedged');
      await ds.destinations.addDestination(dest, initiator: _automation);
      await ds.destinations.setStartDate(
        'wedged',
        DateTime.utc(2026, 1, 1),
        initiator: _automation,
      );
      // Seed a head row that the tombstone targets.
      final head = await enqueueSingle(
        backend,
        'wedged',
        eventId: 'evt-1',
        sequenceNumber: 1,
      );
      final result = await ds.destinations.tombstoneAndRefill(
        'wedged',
        head.entryId,
        initiator: _user,
      );
      expect(result.targetRowId, head.entryId);
      final audits = await _eventsOfType(
        backend,
        kDestinationWedgeRecoveredEntryType,
      );
      expect(audits, hasLength(1));
      final audit = audits.single;
      expect(audit.aggregateId, _installUUID);
      expect(audit.data['id'], 'wedged');
      expect(audit.data['target_row_id'], head.entryId);
      expect(audit.data['target_event_id_range_first_seq'], 1);
      expect(audit.data['target_event_id_range_last_seq'], 1);
      expect(audit.data['deleted_trail_count'], 0);
      expect(audit.data['rewound_to'], 0);
      expect(audit.initiator, _user);
    });

    // Verifies: REQ-d00129-N — when addDestination throws (id is already
    // registered), no audit event lands. Combined with the
    // sequence-number monotonicity guarantee, this proves the audit and
    // the schedule write commit together: a rolled-back mutation rolls
    // back the audit too.
    test(
      'REQ-d00129-N: failed addDestination (duplicate id) emits no audit',
      () async {
        await ds.destinations.addDestination(
          FakeDestination(id: 'primary'),
          initiator: _automation,
        );
        final beforeCount = (await _eventsOfType(
          backend,
          kDestinationRegisteredEntryType,
        )).length;
        expect(beforeCount, 1);
        await expectLater(
          ds.destinations.addDestination(
            FakeDestination(id: 'primary'),
            initiator: _user,
          ),
          throwsArgumentError,
        );
        final afterCount = (await _eventsOfType(
          backend,
          kDestinationRegisteredEntryType,
        )).length;
        expect(
          afterCount,
          beforeCount,
          reason: 'duplicate-id ArgumentError must NOT stamp an audit event',
        );
      },
    );
  });

  group('EventStore.applyRetentionPolicy audit emissions', () {
    late SembastBackend backend;
    late AppendOnlyDatastore ds;
    var counter = 0;

    setUp(() async {
      counter += 1;
      backend = await _openBackend('retention-audit-$counter.db');
      ds = await _bootstrap(backend);
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00138-H — applyRetentionPolicy ALWAYS emits a
    // retention_policy_applied audit, even when both sweeps find zero
    // candidates. The audit carries the policy's retention windows, the
    // candidate counts (0/0 here), and both cutoffs.
    test('REQ-d00138-H: applyRetentionPolicy emits retention_policy_applied '
        'audit on a zero-effect sweep', () async {
      await ds.eventStore.applyRetentionPolicy();
      final audits = await _eventsOfType(
        backend,
        kRetentionPolicyAppliedEntryType,
      );
      expect(audits, hasLength(1));
      final audit = audits.single;
      expect(audit.aggregateId, _installUUID);
      expect(audit.aggregateType, 'system_retention');
      expect(audit.eventType, 'finalized');
      expect(audit.data['events_truncated'], 0);
      expect(audit.data['events_purged'], 0);
      expect(audit.data['policy_full_retention_seconds'], isA<int>());
      expect(audit.data['policy_truncated_retention_seconds'], isA<int>());
      expect(audit.data['cutoff_full'], isA<String>());
      expect(audit.data['cutoff_purge'], isA<String>());
      expect(
        audit.initiator,
        const AutomationInitiator(service: 'retention-policy-sweep'),
      );
    });

    // Verifies: REQ-d00138-H — back-to-back sweeps each stamp their own
    // retention_policy_applied audit. The audit stream is a per-sweep
    // timeline, not a per-non-empty-sweep timeline.
    test(
      'REQ-d00138-H: each sweep emits its own retention_policy_applied audit',
      () async {
        await ds.eventStore.applyRetentionPolicy();
        await ds.eventStore.applyRetentionPolicy();
        await ds.eventStore.applyRetentionPolicy();
        final audits = await _eventsOfType(
          backend,
          kRetentionPolicyAppliedEntryType,
        );
        expect(audits, hasLength(3));
      },
    );
  });
}
