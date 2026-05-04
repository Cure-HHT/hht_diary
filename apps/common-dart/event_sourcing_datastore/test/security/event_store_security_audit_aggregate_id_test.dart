// Verifies that EventStore's three reserved-system audit emission
// sites — clearSecurityContext (security_context_redacted), retention
// compact / purge (security_context_compacted /
// security_context_purged), and per-sweep retention_policy_applied —
// stamp `aggregateId = source.identifier` (the install UUID). Each
// install therefore has a single per-installation hash-chained system
// aggregate spanning bootstrap, destination registry, and security /
// retention audits.
//
// Verifies: REQ-d00138-D (revised: aggregateId=source.identifier on
//   security_context_redacted; subject_event_id moves to data field).
// Verifies: REQ-d00138-E (revised: aggregateId=source.identifier on
//   security_context_compacted).
// Verifies: REQ-d00138-F (revised: aggregateId=source.identifier on
//   security_context_purged).
// Verifies: REQ-d00138-H (revised: aggregateId=source.identifier on
//   system.retention_policy_applied).
// Verifies: REQ-d00154-D — system events use the install UUID as their
//   aggregate.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

const _installUUID = 'cccc3333-4444-5555-6666-777788889999';
const _source = Source(
  hopId: 'mobile-device',
  identifier: _installUUID,
  softwareVersion: 'sec-audit-aggid-test@1.0.0',
);

class _Fixture {
  _Fixture({
    required this.eventStore,
    required this.backend,
    required this.securityContexts,
  });
  final EventStore eventStore;
  final SembastBackend backend;
  final SembastSecurityContextStore securityContexts;
}

EntryTypeDefinition _simpleDef(String id) => EntryTypeDefinition(
  id: id,
  registeredVersion: 1,
  name: id,
  widgetId: 'w',
  widgetConfig: const <String, Object?>{},
);

Future<_Fixture> _setup({DateTime? now}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'sec-audit-aggid-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  final registry = EntryTypeRegistry();
  for (final defn in kSystemEntryTypes) {
    registry.register(defn);
  }
  registry.register(_simpleDef('epistaxis_event'));
  final securityContexts = SembastSecurityContextStore(backend: backend);
  final eventStore = EventStore(
    backend: backend,
    entryTypes: registry,
    source: _source,
    securityContexts: securityContexts,
    clock: now == null ? null : () => now,
  );
  return _Fixture(
    eventStore: eventStore,
    backend: backend,
    securityContexts: securityContexts,
  );
}

