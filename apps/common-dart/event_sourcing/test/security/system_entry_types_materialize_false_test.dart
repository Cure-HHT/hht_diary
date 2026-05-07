// Verifies: REQ-d00154-D — all 10 reserved system entry types ship
//   materialize:false. Cross-aggregate stream events stay out of view-
//   side projection on every install, on both the local-append path
//   and the ingest path (the outer gate `def.materialize` short-
//   circuits the materializer loop in `_appendInTxn` and
//   `_ingestOneInTxn` before any materializer is consulted).
//
// Regression intent: a future refactor that flips one of the ten
//   `EntryTypeDefinition` records to `materialize: true` would silently
//   start firing materializers on cross-aggregate stream events, which
//   is out of scope for Phase 4.22. This test fails loudly if that
//   happens.
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

const Source _source = Source(
  hopId: 'mobile-device',
  identifier: 'install-materialize-false-test',
  softwareVersion: 'pkg@0.0.1',
);

void main() {
  group('Reserved system entry types — materialize:false (REQ-d00154-D)', () {
    // Verifies: REQ-d00154-D — every reserved system entry type
    //   auto-registered by `bootstrapAppendOnlyDatastore` ships
    //   `materialize: false`. Iteration is driven from
    //   `kReservedSystemEntryTypeIds` and the registry is consulted
    //   post-bootstrap so the test exercises the actual auto-registered
    //   `EntryTypeDefinition` instances rather than re-importing the
    //   internal `kSystemEntryTypes` list.
    test('REQ-d00154-D: all 10 reserved system entry types have '
        'materialize:false', () async {
      final db = await newDatabaseFactoryMemory().openDatabase(
        'mat-false-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final backend = SembastBackend(database: db);
      try {
        final datastore = await bootstrapAppendOnlyDatastore(
          backend: backend,
          source: _source,
          entryTypes: const <EntryTypeDefinition>[],
          destinations: const <Destination>[],
          materializers: const <Materializer>[],
          initialViewTargetVersions: const <String, Map<String, int>>{},
        );

        // The reserved id set is the canonical list of system entry
        // types and SHALL be exactly 10. A change here implies a new
        // system entry type was added without flipping this assertion;
        // the test forces an explicit decision on whether the new id
        // also ships materialize:false.
        expect(
          kReservedSystemEntryTypeIds.length,
          equals(10),
          reason:
              'kReservedSystemEntryTypeIds is the canonical 10-element '
              'set per REQ-d00154-D; adding a new system entry type '
              'requires updating this expectation explicitly.',
        );

        for (final id in kReservedSystemEntryTypeIds) {
          final defn = datastore.entryTypes.byId(id);
          expect(
            defn,
            isNotNull,
            reason:
                'reserved system entry type "$id" must be auto-registered '
                'by bootstrapAppendOnlyDatastore (REQ-d00134-B).',
          );
          expect(
            defn!.materialize,
            isFalse,
            reason:
                '$id MUST ship materialize:false to keep cross-aggregate '
                'stream events out of view-side projection (REQ-d00154-D). '
                'Flipping a reserved system entry type to materialize:true '
                'would start firing materializers on system audits — out '
                'of scope for Phase 4.22.',
          );
        }
      } finally {
        await backend.close();
      }
    });
  });
}
