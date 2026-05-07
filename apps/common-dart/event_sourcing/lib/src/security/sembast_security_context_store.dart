import 'package:event_sourcing_datastore/src/security/event_security_context.dart';
import 'package:event_sourcing_datastore/src/security/security_context_store.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/txn.dart';
import 'package:sembast/sembast.dart';

/// Sembast-backed `SecurityContextStore`. Maintains one sembast store
/// (`security_context`) keyed on `event_id`. Cross-store reads (the
/// security_context + events join) live on the backend via
/// [SembastBackend.queryAudit]; this store's [queryAudit] is a thin
/// delegator (REQ-d00151-C).
// Implements: REQ-d00137-A+D — sembast sidecar; null on missing.
// Implements: REQ-d00151-C — queryAudit delegates to backend.queryAudit.
class SembastSecurityContextStore extends InternalSecurityContextStore {
  SembastSecurityContextStore({required this.backend});

  final SembastBackend backend;

  final StoreRef<String, Map<String, Object?>> _store = stringMapStoreFactory
      .store('security_context');

  @override
  Future<EventSecurityContext?> read(String eventId) {
    return backend.transaction((txn) => readInTxn(txn, eventId));
  }

  @override
  Future<EventSecurityContext?> readInTxn(Txn txn, String eventId) async {
    final sembastTxn = _castTxn(txn);
    final raw = await _store.record(eventId).get(sembastTxn);
    if (raw == null) return null;
    return EventSecurityContext.fromJson(Map<String, Object?>.from(raw));
  }

  @override
  Future<void> writeInTxn(Txn txn, EventSecurityContext row) async {
    final sembastTxn = _castTxn(txn);
    await _store.record(row.eventId).put(sembastTxn, row.toJson());
  }

  @override
  Future<void> upsertInTxn(Txn txn, EventSecurityContext row) =>
      writeInTxn(txn, row);

  @override
  Future<void> deleteInTxn(Txn txn, String eventId) async {
    final sembastTxn = _castTxn(txn);
    await _store.record(eventId).delete(sembastTxn);
  }

  @override
  Future<List<EventSecurityContext>> findUnredactedOlderThanInTxn(
    Txn txn,
    DateTime cutoff,
  ) async {
    final sembastTxn = _castTxn(txn);
    final cutoffIso = cutoff.toUtc().toIso8601String();
    final finder = Finder(
      filter: Filter.and([
        Filter.isNull('redacted_at'),
        Filter.lessThanOrEquals('recorded_at', cutoffIso),
      ]),
    );
    final records = await _store.find(sembastTxn, finder: finder);
    return records
        .map(
          (r) =>
              EventSecurityContext.fromJson(Map<String, Object?>.from(r.value)),
        )
        .toList();
  }

  @override
  Future<List<EventSecurityContext>> findOlderThanInTxn(
    Txn txn,
    DateTime cutoff,
  ) async {
    final sembastTxn = _castTxn(txn);
    final cutoffIso = cutoff.toUtc().toIso8601String();
    final finder = Finder(
      filter: Filter.lessThanOrEquals('recorded_at', cutoffIso),
    );
    final records = await _store.find(sembastTxn, finder: finder);
    return records
        .map(
          (r) =>
              EventSecurityContext.fromJson(Map<String, Object?>.from(r.value)),
        )
        .toList();
  }

  // Implements: REQ-d00151-C — thin delegator; the cross-store join lives
  // on the backend (REQ-d00151-A+B) so consumers cannot reach past the
  // abstraction to perform their own joins.
  @override
  Future<PagedAudit> queryAudit({
    Initiator? initiator,
    String? flowToken,
    String? ipAddress,
    DateTime? from,
    DateTime? to,
    int limit = 50,
    String? cursor,
  }) => backend.queryAudit(
    initiator: initiator,
    flowToken: flowToken,
    ipAddress: ipAddress,
    from: from,
    to: to,
    limit: limit,
    cursor: cursor,
  );

  Transaction _castTxn(Txn txn) {
    // Unwrap via the backend's transaction() — test-side txns passed in
    // must have been produced by backend.transaction(). We can't access
    // the private _SembastTxn directly, so the convention is to use the
    // txn via the backend's view methods. This concrete store is paired
    // with SembastBackend-produced transactions.
    return backend.unwrapSembastTxn(txn);
  }
}
