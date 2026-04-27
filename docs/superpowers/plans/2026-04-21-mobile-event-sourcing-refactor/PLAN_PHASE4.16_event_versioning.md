# Phase 4.16 Implementation Plan: Per-Event Versioning

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stamp two `int` version fields on every `StoredEvent` — `entry_type_version` (caller-supplied to `EventStore.append`) and `lib_format_version` (lib-stamped from a constant). Both required, hash-chained, propagated over the wire, validated at ingest with an asymmetric `receiver_version >= author_version` rule.

**Architecture:** Add two top-level fields to `StoredEvent`. Replace `EntryTypeDefinition.version: String` (dead) with `registeredVersion: int`. Add `entryTypeVersion` as a required named parameter on `EventStore.append`. Stamp `lib_format_version` from `StoredEvent.currentLibFormatVersion = 1` automatically. Add two new ingest exception types and a pre-chain-1 check in `ingestBatch` that throws them on receiver-behind-author conditions. Caller-side mechanical fixup of every `append` callsite, every `EntryTypeDefinition` constructor, and the bridge.

**Tech Stack:** Dart 3.10 / Flutter 3.38, sembast, `event_sourcing_datastore` lib + example app.

**Spec:** `docs/superpowers/specs/2026-04-25-phase4.16-event-versioning-design.md`

**Working tree root for all paths below:** `/home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor`

---

## Task 1: Spec amendments (REQ-d00116, REQ-d00118, REQ-d00141, REQ-d00145) via elspais MCP

**Files:**
- Modify: `spec/dev-event-sourcing-mobile.md` (the elspais mutator writes here)
- Modify: `spec/INDEX.md` (recompute hashes after mutations)

This task is mechanical — it runs through the elspais MCP tools and lets the validator regenerate INDEX.md. The full assertion text for each amendment is in the design spec under §Requirements.

- [ ] **Step 1: Load elspais MCP tools**

```
ToolSearch query: select:mcp__elspais__mutate_update_assertion,mcp__elspais__mutate_add_assertion,mcp__elspais__refresh_graph,mcp__elspais__save_mutations
```

Confirm five mutator tools are loaded.

- [ ] **Step 2: REQ-d00116 — replace assertion B (version → registered_version)**

Use `mcp__elspais__mutate_update_assertion`:
- `assertion_id: "REQ-d00116-B"`
- `text: "An EntryTypeDefinition SHALL carry a registered_version integer identifying the highest entry_type_version this lib build's registry will accept on EventStore.ingestBatch. Assertion replaces the previous version string assertion; the dead string field is deleted from the code path and the JSON shape."`

- [ ] **Step 3: REQ-d00118 — add assertions E and F**

Use `mcp__elspais__mutate_add_assertion` twice:

`REQ-d00118-E`:
> Every event record SHALL carry a top-level `entry_type_version` integer field whose value identifies the application schema version under which the event was authored. The value is supplied by the caller of `EventStore.append` and is preserved verbatim across wire transport (REQ-d00145-B) and receiver ingest (REQ-d00145-K).

`REQ-d00118-F`:
> Every event record SHALL carry a top-level `lib_format_version` integer field whose value identifies the storage shape the lib used to persist the event. The value is stamped by the lib at `EventStore.append` time from the constant `StoredEvent.currentLibFormatVersion`; callers of `EventStore.append` SHALL NOT supply this field.

- [ ] **Step 4: REQ-d00141 — amend B; add E and F**

Update `REQ-d00141-B` to add `entryTypeVersion` to the documented signature (full text in spec §Requirements §REQ-d00141).

Add `REQ-d00141-E`:
> `EventStore.append` SHALL stamp `StoredEvent.lib_format_version` from the constant `StoredEvent.currentLibFormatVersion` on every event written, regardless of caller input. The constant SHALL be defined exactly once in the lib at `lib/src/storage/stored_event.dart` and SHALL identify the storage shape the current lib build produces.

Add `REQ-d00141-F`:
> `EventStore.append` SHALL NOT validate the caller-supplied `entryTypeVersion` against `EntryTypeDefinition.registered_version` of the local registry. Local append is the local node's prerogative; cross-node validation is performed at ingest per REQ-d00145.

- [ ] **Step 5: REQ-d00145 — amend K; add L and M**

Update `REQ-d00145-K` to enumerate the two new fields among receiver-immutable identity fields (full text in spec §Requirements §REQ-d00145).

Add `REQ-d00145-L`:
> Before chain-1 verify (REQ-d00145-C), `ingestBatch` SHALL evaluate `incoming.lib_format_version > StoredEvent.currentLibFormatVersion`; on true, SHALL raise `IngestLibFormatVersionAhead` carrying the offending `event_id`, `wire_version`, and `receiver_version`, rolling back the entire batch.

Add `REQ-d00145-M`:
> After the lib-format check (REQ-d00145-L) and before chain-1 verify (REQ-d00145-C), `ingestBatch` SHALL look up `def = registry.byId(incoming.entry_type)`; when `def != null` and `incoming.entry_type_version > def.registered_version`, SHALL raise `IngestEntryTypeVersionAhead` carrying the offending `event_id`, `entry_type`, `wire_version`, and `receiver_version`, rolling back the entire batch. When `def == null`, the existing pre-version-check failure path is unchanged.

