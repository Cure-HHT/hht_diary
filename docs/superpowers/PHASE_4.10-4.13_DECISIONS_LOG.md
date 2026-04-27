# Phase 4.10 – 4.14 Decisions Log (CUR-1154)

Running record of judgment calls made during autonomous execution of Phases 4.10 through 4.13. Each entry: decision, alternatives considered, why this one, blast radius if wrong. Review at end of run; revert any you disagree with on the branch.

> Note on Phase 4.14 (added 2026-04-25): defined post-hoc by the user after reviewing the 4.10–4.13 run. See decisions §4.14.A–E. Plan: `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.14_arch_cleanup.md`.

---

## Phase 4.10 — wedge-aware fillBatch skip

Spec: `docs/superpowers/specs/2026-04-24-phase4.10-wedge-aware-fillbatch-design.md` (commit `872a8604`).

### Decisions made during brainstorm

| # | Decision | Alternative | Why |
| --- | --- | --- | --- |
| 4.10.1 | `fillBatch` keeps `Future<void>` return; wedge-skip is silent no-op | Typed `FillBatchOutcome` enum exposing wedgedSkipped | Existing 3 "did nothing" branches are all void; observability already lives in `readFifoHead` / `wedgedFifos` |
| 4.10.2 | Wedge-skip touches no state — no cursor advance, no event-log walk, no transform call | Maintain cursor past non-matches during wedge | Common-fast-rare-possible: wedged tick stays O(1); rehab recovery (rare) accepts one extra walk; tombstoneAndRefill recovery (dominant) rewinds cursor anyway |
| 4.10.3 | One new assertion REQ-d00128-I, no new REQ number | Claim REQ-d00147 for the change | Strictly extends the existing FIFO/cursor REQ; same topic |

### Decisions deferred / not made

- Diagnostic logging on each wedged tick — explicitly out of scope (would be N log lines per minute per wedged destination).
- FifoPanel UX of "events piling up behind wedge" disappearing — flagged in plan, not implemented in library.

### 4.10.4 — Pre-existing broken cross-references to REQ-d00132 (rehabilitate)

**Discovered** during Phase 4.10 Task 2 spec-compliance review. **NOT introduced by Phase 4.10. Not fixed by Phase 4.10. Surfaced here for user review.**

`spec/dev-event-sourcing-mobile.md` jumps from REQ-d00130 directly to REQ-d00133 — REQ-d00132 has no section. But the library code (in `apps/common-dart/event_sourcing_datastore/lib/src/storage/storage_backend.dart` and `sembast_backend.dart`) contains live `// Implements: REQ-d00132-A` and `// Implements: REQ-d00132-B` markers backing the `wedged → null` "rehabilitate" transition in `setFinalStatusTxn`, plus a `// -------- Rehabilitate helpers (REQ-d00132) --------` section header. These markers point at a REQ section that does not exist.

Two ways the user might want to reconcile this (NOT done in Phase 4.10 — both are out-of-scope expansions):

1. **Restore REQ-d00132** to `spec/dev-event-sourcing-mobile.md` if rehabilitate is intentionally still a supported recovery path. Probably 2 assertions (-A: `readFifoRow`; -B: `wedged → null` transition contract); fold the relevant prose from the lib-code dartdoc into a Rationale section. Cleanest if rehabilitate is staying.
2. **Remove the REQ-d00132 lib markers and the rehabilitate code paths** if rehabilitate was intentionally retired (e.g., during the Phase 4.7 strict-order drain fix, which removed `exhausted` status — the cleanup may have been incomplete on the lib side). Cleanest if rehabilitate is going.

Phase 4.10 took the conservative path: my original draft of REQ-d00128-I cited `rehabilitate (REQ-d00132)` and described its cursor-handling behavior. After spec-compliance review caught the broken reference, I removed every REQ-d00132 / rehabilitate mention from the new Phase 4.10 spec, design spec, and plan. Phase 4.10's only documented recovery path is `tombstoneAndRefill`. The `wedged → null` lib code is untouched.