void main() {
  group(
    'EventStore security/retention audit aggregateId = source.identifier',
    () {
      // Verifies: REQ-d00138-D (revised) — clearSecurityContext stamps
      // aggregateId = source.identifier; the subject event id moves into
      // data so callers can still query "all redactions of event X" by
      // filtering on entry_type AND data.subject_event_id.
      test(
        'REQ-d00138-D: security_context_redacted audit uses source.identifier '
        'as aggregateId',
        () async {
          final fx = await _setup();
          final ev = await fx.eventStore.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'a',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const <String, Object?>{'answers': <String, Object?>{}},
            initiator: const UserInitiator('u1'),
            security: const SecurityDetails(ipAddress: '1.2.3.4'),
          );
          await fx.eventStore.clearSecurityContext(
            ev!.eventId,
            reason: 'GDPR request',
            redactedBy: const UserInitiator('admin-1'),
          );
          final all = await fx.backend.findAllEvents();
          final audit = all.firstWhere(
            (e) => e.entryType == kSecurityContextRedactedEntryType,
          );
          expect(
            audit.aggregateId,
            _installUUID,
            reason:
                'aggregateId MUST be source.identifier, not the redacted '
                "event's own id",
          );
          expect(
            audit.data['subject_event_id'],
            ev.eventId,
            reason: 'redaction subject moves into data.subject_event_id',
          );
          expect(audit.data['reason'], 'GDPR request');
          await fx.backend.close();
        },
      );

      // Verifies: REQ-d00138-E (revised) — security_context_compacted
      // stamps aggregateId = source.identifier, not a per-sweep
      // synthesized id.
      // Verifies: REQ-d00138-F (revised) — security_context_purged
      // stamps aggregateId = source.identifier, not a per-sweep
      // synthesized id.
      // Verifies: REQ-d00138-H (revised) — retention_policy_applied
      // stamps aggregateId = source.identifier, not 'security-retention'.
      test(
        'REQ-d00138-E+F+H: compact, purge, and retention_policy_applied audits '
        'use source.identifier as aggregateId',
        () async {
          final fixtureNow = DateTime.utc(2030, 1, 1);
          final fx = await _setup(now: fixtureNow);

          // Seed a security row in the compact window (past 90 days, but
          // within 90 + 365) so a compact emission lands.
          final evCompact = await fx.eventStore.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'a',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const <String, Object?>{'answers': <String, Object?>{}},
            initiator: const UserInitiator('u1'),
            security: const SecurityDetails(ipAddress: '203.0.113.7'),
          );
          await fx.backend.transaction((txn) async {
            await fx.securityContexts.upsertInTxn(
              txn,
              EventSecurityContext(
                eventId: evCompact!.eventId,
                recordedAt: DateTime.utc(2029, 1, 1),
                ipAddress: '203.0.113.7',
              ),
            );
          });

          // Seed a security row past the purge window (older than 90 +
          // 365 days) so a purge emission lands.
          final evPurge = await fx.eventStore.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'b',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const <String, Object?>{'answers': <String, Object?>{}},
            initiator: const UserInitiator('u1'),
            security: const SecurityDetails(ipAddress: '198.51.100.5'),
          );
          await fx.backend.transaction((txn) async {
            await fx.securityContexts.upsertInTxn(
              txn,
              EventSecurityContext(
                eventId: evPurge!.eventId,
                recordedAt: DateTime.utc(2020, 1, 1),
                ipAddress: '198.51.100.5',
              ),
            );
          });

          await fx.eventStore.applyRetentionPolicy();

          final all = await fx.backend.findAllEvents();
          final compactAudit = all.firstWhere(
            (e) => e.entryType == kSecurityContextCompactedEntryType,
          );
          final purgeAudit = all.firstWhere(
            (e) => e.entryType == kSecurityContextPurgedEntryType,
          );
          final perSweepAudit = all.firstWhere(
            (e) => e.entryType == kRetentionPolicyAppliedEntryType,
          );
          expect(compactAudit.aggregateId, _installUUID);
          expect(purgeAudit.aggregateId, _installUUID);
          expect(perSweepAudit.aggregateId, _installUUID);
          await fx.backend.close();
        },
      );

      // Verifies: REQ-d00154-D — across the bootstrap, retention, and
      // redaction audit streams, every system event a single install
      // emits shares the same aggregateId. The system aggregate is one
      // hash-chained timeline per installation.
      test(
        'REQ-d00154-D: bootstrap + retention + redaction audits all share the '
        'install aggregate',
        () async {
          final fx = await _setup(now: DateTime.utc(2030, 1, 1));
          final ev = await fx.eventStore.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'a',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const <String, Object?>{'answers': <String, Object?>{}},
            initiator: const UserInitiator('u1'),
            security: const SecurityDetails(ipAddress: '1.2.3.4'),
          );
          await fx.eventStore.clearSecurityContext(
            ev!.eventId,
            reason: 'request',
            redactedBy: const UserInitiator('admin-1'),
          );
          await fx.eventStore.applyRetentionPolicy();
          final all = await fx.backend.findAllEvents();
          final systemEntryTypes = <String>{
            kSecurityContextRedactedEntryType,
            kRetentionPolicyAppliedEntryType,
          };
          final systemAudits = all
              .where((e) => systemEntryTypes.contains(e.entryType))
              .toList();
          expect(systemAudits, isNotEmpty);
          for (final audit in systemAudits) {
            expect(
              audit.aggregateId,
              _installUUID,
              reason:
                  'every system audit shares the install aggregate '
                  '(REQ-d00154-D)',
            );
          }
          await fx.backend.close();
        },
      );
    },
  );
}