- [ ] **Step 6: Save mutations + refresh graph**

```
mcp__elspais__save_mutations()
mcp__elspais__refresh_graph()
```

This regenerates `spec/INDEX.md` content hashes.

- [ ] **Step 7: Commit**

```bash
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor add spec/dev-event-sourcing-mobile.md spec/INDEX.md
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor commit -m "$(cat <<'EOF'
[CUR-1154] spec: amend REQs for phase 4.16 per-event versioning

REQ-d00116-B: version: string -> registered_version: int.
REQ-d00118-E,F (new): entry_type_version + lib_format_version on every event.
REQ-d00141-B,E,F: append signature + lib_format_version stamping + no local
  validation against registry.
REQ-d00145-K,L,M: enumerate new fields as receiver-immutable + asymmetric
  version-ahead validation rules.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add `currentLibFormatVersion` constant + extend `StoredEvent`

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/storage/stored_event.dart`
- Test: `apps/common-dart/event_sourcing_datastore/test/storage/stored_event_test.dart` (extend existing)

`StoredEvent` gains two required `final int` fields, a public `currentLibFormatVersion` constant, and corresponding `toMap`/`fromMap`/`equals`/`hashCode`/`synthetic` updates.

- [ ] **Step 1: Write failing tests first**

Extend `test/storage/stored_event_test.dart` with new test groups (find a sensible insertion point — likely after the existing fromMap tests):

```dart
group('REQ-d00118-E,F: entry_type_version + lib_format_version fields', () {
  test('REQ-d00118-E: toMap includes entry_type_version', () {
    final e = StoredEvent.synthetic(
      eventId: 'e-1', aggregateId: 'a-1', entryType: 'demo_note',
      initiator: const UserInitiator('u-1'),
      clientTimestamp: DateTime.utc(2026, 4, 26),
      eventHash: 'hash-1',
      entryTypeVersion: 7,
    );
    expect(e.toMap()['entry_type_version'], 7);
  });

  test('REQ-d00118-F: toMap includes lib_format_version', () {
    final e = StoredEvent.synthetic(
      eventId: 'e-1', aggregateId: 'a-1', entryType: 'demo_note',
      initiator: const UserInitiator('u-1'),
      clientTimestamp: DateTime.utc(2026, 4, 26),
      eventHash: 'hash-1',
      libFormatVersion: 3,
    );
    expect(e.toMap()['lib_format_version'], 3);
  });

  test('REQ-d00118-E: fromMap rejects missing entry_type_version', () {
    final m = _validEventMap()..remove('entry_type_version');
    expect(() => StoredEvent.fromMap(m, 0), throwsFormatException);
  });

  test('REQ-d00118-E: fromMap rejects non-int entry_type_version', () {
    final m = _validEventMap()..['entry_type_version'] = 'not-an-int';
    expect(() => StoredEvent.fromMap(m, 0), throwsFormatException);
  });

  test('REQ-d00118-F: fromMap rejects missing lib_format_version', () {
    final m = _validEventMap()..remove('lib_format_version');
    expect(() => StoredEvent.fromMap(m, 0), throwsFormatException);
  });

  test('REQ-d00118-F: fromMap rejects non-int lib_format_version', () {
    final m = _validEventMap()..['lib_format_version'] = true;
    expect(() => StoredEvent.fromMap(m, 0), throwsFormatException);
  });

  test('REQ-d00118-E,F: round-trip preserves both fields', () {
    final m = _validEventMap()
      ..['entry_type_version'] = 11
      ..['lib_format_version'] = 1;
    final e = StoredEvent.fromMap(m, 0);
    expect(e.entryTypeVersion, 11);
    expect(e.libFormatVersion, 1);
  });

  test('REQ-d00141-E: currentLibFormatVersion is 1', () {
    expect(StoredEvent.currentLibFormatVersion, 1);
  });
});

Map<String, Object?> _validEventMap() => <String, Object?>{
  'event_id': 'e-1',
  'aggregate_id': 'a-1',
  'aggregate_type': 'DiaryEntry',
  'entry_type': 'demo_note',
  'event_type': 'finalized',
  'sequence_number': 1,
  'data': <String, Object?>{},
  'metadata': <String, Object?>{},
  'initiator': const UserInitiator('u-1').toJson(),
  'flow_token': null,
  'client_timestamp': DateTime.utc(2026, 4, 26).toIso8601String(),
  'event_hash': 'hash-1',
  'previous_event_hash': null,
  'entry_type_version': 1,
  'lib_format_version': 1,
};
```

- [ ] **Step 2: Run tests — all six should fail**

```bash
(cd /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/apps/common-dart/event_sourcing_datastore && flutter test test/storage/stored_event_test.dart)
```

Expected: compile error (unknown parameter `entryTypeVersion`/`libFormatVersion`, unknown getter `currentLibFormatVersion`). That's the TDD baseline.

