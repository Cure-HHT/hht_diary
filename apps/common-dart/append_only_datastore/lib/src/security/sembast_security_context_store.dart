import 'dart:convert';

import 'package:append_only_datastore/src/security/event_security_context.dart';
import 'package:append_only_datastore/src/security/security_context_store.dart';
import 'package:append_only_datastore/src/storage/initiator.dart';
import 'package:append_only_datastore/src/storage/sembast_backend.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:append_only_datastore/src/storage/txn.dart';
import 'package:sembast/sembast.dart';

/// Sembast-backed `SecurityContextStore`. Maintains one sembast store
/// (`security_context`) keyed on `event_id`, plus `queryAudit` that joins
/// rows with the event log under the single backend database.
// Implements: REQ-d00137-A+D+F — sembast sidecar; null on missing; queryAudit
// pagination and filter contract.
class SembastSecurityContextStore extends InternalSecurityContextStore {
  SembastSecurityContextStore({required this.backend});

  final SembastBackend backend;

  final StoreRef<String, Map<String, Object?>> _store = stringMapStoreFactory
      .store('security_context');
  final StoreRef<int, Map<String, Object?>> _eventStore = intMapStoreFactory
      .store('events');

  @override
  Future<EventSecurityContext?> read(String eventId) async {
    final db = backend.debugDatabase();
    final raw = await _store.record(eventId).get(db);
    if (raw == null) return null;
    return EventSecurityContext.fromJson(Map<String, Object?>.from(raw));
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

  @override
  Future<PagedAudit> queryAudit({
    Initiator? initiator,
    String? flowToken,
    String? ipAddress,
    DateTime? from,
    DateTime? to,
    int limit = 50,
    String? cursor,
  }) async {
    if (limit < 1 || limit > 1000) {
      throw ArgumentError.value(
        limit,
        'limit',
        'queryAudit limit must be in [1, 1000] (REQ-d00137-F)',
      );
    }

    _CursorPoint? decodedCursor;
    if (cursor != null) {
      try {
        decodedCursor = _CursorPoint.decode(cursor);
      } on Object catch (e) {
        throw ArgumentError.value(cursor, 'cursor', 'corrupt cursor: $e');
      }
    }

    final db = backend.debugDatabase();

    // 1. Filter security rows by ipAddress + date range.
    final securityFilters = <Filter>[];
    if (ipAddress != null) {
      securityFilters.add(Filter.equals('ip_address', ipAddress));
    }
    if (from != null) {
      securityFilters.add(
        Filter.greaterThanOrEquals(
          'recorded_at',
          from.toUtc().toIso8601String(),
        ),
      );
    }
    if (to != null) {
      securityFilters.add(
        Filter.lessThanOrEquals('recorded_at', to.toUtc().toIso8601String()),
      );
    }
    // NOTE: we re-sort the join result in memory (see `rows.sort(...)`
    // below) so the in-memory order is authoritative for pagination; the
    // Sembast sort matches it only for clarity / debuggability.
    final securityFinder = Finder(
      filter: securityFilters.isEmpty
          ? null
          : (securityFilters.length == 1
                ? securityFilters.single
                : Filter.and(securityFilters)),
      sortOrders: [
        SortOrder('recorded_at', false),
        SortOrder(Field.key, false),
      ],
    );
    final securityRecords = await _store.find(db, finder: securityFinder);
    final securityByEventId = <String, EventSecurityContext>{
      for (final r in securityRecords)
        r.key: EventSecurityContext.fromJson(
          Map<String, Object?>.from(r.value),
        ),
    };
    if (securityByEventId.isEmpty) {
      return const PagedAudit(rows: <AuditRow>[]);
    }

    // 2. Fetch matching events.
    final eventFilters = <Filter>[
      Filter.inList('event_id', securityByEventId.keys.toList()),
    ];
    if (flowToken != null) {
      eventFilters.add(Filter.equals('flow_token', flowToken));
    }
    final eventFinder = Finder(
      filter: eventFilters.length == 1
          ? eventFilters.single
          : Filter.and(eventFilters),
    );
    final eventRecords = await _eventStore.find(db, finder: eventFinder);
    var events = eventRecords
        .map((r) => StoredEvent.fromMap(r.value, r.key))
        .toList();
    if (initiator != null) {
      events = events.where((e) => e.initiator == initiator).toList();
    }

    // 3. Inner join + sort by recordedAt desc.
    final rows = <AuditRow>[];
    for (final event in events) {
      final ctx = securityByEventId[event.eventId];
      if (ctx == null) continue;
      rows.add(AuditRow(event: event, context: ctx));
    }
    rows.sort((a, b) {
      final cmp = b.context.recordedAt.compareTo(a.context.recordedAt);
      if (cmp != 0) return cmp;
      return b.event.eventId.compareTo(a.event.eventId);
    });

    // 4. Apply cursor (lower bound) if provided.
    final filtered = decodedCursor == null
        ? rows
        : rows.where((r) {
            final cmp = r.context.recordedAt.compareTo(
              decodedCursor!.recordedAt,
            );
            if (cmp < 0) return true;
            if (cmp == 0) {
              return r.event.eventId.compareTo(decodedCursor.eventId) < 0;
            }
            return false;
          }).toList();

    // 5. Paginate.
    final page = filtered.take(limit).toList();
    final nextCursor = filtered.length > limit
        ? _CursorPoint(
            recordedAt: page.last.context.recordedAt,
            eventId: page.last.event.eventId,
          ).encode()
        : null;
    return PagedAudit(rows: page, nextCursor: nextCursor);
  }

  Transaction _castTxn(Txn txn) {
    // Unwrap via the backend's transaction() — test-side txns passed in
    // must have been produced by backend.transaction(). We can't access
    // the private _SembastTxn directly, so the convention is to use the
    // txn via the backend's view methods. This concrete store is paired
    // with SembastBackend-produced transactions.
    return backend.unwrapSembastTxn(txn);
  }
}

class _CursorPoint {
  const _CursorPoint({required this.recordedAt, required this.eventId});

  factory _CursorPoint.decode(String encoded) {
    final raw = utf8.decode(base64Url.decode(encoded));
    final parts = raw.split('|');
    if (parts.length != 2) throw const FormatException('bad cursor shape');
    return _CursorPoint(
      recordedAt: DateTime.parse(parts[0]),
      eventId: parts[1],
    );
  }

  final DateTime recordedAt;
  final String eventId;

  String encode() {
    final raw = '${recordedAt.toUtc().toIso8601String()}|$eventId';
    return base64Url.encode(utf8.encode(raw));
  }
}
