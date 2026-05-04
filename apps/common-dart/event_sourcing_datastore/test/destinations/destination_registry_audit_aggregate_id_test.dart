// Verifies the system-aggregate consolidation rule for destination
// mutation audits: every reserved-system audit emitted by
// DestinationRegistry SHALL stamp `aggregateId = source.identifier`
// (the install UUID), with the destination identity carried in
// `data.id`. This makes the destination-registry audit stream a
// per-install hash-chained system aggregate, while preserving "all
// audits about destination X" queries via `entry_type` + `data.id`.
//
// Verifies: REQ-d00129-J (revised: aggregateId=source.identifier).
// Verifies: REQ-d00129-K (revised: aggregateId=source.identifier).
// Verifies: REQ-d00129-L (revised: aggregateId=source.identifier).
// Verifies: REQ-d00129-M (revised: aggregateId=source.identifier).
// Verifies: REQ-d00144-G (revised: aggregateId=source.identifier).
// Verifies: REQ-d00154-D — system events use the install UUID as their
//   aggregate so each install has a single per-installation
//   hash-chained system aggregate.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fake_destination.dart';
import '../test_support/fifo_entry_helpers.dart';

const _installUUID = 'aaaa1111-2222-3333-4444-555566667777';
const _source = Source(
  hopId: 'mobile-device',
  identifier: _installUUID,
  softwareVersion: 'audit-aggid-test@1.0.0',
);

const _user = UserInitiator('demo-user-1');
const _automation = AutomationInitiator(service: 'test-bootstrap');

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

Future<List<StoredEvent>> _eventsOfType(
  SembastBackend backend,
  String entryType,
) async {
  final all = await backend.findAllEvents();
  return all.where((e) => e.entryType == entryType).toList();
}

void main() {
  group('DestinationRegistry audit aggregateId = source.identifier', () {
    late SembastBackend backend;
    late AppendOnlyDatastore ds;
    var counter = 0;

    setUp(() async {
      counter += 1;
      backend = await _openBackend('reg-audit-aggid-$counter.db');
      ds = await _bootstrap(backend);
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00129-J (revised) — addDestination's
    // destination_registered audit stamps aggregateId = source.identifier;
    // the destination identity moves into data.id.
    test('REQ-d00129-J: destination_registered audit uses source.identifier as '
        'aggregateId; destination identity in data.id', () async {
      final dest = FakeDestination(id: 'primary', allowHardDelete: false);
      await ds.destinations.addDestination(dest, initiator: _user);
      final audits = await _eventsOfType(
        backend,
        kDestinationRegisteredEntryType,
      );
      expect(audits, hasLength(1));
      final audit = audits.single;
      expect(
        audit.aggregateId,
        _installUUID,
        reason:
            'aggregateId MUST be source.identifier, not '
            '"destination:primary"',
      );
      expect(
        audit.data['id'],
        'primary',
        reason: 'destination identity moves into data.id',
      );
    });

    // Verifies: REQ-d00129-K (revised) — setStartDate's
    // destination_start_date_set audit stamps aggregateId =
    // source.identifier; the destination identity stays in data.id.
    test(
      'REQ-d00129-K: destination_start_date_set audit uses source.identifier '
      'as aggregateId',
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
      },
    );

    // Verifies: REQ-d00129-L (revised) — setEndDate's
    // destination_end_date_set audit stamps aggregateId =
    // source.identifier; the destination identity stays in data.id.
    test('REQ-d00129-L: destination_end_date_set audit uses source.identifier '
        'as aggregateId', () async {
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
      await ds.destinations.setEndDate('primary', endDate, initiator: _user);
      final audits = await _eventsOfType(
        backend,
        kDestinationEndDateSetEntryType,
      );
      expect(audits, hasLength(1));
      final audit = audits.single;
      expect(audit.aggregateId, _installUUID);
      expect(audit.data['id'], 'primary');
      expect(audit.data['end_date'], endDate.toUtc().toIso8601String());
    });

    // Verifies: REQ-d00129-M (revised) — deleteDestination's
    // destination_deleted audit stamps aggregateId = source.identifier;
    // the destination identity stays in data.id.
    test('REQ-d00129-M: destination_deleted audit uses source.identifier as '
        'aggregateId', () async {
      await ds.destinations.addDestination(
        FakeDestination(id: 'purgeable', allowHardDelete: true),
        initiator: _automation,
      );
      await ds.destinations.deleteDestination('purgeable', initiator: _user);
      final audits = await _eventsOfType(backend, kDestinationDeletedEntryType);
      expect(audits, hasLength(1));
      final audit = audits.single;
      expect(audit.aggregateId, _installUUID);
      expect(audit.data['id'], 'purgeable');
      expect(audit.data['allow_hard_delete'], isTrue);
    });

    // Verifies: REQ-d00144-G (revised) — tombstoneAndRefill's
    // destination_wedge_recovered audit stamps aggregateId =
    // source.identifier; the destination identity stays in data.id.
    test(
      'REQ-d00144-G: destination_wedge_recovered audit uses source.identifier '
      'as aggregateId',
      () async {
        final dest = FakeDestination(id: 'wedged');
        await ds.destinations.addDestination(dest, initiator: _automation);
        await ds.destinations.setStartDate(
          'wedged',
          DateTime.utc(2026, 1, 1),
          initiator: _automation,
        );
        final head = await enqueueSingle(
          backend,
          'wedged',
          eventId: 'evt-1',
          sequenceNumber: 1,
        );
        await ds.destinations.tombstoneAndRefill(
          'wedged',
          head.entryId,
          initiator: _user,
        );
        final audits = await _eventsOfType(
          backend,
          kDestinationWedgeRecoveredEntryType,
        );
        expect(audits, hasLength(1));
        final audit = audits.single;
        expect(audit.aggregateId, _installUUID);
        expect(audit.data['id'], 'wedged');
        expect(audit.data['target_row_id'], head.entryId);
      },
    );

    // Verifies: REQ-d00154-D — multiple destination mutations on
    // distinct destination ids share a single per-install system
    // aggregate. The audit stream walks one hash-chained aggregate per
    // installation regardless of which destination was mutated.
    test(
      'REQ-d00154-D: multi-destination mutations share one source.identifier '
      'aggregate',
      () async {
        await ds.destinations.addDestination(
          FakeDestination(id: 'alpha'),
          initiator: _automation,
        );
        await ds.destinations.addDestination(
          FakeDestination(id: 'beta'),
          initiator: _automation,
        );
        final all = await backend.findAllEvents();
        final registrations = all
            .where((e) => e.entryType == kDestinationRegisteredEntryType)
            .toList();
        expect(registrations, hasLength(2));
        for (final audit in registrations) {
          expect(
            audit.aggregateId,
            _installUUID,
            reason:
                'every destination_registered audit shares the install '
                'aggregate (REQ-d00154-D)',
          );
        }
        // The two registrations are distinguished by data.id, not by
        // aggregateId.
        final ids = registrations.map((e) => e.data['id']).toSet();
        expect(ids, <String>{'alpha', 'beta'});
      },
    );
  });
}