- [ ] **Step 3: Modify `StoredEvent`**

Edit `lib/src/storage/stored_event.dart`. Three coordinated changes:

(a) Add the public constant immediately after the class opening dartdoc / above the class:

```dart
class StoredEvent {
  /// Storage shape version the current lib build produces. Stamped on every
  /// event by [EventStore.append] and propagated over the wire. Receivers
  /// reject events whose `lib_format_version > currentLibFormatVersion` per
  /// REQ-d00145-L.
  // Implements: REQ-d00141-E.
  static const int currentLibFormatVersion = 1;
```

(b) Update the constructor + add the two `final int` fields. Find the existing `const StoredEvent({...})` block and add the two parameters as required, plus add the two field declarations alongside the others:

```dart
  const StoredEvent({
    required this.key,
    required this.eventId,
    required this.aggregateId,
    required this.aggregateType,
    required this.entryType,
    required this.entryTypeVersion,        // NEW
    required this.libFormatVersion,        // NEW
    required this.eventType,
    required this.sequenceNumber,
    required this.data,
    required this.metadata,
    required this.initiator,
    required this.clientTimestamp,
    required this.eventHash,
    this.flowToken,
    this.previousEventHash,
  });
  // ... existing fields ...
  /// Application schema version under which this event was authored.
  /// Caller-supplied to [EventStore.append]. Preserved verbatim across the
  /// wire (REQ-d00118-E).
  final int entryTypeVersion;

  /// Storage shape version this event was persisted with. Stamped by the
  /// lib from [currentLibFormatVersion] (REQ-d00118-F).
  final int libFormatVersion;
```

Update the class-level traceability comment to add these REQ refs.

(c) Update `fromMap`, `toMap`, `synthetic`. In `fromMap`, after the existing field validations, add:

```dart
    final entryTypeVersion = _requireInt(map, 'entry_type_version');
    final libFormatVersion = _requireInt(map, 'lib_format_version');
```

and pass them in the returned `StoredEvent(...)`. In `toMap`, add the two keys:

```dart
      'entry_type_version': entryTypeVersion,
      'lib_format_version': libFormatVersion,
```

In `synthetic`, add named parameters with sensible defaults:

```dart
  factory StoredEvent.synthetic({
    // ... existing params ...
    int entryTypeVersion = 1,
    int libFormatVersion = 1,
  }) => StoredEvent(
    // ... existing args ...
    entryTypeVersion: entryTypeVersion,
    libFormatVersion: libFormatVersion,
    // ... rest ...
  );
```

(There's no existing `==` / `hashCode` on `StoredEvent` — `key`-based identity suffices, so no changes there.)

- [ ] **Step 4: Run the new tests — all pass**

```bash
(cd /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/apps/common-dart/event_sourcing_datastore && flutter test test/storage/stored_event_test.dart)
```

Existing tests in this file may now fail to compile because callsites construct `StoredEvent` without the new required params. That's expected — Task 9 (callsite migration) handles them. For now, isolate to running just the new test group:

```bash
(cd /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/apps/common-dart/event_sourcing_datastore && flutter test test/storage/stored_event_test.dart -p chrome -N 'REQ-d00118')
```

If the test runner doesn't support `-N` filter, just verify the file compiles for the new tests by visual inspection — the migration in Task 9 will catch the rest.

- [ ] **Step 5: Don't commit yet**

This task creates a partially-broken state (existing callsites won't compile until Tasks 3–9 land). Land Tasks 2–9 as one logical unit. No commit until Task 9.

---

## Task 3: Replace `EntryTypeDefinition.version: String` with `registeredVersion: int`

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/entry_type_definition.dart`
- Test: existing tests in this file (extend or replace)

The dead `version: String` field is removed and replaced with `registeredVersion: int`. Same constructor position; new JSON key `registered_version`.

- [ ] **Step 1: Edit `entry_type_definition.dart`**

Find the constructor:

```dart
  const EntryTypeDefinition({
    required this.id,
    required this.version,            // DELETE this line
    required this.name,
    // ...
  });
```

Replace with:

```dart
  const EntryTypeDefinition({
    required this.id,
    required this.registeredVersion,
    required this.name,
    // ...
  });
```

Find the field:

```dart
  /// Schema version under which events of this type are written.
  final String version;             // DELETE
```

Replace with:

```dart
  /// Highest `entry_type_version` this lib build's registry accepts on
  /// `EventStore.ingestBatch`. Today (single-version world) it's the only
  /// value; Phase 4.21 may expand to a Set<int> for multi-sponsor concurrency.
  // Implements: REQ-d00116-B.
  final int registeredVersion;
```

Update `fromJson`. Find:

```dart
    final version = _requireString(json, 'version');
```

Replace with:

```dart
    final registeredVersion = _requireInt(json, 'registered_version');
```

Update `toJson`. Find `'version': version,` and replace with `'registered_version': registeredVersion,`.

Update `==`, `hashCode`, `toString` to reference `registeredVersion` instead of `version`.

Add a `_requireInt` helper at the bottom (mirror existing `_requireString`):

```dart
int _requireInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('EntryTypeDefinition: missing or non-int "$key"');
  }
  return value;
}
```

- [ ] **Step 2: Update existing `EntryTypeDefinition` tests**

In `test/entry_type_definition_test.dart` (path may need confirmation — search via `grep -rn "EntryTypeDefinition()" test/`), replace every `version: 'something'` with `registeredVersion: 1`. Add a new test group:

```dart
group('REQ-d00116-B: registered_version replaces version field', () {
  test('fromJson rejects missing registered_version', () {
    final m = _validJson()..remove('registered_version');
    expect(() => EntryTypeDefinition.fromJson(m), throwsFormatException);
  });
  test('fromJson rejects non-int registered_version', () {
    final m = _validJson()..['registered_version'] = '1';
    expect(() => EntryTypeDefinition.fromJson(m), throwsFormatException);
  });
  test('toJson uses snake_case key', () {
    final d = EntryTypeDefinition(
      id: 'demo', registeredVersion: 5, name: 'Demo',
      widgetId: 'w', widgetConfig: const <String, Object?>{});
    expect(d.toJson()['registered_version'], 5);
    expect(d.toJson().containsKey('version'), isFalse);
  });
});
```

(Adjust `_validJson()` helper to use `'registered_version': 1` instead of `'version': '1.0.0'`.)

- [ ] **Step 3: Don't run tests yet (broader migration in flight). Move to Task 4.**

---

## Task 4: Add new ingest exception types

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/ingest/ingest_errors.dart`
- Modify: `apps/common-dart/event_sourcing_datastore/lib/event_sourcing_datastore.dart` (export new types)

