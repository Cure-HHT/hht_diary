# Phase 4.11 Worklog — Read-Side API Gaps (CUR-1154)

**Spec:** docs/superpowers/specs/2026-04-24-phase4.11-read-side-api-gaps-design.md
**Decisions log:** docs/superpowers/PHASE_4.10-4.13_DECISIONS_LOG.md (Phase 4.11 section)
**Branch:** mobile-event-sourcing-refactor

## Baseline (Task 1)

- event_sourcing_datastore: +566 passed
- provenance: +38 passed
- analyze (lib + example + provenance): clean
- Phase 4.10 HEAD confirmed at commit `6eb9bed1`

### `debugDatabase` / `intMapStoreFactory.store` BEFORE state

The Step 5 grep produced 9 hits (vs. the plan's anticipated 6). All 9 are
legitimate per the orchestrator's review; annotations distinguish intentional
sites (kept) from migration targets handled in later tasks.

```text
lib/src/storage/sembast_backend.dart:82                     intentional   internal _ingestedEventsStore field initializer (backend's own store-opening; not a reach-around)
lib/src/storage/sembast_backend.dart:89                     intentional   internal FIFO store factory (backend's own; not a reach-around)
lib/src/storage/sembast_backend.dart:105                    intentional   debugDatabase() definition site
lib/src/security/sembast_security_context_store.dart:23-24  intentional   intMapStoreFactory.store('events') field initializer for queryAudit (line-wrapped; counted as one logical hit)
lib/src/security/sembast_security_context_store.dart:28     to-migrate    security store read() calls debugDatabase (Task 7)
lib/src/security/sembast_security_context_store.dart:126    intentional   queryAudit() calls debugDatabase (kept per decisions log §4.11.3)
example/lib/widgets/detail_panel.dart:144-145               to-migrate    FIFO reach-around (Task 8)
example/lib/widgets/fifo_panel.dart:81-82                   to-migrate    FIFO reach-around (Task 8)
```

Migration targets after this phase: 3 sites (security store `read()`,
`detail_panel.dart` FIFO reach-around, `fifo_panel.dart` FIFO reach-around).
Intentional survivors after this phase: 6 sites (4 internal sembast-backend
store/factory references + `debugDatabase()` definition + `queryAudit`).

## Tasks

- [x] Task 1: Baseline + worklog
- [x] Task 2: Spec — REQ-d00147 + REQ-d00148 (two new sections)
- [x] Task 3: Failing test for findEventById (REQ-d00147)
- [x] Task 4: Implement findEventById on StorageBackend + SembastBackend
- [x] Task 5: Failing test for listFifoEntries (REQ-d00148)
- [x] Task 6: Implement listFifoEntries on StorageBackend + SembastBackend
- [x] Task 7: Migrate security store's `read()` off debugDatabase
- [x] Task 8: Migrate example panels (fifo_panel + detail_panel) onto new APIs; document debugDatabase narrowing
- [x] Task 9: Final verification + close worklog

## Final verification (Task 9)

### Test counts

```text
event_sourcing_datastore: 00:03 +573: All tests passed!
provenance:               00:00 +38: All tests passed!
```

Delta vs. baseline: event_sourcing_datastore +7 (566 baseline + 3 findEventById
[Task 3] + 4 listFifoEntries [Task 5]); provenance unchanged.

### Analyze (all three packages clean)

```text
event_sourcing_datastore: Analyzing event_sourcing_datastore... No issues found! (ran in 0.7s)
provenance:               Analyzing provenance...                No issues found! (ran in 0.2s)
example:                  Analyzing example...                   No issues found! (ran in 0.5s)
```

### `debugDatabase` / `intMapStoreFactory.store` AFTER state

```text
lib/src/security/sembast_security_context_store.dart:123:    final db = backend.debugDatabase();
lib/src/storage/sembast_backend.dart:82:      intMapStoreFactory.store(_ingestedEventsStoreName);
lib/src/storage/sembast_backend.dart:89:      intMapStoreFactory.store('fifo_$destinationId');
lib/src/storage/sembast_backend.dart:115:  Database debugDatabase() => _database();
```

Plus one logical hit not captured by `intMapStoreFactory.store` regex due to
line-wrapping: `lib/src/security/sembast_security_context_store.dart:23` —
`intMapStoreFactory` field initializer for queryAudit's events-store handle
(intentional, kept per §4.11.3).

Zero hits in `apps/common-dart/event_sourcing_datastore/example/lib/`. Example
is fully off both `debugDatabase` and the FIFO `intMapStoreFactory.store`
reach-around. The two surviving lib hits for `debugDatabase` (definition site +
`queryAudit` caller) are intentional per decisions log §4.11.3.
