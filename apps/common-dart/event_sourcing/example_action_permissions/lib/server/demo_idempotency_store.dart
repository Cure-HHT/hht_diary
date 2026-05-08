// lib/server/demo_idempotency_store.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00170-D,E (REQ-IDEMPOT) — same contract as InMemoryIdempotencyStore;
//   adds an inspection-only `listEntries()` for the demo inspector pane.

import 'package:event_sourcing/event_sourcing.dart';
import 'package:meta/meta.dart';

/// Inspector-only read of one cache slot. Hides `resultJson` /
/// `emittedEventIds` so the inspector pane never shows the cached
/// payload itself — only that a slot exists and when it expires.
@immutable
class DemoIdempotencyEntrySnapshot {
  const DemoIdempotencyEntrySnapshot({
    required this.actionName,
    required this.principalId,
    required this.idempotencyKey,
    required this.expiresAt,
  });

  final String actionName;
  final String principalId;
  final String idempotencyKey;
  final DateTime expiresAt;
}

/// In-memory `IdempotencyStore` that exposes a sorted snapshot of every
/// cached slot for the inspector pane. Same store contract as
/// `InMemoryIdempotencyStore` — use this in the demo so the inspector
/// can render the cache.
class DemoIdempotencyStore implements IdempotencyStore {
  DemoIdempotencyStore();

  final Map<String, _Slot> _slots = <String, _Slot>{};

  String _composite(String a, String p, String k) => '$a|$p|$k';

  @override
  Future<IdempotencyEntry?> lookup(
    String actionName,
    String principalId,
    String key, {
    DateTime? now,
  }) async {
    final slot = _slots[_composite(actionName, principalId, key)];
    if (slot == null) return null;
    if (slot.entry.isExpired(now: now ?? DateTime.now())) return null;
    return slot.entry;
  }

  @override
  Future<void> record({
    required String actionName,
    required String principalId,
    required String key,
    required Map<String, dynamic> resultJson,
    required List<String> emittedEventIds,
    required DateTime expiresAt,
  }) async {
    _slots[_composite(actionName, principalId, key)] = _Slot(
      actionName: actionName,
      principalId: principalId,
      idempotencyKey: key,
      entry: IdempotencyEntry(
        resultJson: Map<String, dynamic>.unmodifiable(resultJson),
        emittedEventIds: List<String>.unmodifiable(emittedEventIds),
        recordedAt: DateTime.now(),
        expiresAt: expiresAt,
      ),
    );
  }

  @override
  Future<int> sweepExpired({DateTime? before}) async {
    final cutoff = before ?? DateTime.now();
    final keys = _slots.entries
        .where((e) => e.value.entry.isExpired(now: cutoff))
        .map((e) => e.key)
        .toList();
    for (final k in keys) {
      _slots.remove(k);
    }
    return keys.length;
  }

  /// Inspector-only snapshot of every cache entry. Sorted by
  /// (actionName, principalId, idempotencyKey).
  List<DemoIdempotencyEntrySnapshot> listEntries() {
    final list =
        _slots.values
            .map(
              (s) => DemoIdempotencyEntrySnapshot(
                actionName: s.actionName,
                principalId: s.principalId,
                idempotencyKey: s.idempotencyKey,
                expiresAt: s.entry.expiresAt,
              ),
            )
            .toList()
          ..sort((a, b) {
            final ac = a.actionName.compareTo(b.actionName);
            if (ac != 0) return ac;
            final pc = a.principalId.compareTo(b.principalId);
            if (pc != 0) return pc;
            return a.idempotencyKey.compareTo(b.idempotencyKey);
          });
    return list;
  }
}

class _Slot {
  const _Slot({
    required this.actionName,
    required this.principalId,
    required this.idempotencyKey,
    required this.entry,
  });

  final String actionName;
  final String principalId;
  final String idempotencyKey;
  final IdempotencyEntry entry;
}