Two new exception classes alongside the existing ones (`IngestDecodeFailure`, `IngestChainBroken`, `IngestIdentityMismatch`).

- [ ] **Step 1: Add the new classes to `ingest_errors.dart`**

Append to the file:

```dart
/// Thrown by `EventStore.ingestBatch` when an incoming event's
/// `lib_format_version` exceeds the receiver's `StoredEvent.currentLibFormatVersion`.
/// The receiver cannot interpret the event's storage shape; the entire batch
/// is rolled back. Operator action: upgrade the receiver lib.
// Implements: REQ-d00145-L.
class IngestLibFormatVersionAhead implements Exception {
  const IngestLibFormatVersionAhead({
    required this.eventId,
    required this.wireVersion,
    required this.receiverVersion,
  });
  final String eventId;
  final int wireVersion;
  final int receiverVersion;
  @override
  String toString() =>
      'IngestLibFormatVersionAhead(event_id: $eventId, '
      'wire: $wireVersion, receiver: $receiverVersion)';
}

/// Thrown by `EventStore.ingestBatch` when an incoming event's
/// `entry_type_version` exceeds `EntryTypeDefinition.registered_version` for
/// its `entry_type` in the receiver's registry. Operator action: upgrade
/// the receiver's entry-type registry to register the new version.
// Implements: REQ-d00145-M.
class IngestEntryTypeVersionAhead implements Exception {
  const IngestEntryTypeVersionAhead({
    required this.eventId,
    required this.entryType,
    required this.wireVersion,
    required this.receiverVersion,
  });
  final String eventId;
  final String entryType;
  final int wireVersion;
  final int receiverVersion;
  @override
  String toString() =>
      'IngestEntryTypeVersionAhead(event_id: $eventId, entry_type: $entryType, '
      'wire: $wireVersion, receiver: $receiverVersion)';
}
```

- [ ] **Step 2: Export from `event_sourcing_datastore.dart`**

Find the existing ingest-error export:

```dart
export 'src/ingest/ingest_errors.dart'
    show IngestChainBroken, IngestDecodeFailure, IngestIdentityMismatch;
```

Replace with:

```dart
export 'src/ingest/ingest_errors.dart'
    show
        IngestChainBroken,
        IngestDecodeFailure,
        IngestEntryTypeVersionAhead,
        IngestIdentityMismatch,
        IngestLibFormatVersionAhead;
```

(Alphabetical for consistency with neighboring exports.)

- [ ] **Step 3: Move to Task 5**

---