**Recommended next action for the user**: when reviewing the branch, decide between options 1 and 2 above and open a separate ticket. This decision affects nothing in Phase 4.10 onwards; the wedge-skip optimization is correct under either interpretation (rehabilitate, if it stays, simply means the wedge-skip's early return ends sooner — `head.finalStatus` flips back to `null` after rehab, and the next `fillBatch` proceeds normally; no spec text needed for that since the early-return condition is exactly `finalStatus == wedged`).

**Closed:** 2026-04-24. Final verification: event_sourcing_datastore +566, provenance +38, all analyze clean.

---

## Phase 4.11 — read-side API gaps

Spec: `docs/superpowers/specs/2026-04-24-phase4.11-read-side-api-gaps-design.md`.

### Decisions made before plan-writing

| # | Decision | Alternative | Why |
| --- | --- | --- | --- |
| 4.11.1 | Adopt spec §3.3 Option A (typed surface for security store; document `debugDatabase` as test/example only) | Option B (rename only, leave reach-arounds) | Greenfield principle XP.1 — close the abstraction leak rather than papering over it |
| 4.11.2 | Migrate `SembastSecurityContextStore.read()` by wrapping `readInTxn` in a transaction; do NOT add a new `StorageBackend.findSecurityContextById` | Add a new typed StorageBackend method | The in-txn variant already exists; wrapping is a 1-line fix and avoids adding a method that's only used in one place |
| 4.11.3 | `SembastSecurityContextStore.queryAudit()` keeps using `debugDatabase()` in Phase 4.11 | Migrate it now via new typed StorageBackend audit-query API | queryAudit does a complex cross-store join + sort + paginate — the right shape needs its own design pass. Phase 4.11's mandate is "narrow API additions"; designing a query-audit API would blow up the PR. Surfaced for review under §4.11.4 below. |
| 4.11.4 | Migrate `example/lib/widgets/detail_panel.dart`'s FIFO reach-around (line 144–145) onto `listFifoEntries` in Phase 4.11 too | Defer to a later phase | Spec missed this case but it's the EXACT same pattern as fifo_panel.dart. Migrating it costs almost nothing and gets the example fully off `debugDatabase` for FIFO concerns |
| 4.11.5 | REQ-d00147 (findEventById) + REQ-d00148 (listFifoEntries). Confirm ceiling at Task 2 via the spec | Re-derive from `discover_requirements` MCP | Spec's calculation of ceiling = REQ-d00146 (post-4.9 + 4.10) is verifiable by grep; if the live spec disagrees, Task 2 picks the next two available numbers and updates references |
| 4.11.6 | `findEventById` test asserts FUNCTIONAL CORRECTNESS only (lookup hit / miss / wrong-id-returns-null) | Add an "indexed lookup complexity" test | Spec Risk 1 acknowledges no clean test exists for sembast index presence. The REQ rationale and code comment document the indexed-lookup intent; production complexity is verifiable via sembast database inspection if a regression is suspected. Not worth a flaky test. |

### 4.11.7 — `findEventById` queries both origin (`_eventStore`) and ingest (`_ingestedEventsStore`) stores

**Discovered** during Task 4 implementation. Phase 4.9 added a second sembast store (`_ingestedEventsStore`) keyed by `ingest_sequence_number`, separate from the origin `_eventStore` keyed by `sequence_number`. `findEventByIdInTxn` (Phase 4.9) only queries `_ingestedEventsStore` because its sole caller (ingest's idempotency check) is checking whether the receiver-side store has the event. But `findEventById`'s callers (UI, hash-chain walkers) want "any event with this id, regardless of which store holds it."

Implementation queries `_eventStore` first, falls back to `_ingestedEventsStore` if absent. Mirrors the pre-existing dual-store pattern of `findEventsForAggregate`. Confirmed test-correct: origin-side appended events show up; ingested events would too via the fallback (no test currently exercises the ingest path through this method, but the fallback is symmetric).

**Why origin-first**: on a mobile diary device, the vast majority of events are origin (locally appended via `EntryService.record`). Origin-first is the common-fast path; ingest fallback covers the rare case (mobile rarely ingests; portal would query both heavily once it lands).

**If wrong**: this decision is local to one method. A future caller that needs ingest-only or origin-only semantics would add a typed variant (`findOriginEventById` / `findIngestedEventById`) rather than mutating `findEventById`'s contract. No spec change needed; REQ-d00147-A says "the event whose `event_id` equals `eventId`" without qualifying which store, which is the right level of abstraction.

### Decisions deferred / not made

- **queryAudit migration** (decision 4.11.3 above): user should decide separately whether to (a) add a typed audit-query API to StorageBackend, (b) extract queryAudit into a separate audit module that owns its sembast access, or (c) make `debugDatabase`'s existence intentional for intra-library code via a renamed `_internalDatabase()` accessor with `@internal` annotation.
- Reactive / streaming APIs — carved into Phase 4.12 (per spec §2).
- Shared-cache primitive — carved into Phase 4.12 (per spec §2).
- `event_stream_panel.dart` migration off polling — not in 4.11; falls under 4.12's reactive layer.

**Closed:** 2026-04-25. Final verification: event_sourcing_datastore +573, provenance +38, all analyze clean. Two intentional debugDatabase references remain (definition + queryAudit) per §4.11.3.

---

## Phase 4.12 — reactive read layer + coordination primitive

Spec stub: `docs/superpowers/specs/2026-04-24-phase4.12-reactive-read-layer-stub.md` (5 open decisions, blocking execution).
Full design (this run): `docs/superpowers/specs/2026-04-25-phase4.12-reactive-read-layer-design.md`.

### Decisions made (conservative defaults across all 5 open questions)

| # | Decision | Alternative(s) | Why |
| --- | --- | --- | --- |
| 4.12.A | Concurrency contract: Dart `Stream` (broadcast). | `ValueListenable` / `ChangeNotifier` / `StateFlow`-shaped CurrentValueSubject | Pure-Dart; broadest reach; doesn't drag Flutter into the lib (Flutter-agnostic by design). Broadcast supports N consumers per source without per-subscriber state in the lib. |
| 4.12.B | Change detection: library-owned broadcast over write paths. | sembast `onSnapshots` (couples lib reactive contract to sembast); polled diff (worst of both worlds). | Keeps StorageBackend backend-agnostic; future Postgres backend implements the same contract by emitting on its write paths. The "outside writes" risk is small — the library is the only sanctioned writer of its own stores; raw test-only writes bypass and that's fine. |
| 4.12.C | Replay semantics: caller passes `afterSequence` for `watchEvents`; on subscribe emit replay from log, then transition to live. `watchFifo` emits current snapshot on subscribe, then each change. No state retention, no compaction handling. | Stateful "remember subscriber's cursor" or "broadcast holds last N events" patterns. | Caller already knows the cursor it wants; tail-`-F` semantics is well-understood. Slow consumers may miss events between pause/resume; they recover by re-subscribing with the last-seen sequence. No new state on the lib side. |
| 4.12.D | Scope: `watchEvents` + `watchFifo`. NOT `watchEntry` (per-aggregate materialized view). | All three from the stub's sketch. | watchEvents covers `detail_panel.dart` + `event_stream_panel.dart`; watchFifo covers `fifo_panel.dart`. watchEntry has no current example consumer (no panel reads a single DiaryEntry by aggregate id). Defer to mobile cutover (CUR-1169) when there's a real call site. |
| 4.12.E | No new "DataStore" coordination primitive; consumers share a single `SembastBackend` instance. | New `DataStore` handle that coordinates reads across consumers. | Broadcast streams already deduplicate work across N subscribers per source. The shared `SembastBackend` instance IS the coordination point. Document this in the new APIs' dartdoc. |

### Decisions deferred / not made

- **`watchEntry(aggregateId)` for per-aggregate materialized view reads** — defer to mobile cutover (CUR-1169) when the post-cutover diary read screens become a concrete consumer.
- **Compaction / log truncation semantics** — not on the roadmap; assertion text says nothing about it. If compaction lands later, watch-stream contract gets a new assertion then.
- **Cross-device subscription** (a remote server pushing changes to a mobile client) — orthogonal to library-local reactive reads; out of scope.
- **Stream-level error model** (do storage errors propagate down the stream as `addError`, or do they tear down the stream?) — picked: `addError` for non-fatal storage errors observed during a snapshot fetch; the stream stays open. Fatal errors (backend closed) cause `close()`. Logged here for visibility; assertion text in REQ codifies it.
- **Test framework reactive utilities** — using `package:flutter_test`'s `emitsInOrder` / `emitsThrough` / `expectLater(stream, ...)` matchers; no new test utility. Already in the toolchain.

### 4.12.H — `enqueueFifo` / `appendAttempt` / `markFinal` rerouted through wrapper `transaction()`

**Discovered** during Task 7 implementation. Three FIFO mutators were calling `_database().transaction(...)` directly instead of the wrapper `transaction<T>(body)` method. The wrapper is what drains `_pendingPostCommit`; bypassing it meant the FIFO emission callbacks landed on the inner pending-list but were never fired (because the wrapper was never invoked). Net effect: silent drop of `_fifoChangesController` notifications for any caller using these three methods directly (which is most production callers).

Fix: reroute all three through `transaction((txn) => …Txn(txn, …))`. The Txn variants (`enqueueFifoTxn`, `appendAttempt` already had no Txn variant — added the indirection inline by wrapping in a `transaction((txn) => _appendAttemptTxn(txn, …))` style) carry the post-commit `add()` calls; the wrapper drains them on commit success.

This is a load-bearing correctness fix — without it, `watchFifo` would have looked correct in tests that drive `enqueueFifoTxn` directly but would have silently failed for production callers driving `enqueueFifo`/`appendAttempt`/`markFinal`.

Surfaced for user visibility because this changes the `transaction()` invocation count: every call to those three methods now goes through one extra layer of wrapper. Performance impact is negligible (sembast transaction overhead dominates), but worth knowing.

### 4.12.G — Per-call broadcast controllers in `watchEvents` / `watchFifo`

**Discovered** during Task 5 implementation. The plan's sketch used a unicast `StreamController()` per `watchEvents()` call. REQ-d00149-C says the returned stream MUST be broadcast — multiple subscribers attached to the SAME returned stream receive identical sequences. A unicast controller crashes with "Stream has already been listened to" on the second `.listen()`.

Implementation uses `StreamController<StoredEvent>.broadcast()` per call. The backend-level `_eventsController` remains the underlying broadcast source; per-call controllers attach to it during `onListen` (with a `started` flag because broadcast `onListen` fires per attach) and tear down when the LAST subscriber cancels (broadcast `onCancel` fires after final detach). Same pattern applies to `watchFifo` (Task 7).

This matches the spec — REQ-d00149-C already mandated broadcast semantics; the plan's unicast hint was wrong, not the spec.

### 4.12.F — Phase invariant 4 ("zero Timer.periodic in example/lib") narrowed to the three migrating panels

**Discovered** during Task 1 baseline. The plan's invariant 4 said "zero hits"; actual baseline is 7 hits across 4 files plus 2 comments:

- `detail_panel.dart` — to migrate (Task 8). Removed.
- `event_stream_panel.dart` — to migrate (Task 8). Removed.
- `fifo_panel.dart` — to migrate (Task 8). Removed.
- `materialized_panel.dart:31` — polls the materialized view (per-aggregate read pattern). Not in scope: needs `watchEntry` / `watchView`, both deferred per §4.12.D. Stays as `Timer.periodic`.
- `main.dart:102` — periodic `syncCycle` drain trigger. NOT a UI polling loop; this is the demo's intentional drain scheduler analogous to a real app's background-sync ticker. Stays.
- `main.dart:94` and `demo_sync_policy.dart:20` — comments referencing Timer.periodic, not actual code. Cosmetic.

**Adjusted invariant 4**: zero `Timer.periodic` in `detail_panel.dart`, `event_stream_panel.dart`, `fifo_panel.dart`. The four other hits stay. `materialized_panel.dart` migration is deferred to mobile cutover (CUR-1169) along with `watchEntry`.

(Per-task discoveries — additional decisions made during execution — will be appended below as numbered subsections.)

**Closed:** 2026-04-25. Final verification: event_sourcing_datastore +582, provenance +38, all analyze clean. Three example panels migrated off Timer.periodic; materialized_panel + main.dart drain ticker remain per §4.12.F.

---

## Phase 4.13 — outgoing native-format wire_payload optimization

Spec stub: `docs/superpowers/specs/2026-04-24-phase4.13-outgoing-native-wire-payload-stub.md`.
Full design (this run): `docs/superpowers/specs/2026-04-25-phase4.13-outgoing-native-wire-payload-design.md`.

### Decisions made before plan-writing

| # | Decision | Alternative(s) | Why |
| --- | --- | --- | --- |
| 4.13.A | Storage-side optimization, transparent to `Destination` API. `enqueueFifoTxn` detects `wire_format == "esd/batch@1"`, parses the bytes via `BatchEnvelope.decode`, persists envelope metadata + drops the bytes. Drain re-encodes via `findEventById` + `BatchEnvelope.encode`. | (Y) Add `Destination.isNative` getter + library-managed serialization path; (Z) Add `envelopeMetadata` field to `WirePayload` and expect destinations to populate it. | Zero destination API changes; smallest possible blast radius. The destination's existing `transform()` returns canonical bytes with `contentType: 'esd/batch@1'`; the library opportunistically optimizes storage by parsing-and-stripping. 3rd-party destinations are completely untouched. |
| 4.13.B | Greenfield REQ-d00119-B rewrite in final-state voice. `wire_payload` is conditionally null based on `wire_format`: NATIVE rows (`wire_format == "esd/batch@1"`) SHALL store null `wire_payload` + non-null `envelope_metadata`; non-native rows SHALL store non-null `wire_payload` + null `envelope_metadata`. | "MAY be null" wording (less prescriptive). | Per principle XP.1: greenfield, no transition tolerance. Final-state spec says exactly what the system holds. |
| 4.13.C | Add new `envelope_metadata` field to `FifoEntry` (and a new `BatchEnvelopeMetadata` value type carrying `batch_id`, `sender_hop`, `sender_identifier`, `sender_software_version`, `sent_at` — everything from `BatchEnvelope` except the events). | Reuse `BatchEnvelope` directly (would force the storage layer to carry events around redundantly); inline into FifoEntry as separate columns (more sembast schema spread). | A typed value object is the cleanest hand-off across enqueue / drain / panels. The events list is recovered at drain time from `event_ids`, never stored alongside envelope metadata. |
| 4.13.D | Retry determinism via deterministic re-encoding. JCS canonicalization (RFC 8785) is byte-deterministic; events are immutable (REQ-p00004); envelope metadata is stored at enqueue and reused verbatim across retries. Same input → same bytes on every drain attempt. | Cache the bytes in-memory per row across retries (defeats the point); store the bytes too (defeats the storage saving). | Determinism is a property of the inputs + encoder; we already have all three locked. |
| 4.13.E | Extend REQ-d00119 with one new assertion (REQ-d00119-K) covering envelope metadata; rewrite REQ-d00119-B in place. NO new REQ number claimed. Stub said "extension of REQ-d00119; possibly an assertion added" — confirmed: extend in place. | Claim REQ-d00151 for the optimization. | The change is strictly inside the FIFO row shape contract that REQ-d00119 owns. Same topic; same REQ. |
| 4.13.F | Drain branches at the call site of `destination.send`. Reads envelope_metadata; if non-null, looks up events via `findEventById`, encodes with `BatchEnvelope`, sends the bytes. If null, sends `wire_payload` as-is. No destination API change. | Pre-encode in fillBatch (defeats storage saving); add a "lazy WirePayload" abstraction (over-engineered for one branch). | Drain is the natural place — only it needs the bytes. fillBatch's job is enqueue + ship the row to storage; that's done. |

### Decisions deferred / not made

- **Portal-side outbound FIFOs** (portal-to-EDC relay) — out of scope per stub §4. Mobile-only optimization; portal does its own thing later.
- **Compression of native payloads** — orthogonal optimization (storage AND wire); not in 4.13.
- **Migration of pre-existing FIFO rows** — greenfield, no rows in the wild. New rows follow the new shape; tests verify both code paths but no migration step.
- **Dynamic wire-format negotiation** with destinations — destination declares format at registration time via its transform's contentType output; no negotiation needed.
- **`BatchEnvelope.encode`'s `events` field shape** — stored as `List<Map<String, Object?>>` per Phase 4.9. The serialize-on-demand path needs `StoredEvent.toMap()` (or equivalent) to build `events` from looked-up StoredEvents. Verified during plan-writing that this method exists.

### 4.13.G — `FifoEntry.wirePayload` is `Map<String, Object?>`, not a typed `WirePayload`

**Discovered** during Task 4 implementation. The plan and design assumed `FifoEntry.wirePayload` was the typed `WirePayload` value object. The actual schema stores it as a `Map<String, Object?>` (with keys `bytes`/`contentType`/`transformVersion` inside). The plan's sample test code that called `WirePayload(bytes: …)` would not have compiled.

Implementer correctly adjusted: `wirePayload` becomes `Map<String, Object?>?` (nullable), enqueueFifoTxn maps the WirePayload argument to a Map at storage time (existing pattern), and the new envelope_metadata field is stored as a sub-map via `BatchEnvelopeMetadata.toMap()` / `fromMap()`.

Knock-on for Task 6 (drain): drain currently does `jsonEncode(head.wirePayload)` — a Map → JSON string → bytes. Native rows will branch BEFORE this jsonEncode: when `envelope_metadata` is non-null, drain reconstructs bytes via `findEventById` + `BatchEnvelope.encode`, NOT via jsonEncode of any Map. Task 6 implementer needs to construct the appropriate `WirePayload` (the typed value object) for the `destination.send(...)` call from the reconstructed bytes — the destination's `send` signature takes a `WirePayload`, not a Map.

(Per-task discoveries appended below as numbered subsections.)

**Closed:** 2026-04-25. Final verification: event_sourcing_datastore +594, provenance +38, all analyze clean. Native FIFO rows store envelope_metadata + null wire_payload; drain reconstructs deterministically.

---

## Phase 4.14 — architectural cleanup + unified event store + audit-query API + greenfield Destination API

Defined post-hoc by user review of the 4.10–4.13 run. Bundles four logically-distinct cleanups that share a common theme: **fix the design now, not later**, while still in greenfield. Plan: `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.14_arch_cleanup.md`.

### Decisions made

| # | Decision | Source | Why |
| --- | --- | --- | --- |
| 4.14.A | Remove rehabilitate code paths and all REQ-d00132 markers from lib + tests. Keep only `tombstoneAndRefill` as the wedge-recovery primitive. | User feedback 2026-04-25 on §4.10.4 | "No need to keep these. Remove the REQ-d00132 lib markers and the rehabilitate code." Phase 4.7 retired `exhausted`; rehabilitate is the orphan. |
| 4.14.B | Unify `_eventStore` and `_ingestedEventsStore` into ONE table. Ingested events get a local `sequence_number` from the standard counter; the originator's `sequence_number` is preserved on the receiver's `ProvenanceEntry` as a new `origin_sequence_number` field for chain reconstruction. Drop `nextIngestSequenceNumber`, `readIngestTail`, `_ingestedEventsStore`. Chain 2 ordering uses local `sequence_number`. | User feedback 2026-04-25 on §4.11.7 | "We should only have one table, not 3. Ingested events should look just like a local event, but with additional metadata. They can have their sequence_number replaced by the proper local one: the old sequence_number should be put into the metadata for the hop, for reconstructing the hash chain or original event when needed." Disposable materialized views (DiaryEntry, security_context, etc.) stay separate — those are by-definition rebuild-able from the unified event store. |
| 4.14.C | Greenfield Destination API for native: add `Destination.serializesNatively: bool` (or equivalent) declaring whether the destination speaks `esd/batch@1`. When true, library produces envelope metadata directly in fillBatch and skips `Destination.transform`. enqueueFifoTxn no longer parses bytes; storage just persists what the library handed it. Drain still re-encodes for the native path; lossy 3rd-party path unchanged. | User feedback 2026-04-25 on §4.13.A | "Greenfield. Do the right thing for this greenfield situation." Original 4.13.A optimization was clever-but-indirect (parse-and-strip the bytes the destination produced). Greenfield means we change the contract: destinations declare native or lossy; library handles native serialization. |
| 4.14.D | Add typed `StorageBackend.queryAudit({...filters, cursor, limit}) → Future<PagedAudit>` that owns the cross-store join (security_context + events). `SembastSecurityContextStore.queryAudit` becomes a thin delegator. `debugDatabase()` is REMOVED entirely (zero remaining callers in lib or example after 4.14). | User feedback 2026-04-25 on §4.11.3 | "Let's plan the proper solution now for phase 4.14." queryAudit was the last `debugDatabase()` survivor; with it migrated, the abstraction leak is fully closed. |
| 4.14.E | Doc fix: REQ-d00149-E and REQ-d00150-E "consumers SHALL share a single SembastBackend instance" wording is amended to "consumers SHALL share a single backend instance per database — the broadcast deduplication is the coordination mechanism, applicable to any `StorageBackend` implementation, not specific to sembast." | User feedback 2026-04-25 on §4.12.E | "Not specific to Sembast, I imagine. True for any backend." Correct — the sharing rule is about broadcast-stream coordination, not about sembast in particular. |
| 4.14.F | The "wrapping `read()` in a transaction" pattern from §4.11.2 is the correct implementation, but the rationale framing ("preserving the public contract during migration") is greenfield-incompatible. No code change; just don't repeat the framing. | User feedback 2026-04-25 on §4.11.2 | "Greenfield, no need for migrate. Wrapping *might* be the correct answer, but not for the stated reasons." The wrapping is right because in-txn variant already exists and the overhead is one transaction; framing it as "migration" implied a back-compat concern that doesn't exist. |
| 4.14.G | Portal-side outbound FIFO support stays out of scope. Library provides outbound native + lossy 3rd-party FIFOs; that's sufficient until portal consumers exist. | User feedback 2026-04-25 on deferred items | "Currently, supporting both outgoing native and transformed FIFOs is sufficient." Confirmed — no library-level addition needed for portal; portal's own ticket adds whatever it needs on top of the existing primitives. |

### REQ-number math (to be confirmed at task time)

Pre-Phase-4.14 ceiling: REQ-d00150. Phase 4.14 claims:

- **REQ-d00151** — `StorageBackend.queryAudit` typed audit-query API (Group D).
- **REQ-d00152** — `Destination.serializesNatively` declaration + library-managed native serialization contract (Group C).

Extensions (no new numbers):

- REQ-d00115 (ProvenanceEntry) — new field `origin_sequence_number` (Group B).
- REQ-d00145 (ingestBatch / ingestEvent contracts) — amended: ingested events get local sequence_number (Group B).
- REQ-d00146 (verification APIs) — amended: verifyIngestChain walks unified event store by local sequence_number (Group B).
- REQ-d00149-E + REQ-d00150-E — backend-agnostic wording (Group A).
- REQ-d00119-K (Phase 4.13) — rewritten in light of greenfield API (Group C).

Removals (no new numbers; remove from lib + tests):

- REQ-d00132 markers — entirely removed (Group A). Remains absent from spec, which is correct.

### Decisions deferred / not made (Phase 4.14)

- Sub-phasing: Phase 4.14 is large. The plan structures work in four task groups (A/B/C/D) with explicit checkpoints; if execution finds the bundle too big, the orchestrator can pause between groups.
- materialized_panel reactive read (`watchEntry`) — still deferred to mobile cutover (CUR-1169) per §4.12.D.
- Compaction / log truncation — still deferred (no consumer asking).

(Per-task discoveries appended below.)

**Closed:** 2026-04-25. Final verification: event_sourcing_datastore +595, provenance +45, all analyze clean. All four cleanup targets satisfied (zero rehabilitate / zero _ingestedEventsStore / zero debugDatabase / zero BatchEnvelope.decode-in-storage).

---

## Phase 4.15 — example app capability showcase

Plan: `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/PLAN_PHASE4.15_example_capability_showcase.md`.

### Decisions made during execution

| # | Decision | Source | Why |
| --- | --- | --- | --- |
| 4.15.A | Add a "set demo security context" toggle to top_action_bar.dart so the new AuditPanel renders non-empty rows. Folded into Task 5. | Task 4 surfaced empty-audit issue; orchestrator approved scope addition. | The AuditPanel is decorative without populated rows. Toggle is a 5-line change; making the panel actually demoable is in the spirit of "expose capabilities cleanly." |

**Closed:** 2026-04-25. Final verification: event_sourcing_datastore +595, provenance +45, all analyze clean. Three highlight capabilities exposed (native vs lossy FIFO, AuditPanel, origin_sequence_number) plus demo security-context toggle.

---

## Cross-phase / strategic decisions

### XP.1 — Greenfield: NO backward-compat anywhere

**Decision** (user-reinforced 2026-04-24): mobile and portal are both greenfield, never deployed. Backward compat is not just unnecessary — it's actively bad for maintainability. Each upcoming phase MUST be designed in final-state voice (no "keeps working with old code", "preserves prior behavior for callers using X", "deprecated but still supported"). When a Phase touches an existing API surface, the right move is often to REMOVE the old shape entirely once the new one is in place, not to keep both.

**Concrete implications per upcoming phase:**

- **Phase 4.11**: `debugDatabase()` audit can REMOVE the method or restrict it to a test-only escape hatch — no need to keep it for "any caller who might still want it." Non-test callers are migrated to typed `StorageBackend` methods in the same PR; `debugDatabase()` either disappears or is renamed to make its test-only nature obvious.
- **Phase 4.12**: if reactive APIs replace the polling pattern in the example app, the old `Timer.periodic` + `findAll…` pattern goes away in the same PR. We do not keep both as alternatives.
- **Phase 4.13**: when relaxing REQ-d00119-B's unconditional `wire_payload`, just rewrite the assertion in final-state voice ("`wire_payload` SHALL be present iff `wire_format` is a lossy 3rd-party format; native `esd/batch@1` rows SHALL omit `wire_payload`"). No transition assertions, no "legacy rows are tolerated" carve-outs.

**Spec voice rule** (per `feedback_final_state_spec_voice.md`): no "removed", "no longer", "does NOT require" phrasing in any spec or REQ. Write the rule the system follows in its final shape.

### XP.3 — When adding a NEW REQ section, include `| **Hash**: 00000000` placeholder

**Discovered** during Phase 4.11 Task 2. The elspais pre-commit hook's `update_hash_in_file` tool only POPULATES an existing hash placeholder; it does not APPEND one. A new REQ block written with bare `*End* *Title*` lines (no `| **Hash**:` suffix) commits without hashes, leaving INDEX.md columns empty.

**Convention for any future new REQ section** (Phase 4.13 may add one extending REQ-d00119): write the closing line as:

```markdown
*End* *Title* | **Hash**: 00000000
```

The hook replaces `00000000` with the real hash and updates INDEX.md, all in one commit. No fixup churn. Phase 4.10 (extending REQ-d00128's assertion list) did not hit this because the `*End*` already had a hash; only NEW REQ sections need the placeholder.

### XP.2 — Decision-pinning style

When making a judgment call inside a phase's design, log it here with: decision, alternatives, why this one. Subagents executing the work see this doc and treat the decisions as pinned — they don't re-litigate. User reviews at the end and reverts any they disagree with. This is the only checkpoint between brainstorm-skipped and merge-ready.