## Task 5: Update `EventStore.append` — required `entryTypeVersion`; stamp `libFormatVersion`

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart`
- Test: `apps/common-dart/event_sourcing_datastore/test/event_store/append_versioning_test.dart` (new)

`append` gains a required `int entryTypeVersion` named parameter. The `StoredEvent` it constructs uses that value for `entryTypeVersion` and `StoredEvent.currentLibFormatVersion` for `libFormatVersion`.

- [ ] **Step 1: Write failing tests first**

Create the new test file:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<EventStore> _bootstrap() async {
  final db = await newDatabaseFactoryMemory().openDatabase('append-versioning.db');
  final backend = SembastBackend(database: db);
  final ds = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: const Source(
      hopId: 'mobile-device', identifier: 'demo-device',
      softwareVersion: 'test',
    ),
    entryTypes: <EntryTypeDefinition>[
      EntryTypeDefinition(
        id: 'demo_note',
        registeredVersion: 5,
        name: 'demo_note', widgetId: 'w', widgetConfig: const <String, Object?>{},
      ),
    ],
    destinations: const <Destination>[],
    materializers: const <Materializer>[],
  );
  return ds.eventStore;
}

void main() {
  group('REQ-d00141-B,E: EventStore.append stamps version fields', () {
    test('REQ-d00141-B: caller-supplied entry_type_version is stamped verbatim', () async {
      final es = await _bootstrap();
      final stored = await es.append(
        entryType: 'demo_note',
        entryTypeVersion: 3,        // caller picks 3 even though registry registers 5
        aggregateId: 'a-1',
        aggregateType: 'DiaryEntry',
        eventType: 'finalized',
        data: const <String, Object?>{'answers': <String, Object?>{}},
        initiator: const UserInitiator('u-1'),
      );
      expect(stored!.entryTypeVersion, 3);
    });

    test('REQ-d00141-E: lib_format_version stamped from currentLibFormatVersion', () async {
      final es = await _bootstrap();
      final stored = await es.append(
        entryType: 'demo_note', entryTypeVersion: 5,
        aggregateId: 'a-1', aggregateType: 'DiaryEntry', eventType: 'finalized',
        data: const <String, Object?>{'answers': <String, Object?>{}},
        initiator: const UserInitiator('u-1'),
      );
      expect(stored!.libFormatVersion, StoredEvent.currentLibFormatVersion);
    });

    test('REQ-d00141-F: append does NOT validate entryTypeVersion against registry', () async {
      // Registry says registeredVersion=5; caller passes 99. append should accept.
      final es = await _bootstrap();
      final stored = await es.append(
        entryType: 'demo_note', entryTypeVersion: 99,
        aggregateId: 'a-1', aggregateType: 'DiaryEntry', eventType: 'finalized',
        data: const <String, Object?>{'answers': <String, Object?>{}},
        initiator: const UserInitiator('u-1'),
      );
      expect(stored!.entryTypeVersion, 99);
    });
  });
}
```

- [ ] **Step 2: Edit `event_store.dart`**

Find the `append` method signature. Add `required int entryTypeVersion` to the named parameters. Inside the method body where `StoredEvent` is constructed, pass `entryTypeVersion: entryTypeVersion` and `libFormatVersion: StoredEvent.currentLibFormatVersion`.

(The exact location inside the method: search for `StoredEvent(` calls in the body; there's usually one or two — one for the new event being appended, possibly another in helper paths. Update each.)

Update the dartdoc for `append` to mention the new required parameter:

```dart
  /// Appends one event to the event log. The caller MUST supply
  /// [entryTypeVersion]; the lib stamps `lib_format_version` from
  /// [StoredEvent.currentLibFormatVersion].
  // Implements: REQ-d00141-B+E+F.
  Future<StoredEvent?> append({
    required String entryType,
    required int entryTypeVersion,        // NEW
    // ... existing params ...
  }) async {
```

- [ ] **Step 3: Run the new test file**

```bash
(cd /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/apps/common-dart/event_sourcing_datastore && flutter test test/event_store/append_versioning_test.dart)
```

Expected: 3 PASS. (Other test files in the repo may not compile yet — Task 9 fixes them.)

- [ ] **Step 4: Move to Task 6**

---

## Task 6: Add version-ahead validation in `ingestBatch`

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/lib/src/event_store.dart`
- Test: `apps/common-dart/event_sourcing_datastore/test/event_store/ingest_version_validation_test.dart` (new)

Inside `ingestBatch`'s per-event loop, BEFORE the chain-1 verify call, add the asymmetric `>=` validation. Throw the new typed exceptions on failure (which roll back the txn per existing semantics).

- [ ] **Step 1: Write failing tests first**

Create the new test file:

```dart
import 'dart:typed_data';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

// Helper: build an esd/batch@1 envelope manually with a given event map.
Uint8List _envelope({
  required String entryType,
  required int entryTypeVersion,
  required int libFormatVersion,
}) {
  // Minimal valid envelope. Exact fields per REQ-d00118 + REQ-d00115.
  // ... (see SyntheticBatchBuilder for shape, but allow caller to override
  //      entry_type_version / lib_format_version for the test).
  // For brevity, the implementer should adapt SyntheticBatchBuilder OR
  // construct the JSON directly here.
  // Returns the canonical-JSON bytes of the envelope.
  throw UnimplementedError('Implementer: factor out from SyntheticBatchBuilder');
}

Future<EventStore> _bootstrapWithRegistry({required int registeredVersion}) async {
  final db = await newDatabaseFactoryMemory().openDatabase('ingest-validation-${DateTime.now().millisecondsSinceEpoch}.db');
  final backend = SembastBackend(database: db);
  final ds = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: const Source(
      hopId: 'portal', identifier: 'demo-portal',
      softwareVersion: 'test',
    ),
    entryTypes: <EntryTypeDefinition>[
      EntryTypeDefinition(
        id: 'demo_note',
        registeredVersion: registeredVersion,
        name: 'demo_note', widgetId: 'w', widgetConfig: const <String, Object?>{},
      ),
    ],
    destinations: const <Destination>[],
    materializers: const <Materializer>[],
  );
  return ds.eventStore;
}

void main() {
  group('REQ-d00145-L: lib_format_version-ahead', () {
    test('throws IngestLibFormatVersionAhead and rolls back batch', () async {
      final es = await _bootstrapWithRegistry(registeredVersion: 1);
      final bytes = _envelope(
        entryType: 'demo_note', entryTypeVersion: 1,
        libFormatVersion: StoredEvent.currentLibFormatVersion + 1,
      );
      await expectLater(
        es.ingestBatch(bytes, wireFormat: BatchEnvelope.wireFormat),
        throwsA(isA<IngestLibFormatVersionAhead>()),
      );
      // No event landed.
      // (Use es-internal backend to verify; or use findAllEvents if exposed.)
    });
  });

  group('REQ-d00145-M: entry_type_version-ahead', () {
    test('throws IngestEntryTypeVersionAhead and rolls back batch', () async {
      final es = await _bootstrapWithRegistry(registeredVersion: 2);
      final bytes = _envelope(
        entryType: 'demo_note', entryTypeVersion: 5,
        libFormatVersion: 1,
      );
      await expectLater(
        es.ingestBatch(bytes, wireFormat: BatchEnvelope.wireFormat),
        throwsA(isA<IngestEntryTypeVersionAhead>()),
      );
    });
  });

  group('validation order', () {
    test('lib-ahead checked before entry-type-ahead', () async {
      final es = await _bootstrapWithRegistry(registeredVersion: 2);
      final bytes = _envelope(
        entryType: 'demo_note', entryTypeVersion: 5,           // also too high
        libFormatVersion: StoredEvent.currentLibFormatVersion + 1, // also too high
      );
      await expectLater(
        es.ingestBatch(bytes, wireFormat: BatchEnvelope.wireFormat),
        throwsA(isA<IngestLibFormatVersionAhead>()),
      );
    });
  });

  group('happy path', () {
    test('matched versions ingest cleanly', () async {
      final es = await _bootstrapWithRegistry(registeredVersion: 5);
      final bytes = _envelope(
        entryType: 'demo_note', entryTypeVersion: 3, libFormatVersion: 1,
      );
      final result = await es.ingestBatch(bytes, wireFormat: BatchEnvelope.wireFormat);
      expect(result.events.length, 1);
    });
  });
}
```

The implementer must factor `_envelope(...)` from `apps/common-dart/event_sourcing_datastore/example/lib/synthetic_ingest.dart`'s `SyntheticBatchBuilder` (which is in the example, not in the lib's tests). Either copy the relevant logic into the test file or extract a test-support helper into `lib/test/` if appropriate.

- [ ] **Step 2: Add the validation helper inside `ingestBatch`**

Edit `lib/src/event_store.dart`. Inside the per-event loop in `ingestBatch`, add the validation BEFORE `_ingestOneInTxn` (which runs chain-1 verify):

```dart
    await backend.transaction((txn) async {
      for (var i = 0; i < envelope.events.length; i++) {
        final eventMap = envelope.events[i];
        final storedEvent = StoredEvent.fromMap(
          Map<String, Object?>.from(eventMap), 0,
        );
        // Implements: REQ-d00145-L. Lib-format check runs first.
        if (storedEvent.libFormatVersion > StoredEvent.currentLibFormatVersion) {
          throw IngestLibFormatVersionAhead(
            eventId: storedEvent.eventId,
            wireVersion: storedEvent.libFormatVersion,
            receiverVersion: StoredEvent.currentLibFormatVersion,
          );
        }
        // Implements: REQ-d00145-M. Entry-type check second; def==null falls
        // through to existing failure path inside _ingestOneInTxn.
        final def = entryTypes.byId(storedEvent.entryType);
        if (def != null && storedEvent.entryTypeVersion > def.registeredVersion) {
          throw IngestEntryTypeVersionAhead(
            eventId: storedEvent.eventId,
            entryType: storedEvent.entryType,
            wireVersion: storedEvent.entryTypeVersion,
            receiverVersion: def.registeredVersion,
          );
        }
        // ... existing _ingestOneInTxn call ...
      }
    });
```

(Adjust to the actual variable names in `event_store.dart`. The registry is accessed as a class field on `EventStore`; the actual symbol is `_entryTypes` or similar — confirm by reading the file.)

- [ ] **Step 3: Run the new test file**

```bash
(cd /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/apps/common-dart/event_sourcing_datastore && flutter test test/event_store/ingest_version_validation_test.dart)
```

Expected: all 4 PASS.

- [ ] **Step 4: Move to Task 7**

---

## Task 7: Mechanical callsite migration in `lib/`

**Files:** Multiple. Touch every callsite that constructs `EntryTypeDefinition` or calls `EventStore.append`. The compiler's missing-required-parameter errors are the work-list — each error gets a fix.

- [ ] **Step 1: Run `flutter analyze` in the lib package; collect every missing-required-parameter error**

```bash
(cd /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/apps/common-dart/event_sourcing_datastore && flutter analyze 2>&1 | grep -E "(missing_required_argument|undefined_named_parameter)" | head -40)
```

The expected error categories:
- `EntryTypeDefinition(...)` callsites missing `registeredVersion` or referring to a now-deleted `version`
- `EventStore.append(...)` callsites missing `entryTypeVersion`
- `StoredEvent(...)` direct constructions missing `entryTypeVersion`/`libFormatVersion` (only in test fixtures and possibly internal lib helpers; production code goes through `append`)

- [ ] **Step 2: Walk the error list and apply fixes**

Pattern for each:

| Where | Fix |
| --- | --- |
| `EntryTypeDefinition(version: 'x', ...)` | `EntryTypeDefinition(registeredVersion: 1, ...)` |
| `EntryTypeDefinition.fromJson({'version': 'x', ...})` (test fixtures) | `{'registered_version': 1, ...}` |
| `eventStore.append(entryType: '...', ...)` (in tests / lib helpers) | add `entryTypeVersion: 1` |
| Direct `StoredEvent(...)` constructions | add `entryTypeVersion: 1, libFormatVersion: 1` |
| Direct `StoredEvent.synthetic(...)` constructions | (already gets defaults) — only update if a specific version is needed |

For the lib's own internal `_appendReceiverProvenance` / `_buildIngestEvent` paths inside `event_store.dart`, the `entryTypeVersion` and `libFormatVersion` fields come straight from the wire (they were just decoded by `StoredEvent.fromMap` in `ingestBatch`) and are already on the `StoredEvent` instance — no change needed there.

For the system-entry-type emit paths (security_context_redacted/compacted/purged), the lib emits via `EventStore.append`; supply `entryTypeVersion: 1` (the lib's version for system entry types).

- [ ] **Step 3: Verify analyze + tests clean**

```bash
(cd /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/apps/common-dart/event_sourcing_datastore && flutter analyze && flutter test)
```

Expected: analyze clean, all existing lib tests + the 7 new tests from Tasks 2/3/5/6 pass.

- [ ] **Step 4: Move to Task 8**

---

## Task 8: Mechanical callsite migration in `example/`

**Files:** Same idea as Task 7 but in the example app.

- [ ] **Step 1: Run analyze in example dir**

```bash
(cd /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/apps/common-dart/event_sourcing_datastore/example && flutter analyze)
```

- [ ] **Step 2: Walk callsites**

Files most likely to need updates:
- `example/lib/demo_types.dart` — `allDemoEntryTypes` uses `EntryTypeDefinition(...)` constructors. Add `registeredVersion: 1` to each.
- `example/lib/widgets/top_action_bar.dart` — `_record(...)` calls `eventStore.append(...)`. Add `entryTypeVersion: 1`.
- `example/lib/synthetic_ingest.dart` — `SyntheticBatchBuilder.buildSingleEventBatch` builds an event map manually; the map needs `'entry_type_version': 1` and `'lib_format_version': 1` added.
- `example/test/portal_sync_test.dart` — `_appendDemoNote(...)` — add `entryTypeVersion: 1`.
- `example/test/portal_soak_test.dart` — same pattern in append helpers.
- `example/integration_test/dual_pane_test.dart` — same.
- `example/test/native_demo_destination_test.dart` and `downstream_bridge_test.dart` — they use `SyntheticBatchBuilder`; since it now stamps the new fields, no change needed at the test level once the helper is updated.

- [ ] **Step 3: Update `DownstreamBridge` to map the two new exceptions**

Edit `example/lib/downstream_bridge.dart`. Find the existing `try { ... } on IngestDecodeFailure ... on IngestChainBroken ... on IngestIdentityMismatch ...` block. Add two more `on` arms before the catch-all:

```dart
    try {
      await _target.ingestBatch(
        payload.bytes,
        wireFormat: payload.contentType,
      );
      return const SendOk();
    } on IngestDecodeFailure catch (e) {
      return SendPermanent(error: e.toString());
    } on IngestIdentityMismatch catch (e) {
      return SendPermanent(error: e.toString());
    } on IngestChainBroken catch (e) {
      return SendPermanent(error: e.toString());
    } on IngestLibFormatVersionAhead catch (e) {              // NEW
      return SendPermanent(error: e.toString());
    } on IngestEntryTypeVersionAhead catch (e) {              // NEW
      return SendPermanent(error: e.toString());
    } catch (e) {
      return SendTransient(error: e.toString());
    }
```

Update the class dartdoc to add the two new exceptions to the mapping table.

- [ ] **Step 4: Add bridge test cases for the two new mappings**

Extend `example/test/downstream_bridge_test.dart`. Add two test cases inside the existing `group('DownstreamBridge.deliver', () { ... })`:

```dart
test('REQ-d00145-L: IngestLibFormatVersionAhead → SendPermanent', () async {
  final stub = _ThrowingEventStore(const IngestLibFormatVersionAhead(
    eventId: 'e-1', wireVersion: 2, receiverVersion: 1,
  ));
  final bridge = DownstreamBridge(stub);
  final result = await bridge.deliver(_wirePayload(Uint8List.fromList(<int>[1])));
  expect(result, isA<SendPermanent>());
});

test('REQ-d00145-M: IngestEntryTypeVersionAhead → SendPermanent', () async {
  final stub = _ThrowingEventStore(const IngestEntryTypeVersionAhead(
    eventId: 'e-1', entryType: 'demo_note',
    wireVersion: 5, receiverVersion: 2,
  ));
  final bridge = DownstreamBridge(stub);
  final result = await bridge.deliver(_wirePayload(Uint8List.fromList(<int>[1])));
  expect(result, isA<SendPermanent>());
});
```

The existing `_ThrowingEventStore` stub throws a fixed `StateError` — extend it to accept an arbitrary exception in its constructor:

```dart
class _ThrowingEventStore implements EventStore {
  _ThrowingEventStore([this._toThrow = const _DefaultThrow()]);
  final Object _toThrow;
  @override
  Future<IngestBatchResult> ingestBatch(Uint8List bytes, {required String wireFormat}) {
    throw _toThrow;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _DefaultThrow implements Exception { const _DefaultThrow(); }
```

- [ ] **Step 5: Verify**

```bash
(cd /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/apps/common-dart/event_sourcing_datastore/example && flutter analyze && flutter test)
```

Expected: analyze clean, all tests pass.

Also run integration test to verify the dual-pane app still builds (no need to actually launch on Linux):

```bash
(cd /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/apps/common-dart/event_sourcing_datastore/example && flutter analyze integration_test/)
```

- [ ] **Step 6: Move to Task 9**

---

## Task 9: Atomic commit of Tasks 2–8

The intermediate state is unbuildable, so we land it as one commit.

- [ ] **Step 1: Stage all touched files**

```bash
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor add \
    apps/common-dart/event_sourcing_datastore/lib \
    apps/common-dart/event_sourcing_datastore/test \
    apps/common-dart/event_sourcing_datastore/example
```

- [ ] **Step 2: Verify build is green**

```bash
(cd /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/apps/common-dart/event_sourcing_datastore && flutter analyze && flutter test)
(cd /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/apps/common-dart/event_sourcing_datastore/example && flutter analyze && flutter test)
```

Both must be clean.

- [ ] **Step 3: Commit**

```bash
git -C /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor commit -m "$(cat <<'EOF'
[CUR-1154] phase 4.16 — per-event versioning (entry_type + lib_format)

Two int version fields stamped on every StoredEvent:
- entry_type_version: caller-supplied to EventStore.append (compile-time
  enforced via Dart's required keyword)
- lib_format_version: lib-stamped from StoredEvent.currentLibFormatVersion
  on every append, regardless of caller input

Both required, hash-chained via toMap canonical JSON, propagated verbatim
over the wire inside BatchEnvelope.events[]. Receivers reject events
where wire_version > receiver_version with new typed exceptions:
- IngestLibFormatVersionAhead (REQ-d00145-L)
- IngestEntryTypeVersionAhead (REQ-d00145-M)

Validation runs before chain-1 verify; rolls back the entire batch on
either exception. Unknown-entry-type case unchanged (existing path).

EntryTypeDefinition.version: String replaced with registeredVersion: int.
The String field was dead in the codebase. registered_version is the
highest entry_type_version this lib build's registry will accept.

Bridge maps both new exceptions to SendPermanent (matching decode/identity/
chain mappings). Mobile FIFO row goes final-failed; operator runbook is
"upgrade portal first, then mobile fleet".

Mechanical: every EventStore.append callsite gains entryTypeVersion:; every
EntryTypeDefinition constructor gains registeredVersion:; SyntheticBatchBuilder
stamps both new fields on the wire event map.

Implements: REQ-d00116-B, REQ-d00118-E+F, REQ-d00141-B+E+F, REQ-d00145-K+L+M.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:**
- REQ-d00118-E,F (event fields) → Task 2.
- REQ-d00141-B,E,F (append signature + stamping + no-validation) → Task 5.
- REQ-d00116-B (registeredVersion) → Task 3.
- REQ-d00145-L,M (asymmetric ingest validation) → Task 6.
- REQ-d00145-K (receiver-immutable enumeration) → no code change; assertion text amendment in Task 1.
- Bridge mapping → Task 8 step 3.
- Test coverage for each REQ → Tasks 2, 3, 5, 6, 8.

**Placeholder scan:** None. All code blocks executable; the only `UnimplementedError` is in Task 6's `_envelope(...)` helper with explicit instruction for the implementer to factor from `SyntheticBatchBuilder`.

**Type consistency:** `entryTypeVersion`/`libFormatVersion` consistent across `StoredEvent`, `EventStore.append`, exception fields, JSON snake_case, test code.

**One pre-flight risk:** the `_envelope(...)` helper in Task 6 needs the implementer to construct or factor an envelope. If `SyntheticBatchBuilder` is reusable from the test file (it lives in the example, not the lib), the lib test may need to either copy the relevant logic or import from the example via a `path:` dev dep. Either is acceptable; document the choice in the test file's header comment.
