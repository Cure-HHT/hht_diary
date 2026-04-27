# Master Plan Phase 4.4: Events lib extensions for portal use

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Branch**: `mobile-event-sourcing-refactor` (shared)
**Ticket**: CUR-1154 (parent); CUR-1159 (portal-side counterpart, Sub-project E)
**Phase**: 4.4 of 6
**Status**: Not Started
**Depends on**: Phase 4.3 squashed and phase-reviewed
**Design doc**: `docs/superpowers/specs/2026-04-22-events-lib-extensions-design.md`
**Source TODO**: `TODO4.4.md` (worktree root)

## Goal

Extend the events library with `Initiator`, `flowToken`, `EventSecurityContext`, multi-materializer support, and an `EventStore` rename — serving both the portal-server side (CUR-1159) and the mobile PIN-login flow, without touching `clinical_diary` (Phase 5's job) and without disturbing Phase 4.3 deliverables.

## Architecture

Events library grows a sidecar security-context store (independent FK into `event_log`), a sealed `Initiator` replacing `StoredEvent.userId`, a universal `flow_token` correlation column, and a pluggable `Materializer` abstraction with generic view storage on `StorageBackend`. `EntryService` is renamed to `EventStore` with a per-field append API that takes `Initiator` + optional `SecurityDetails`. `bootstrapAppendOnlyDatastore` returns a facade (`AppendOnlyDatastore`) with four members and auto-registers three reserved system entry types for security-context audit.

## Tech Stack

Dart 3 (sealed classes, pattern matching). Sembast for mobile-side impl. JCS / sha256 for hash chain. Test framework: `flutter_test` + `sembast_memory`.

## Scope boundaries

**In Phase 4.4:**
- `Initiator` sealed with three variants; `StoredEvent.userId` → `StoredEvent.initiator`.
- `flow_token` nullable on `StoredEvent`; sembast index added.
- `Source` (rename of `DeviceInfo`; drops `userId`).
- `EventStore` (rename of `EntryService`; new `append(...)` signature; gains `clearSecurityContext`, `applyRetentionPolicy`).
- `EventSecurityContext` sidecar + `SecurityContextStore` abstract + `SembastSecurityContextStore` concrete; `queryAudit`.
- `SecurityRetentionPolicy` + `SecurityDetails`.
- `Materializer` becomes abstract; `DiaryEntriesMaterializer` extracted; `EntryTypeDefinition.materialize` flag.
- `StorageBackend` drops diary-specific methods; adds generic view methods.
- `bootstrapAppendOnlyDatastore` → `AppendOnlyDatastore` facade; auto-registers 3 system entry types.
- 3 reserved system entry types (`security_context_redacted`, `security_context_compacted`, `security_context_purged`).
- Hash spec change: identity fields now `{event_id, aggregate_id, entry_type, event_type, sequence_number, data, initiator, flow_token, client_timestamp, previous_event_hash, metadata}`.
- `REQ-EVENTS-NO-SECRETS` documented invariant.
- Legacy `EventRepository.append` keeps its `userId: String` parameter; wraps internally into `UserInitiator(userId)` and stamps `metadata.provenance[0]` so records conform to the new `StoredEvent` shape.
- `StoredEvent.synthetic(...)` test-fixture factory.

**Deferred to Phase 4.5:** storage-failure taxonomy, FailureInjector, StorageException classifier, storage-failure audit log, MaterializedView recovery on corrupt read.

**Deferred to Phase 4.6:** demo app, worked multi-materializer example (button toggle).

**Out of scope entirely:** PostgreSQL `StorageBackend`, retention cron wiring, portal actions lib (CUR-1159 Sub-project A), diary-sync ingestion endpoint, OpenTelemetry stamping, encryption-at-rest.

`clinical_diary` / `NosebleedService` remain untouched; Phase 5 cuts them over.

## Execution rules

Read `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/README.md` in full before starting. TDD cadence, REQ citation format, phase-squash procedure, and cross-phase invariants apply.

Phase 4.4 lands as one squashed commit. Per-task commit cadence during development is fine — the squash happens on PR merge. Before each phase-squash prep verification, all tests MUST be green.

Per-task controller workflow lives in `PHASE_4.4_WORKLOG.md`. Each task:
1. Implement the task per the steps below.
2. Append a brief outline of the finished work to `PHASE_4.4_WORKLOG.md` (status, not history).
3. Commit the changes.
4. Launch a sub-agent to review the commit (tell it NOT to read `docs/`).
5. Decide which review comments to address; log both addressed and dismissed to WORKLOG.
6. Commit review fixes.

## Applicable REQ assertions

Numbers claimed at Task 3 via `discover_requirements("next available REQ-d")`. All land in `spec/dev-event-sourcing-mobile.md`.

| REQ topic | Scope | Assertions |
| --- | --- | --- |
| `REQ-INITIATOR` | sealed actor type, 3 variants, JSON roundtrip | A-F |
| `REQ-FLOWTOKEN` | nullable correlation; backend indexed | A-E |
| `REQ-SECCTX` | sidecar store; atomic write; one-way FK | A-F |
| `REQ-RETENTION` | policy value type; sweep API; audit events | A-G |
| `REQ-EVENTS-NO-SECRETS` | documented invariant | A-C |
| `REQ-MATERIALIZERS` | pluggable; def.materialize flag; generic views | A-F |
| `REQ-EVENTSTORE` | rename; single append(); permission-blind | A-D |
| `REQ-SOURCE` | rename of DeviceInfo; hopId/identifier/softwareVersion | A-C |
| Update `REQ-d00120-B` | drop user_id, device_id; add initiator, flow_token, metadata | (in-place edit) |
| Update `REQ-d00134` | return AppendOnlyDatastore facade; auto-register system types | (in-place edit) |

REQ citation placement: `// Implements: REQ-xxx-Y — <prose>` per-function; `// Verifies: REQ-xxx-Y — <prose>` per-test; the assertion ID starts the test description: `test('REQ-xxx-Y: description', () { ... })`.

---

## Plan

### Task 1: Baseline verification

**Files:** none (read-only)

- [ ] **Step 1: Confirm Phase 4.3 complete.** Run: `git log --oneline -10`. Expected: Phase 4.3 squashed commits present; the Phase 4.4 design commits at HEAD (`943c2c79`, `83f0ec98`, `72ff3378`, `b6855346`, `0fc88d5b`).

- [ ] **Step 2: Baseline tests green.** Run, each in its own shell invocation:
  - `(cd apps/common-dart/append_only_datastore && dart test)` — all pass
  - `(cd apps/common-dart/provenance && dart test)` — all pass
  - `(cd apps/common-dart/trial_data_types && dart test)` — all pass
  - `(cd apps/common-dart/append_only_datastore && dart analyze)` — no issues
  - `(cd apps/daily-diary/clinical_diary && flutter test)` — all pass
  - `(cd apps/daily-diary/clinical_diary && flutter analyze)` — no errors

- [ ] **Step 3: Record baseline in WORKLOG.** Note Phase 4.3 tip SHA and test counts.

- [ ] **Step 4: No commit** (verification only).

---

### Task 2: Parent plan README update

Thin annotation to the phase index; no code.

**Files:**
- Modify: `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/README.md`

- [ ] **Step 1: Read README.** Read the current "Phase sequence" table.

- [ ] **Step 2: Insert Phase 4.4 row** between 4.3 and 4.6 using the Edit tool. Add this row:

```markdown
| 4.4 | [PLAN_PHASE4.4_library.md](PLAN_PHASE4.4_library.md) | Events lib extensions for portal use: Initiator, flowToken, EventSecurityContext, multi-materializer, EventStore rename | Medium — large library phase |
```

- [ ] **Step 3: Commit.**

```bash
git add docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/README.md
git commit -m "[CUR-1154] Phase 4.4: add plan to phase index"
```

---

### Task 3: Spec additions — claim REQ-d numbers and write new REQ topics

**Files:**
- Modify: `spec/dev-event-sourcing-mobile.md`
- Modify: `spec/INDEX.md`

- [ ] **Step 1: Claim 8 new REQ-d numbers.** Run `discover_requirements("next available REQ-d")` eight times and record each returned number into the WORKLOG with its mapped topic:

  1. `REQ-INITIATOR` → REQ-d00XXX
  2. `REQ-FLOWTOKEN` → REQ-d00XXX
  3. `REQ-SECCTX` → REQ-d00XXX
  4. `REQ-RETENTION` → REQ-d00XXX
  5. `REQ-EVENTS-NO-SECRETS` → REQ-d00XXX
  6. `REQ-MATERIALIZERS` → REQ-d00XXX
  7. `REQ-EVENTSTORE` → REQ-d00XXX
  8. `REQ-SOURCE` → REQ-d00XXX

- [ ] **Step 2: Write the eight new REQ topics** into `spec/dev-event-sourcing-mobile.md`, each appended after the Phase 4.3 REQs, using the existing REQ template format (title, Level, Status, Implements, Rationale, Assertions, trailing hash line). Include each assertion as listed below (use the design doc §8 text verbatim for assertions, expanding the lettered shorthand into full SHALL statements).

  **REQ-INITIATOR** — assertions A-F (§4.1, §5, §7 of design doc):
  - A: `Initiator` SHALL be a Dart 3 sealed class with exactly three variants: `UserInitiator`, `AutomationInitiator`, `AnonymousInitiator`.
  - B: Each variant SHALL round-trip through a JSON map carrying a `type` discriminator (`"user"`, `"automation"`, `"anonymous"`) and the variant's field(s); the encoding SHALL be exact per design-doc §4.1.
  - C: Every mobile call site that previously supplied `userId: String` SHALL be migrated to supply `initiator: UserInitiator(userId)`.
  - D: `AutomationInitiator.triggeringEventId` SHALL be nullable; when non-null it SHALL reference an existing event's `event_id`.
  - E: `AnonymousInitiator.ipAddress` SHALL be nullable; `null` is the pre-auth value used by the PIN-login screen.
  - F: `Initiator.fromJson` SHALL throw `FormatException` on unknown `type` discriminator or a missing required field per variant.

  **REQ-FLOWTOKEN** — assertions A-E:
  - A: `StoredEvent.flowToken` SHALL be a nullable `String?` column.
  - B: The format convention `'<aggregate-or-flow-name>:<id>'` SHALL be documented in the lib README and this REQ; the lib SHALL NOT enforce format at runtime.
  - C: Callers that participate in a multi-event flow SHALL stamp the same `flowToken` on every event of the flow.
  - D: `SembastBackend` SHALL maintain an index on `flow_token` in the events store so `WHERE flow_token = ?` queries do not scan the full log.
  - E: `flow_token` SHALL be part of the `event_hash` inputs.

  **REQ-SECCTX** — assertions A-F:
  - A: `EventSecurityContext` SHALL be a separate sembast store (`security_context`), not columns on `event_log`.
  - B: The FK direction SHALL be `security_context.event_id → event_log.event_id`; the event row SHALL NOT reference security.
  - C: `EventStore.append` writes the event row AND (when `security != null`) the security row in one backend transaction; any throw rolls back both.
  - D: `SecurityContextStore.read(eventId)` SHALL return the row or `null`; missing row is not an error.
  - E: Security rows SHALL only be written by `EventStore.append` (store-internal mutation API is package-private).
  - F: `SecurityContextStore.queryAudit({initiator?, flowToken?, ipAddress?, from?, to?, limit, cursor?})` SHALL return a `PagedAudit` of `AuditRow(event, context)`; `limit` SHALL be in `[1, 1000]`; cursor SHALL be opaque; corrupt cursor SHALL throw `ArgumentError`.

  **REQ-RETENTION** — assertions A-G:
  - A: `SecurityRetentionPolicy` SHALL be an immutable value type with `fullRetention` (default 90 days), `truncatedRetention` (default 365 days), IPv4 last-octet truncation (default true), IPv6 /48 truncation (default true), user-agent drop after full (default true), geo drop after full (default false), drop-all after truncated (default true); `SecurityRetentionPolicy.defaults` SHALL be a `static const`.
  - B: `EventStore.applyRetentionPolicy(policy: ?, sweepInitiator: ?)` SHALL truncate rows past `fullRetention` per policy flags.
  - C: `applyRetentionPolicy` SHALL delete rows past `fullRetention + truncatedRetention`.
  - D: `EventStore.clearSecurityContext(eventId, reason, redactedBy)` SHALL delete the security row AND append exactly one `security_context_redacted` event (`aggregateType='security_context'`, `aggregateId=eventId`, `eventType='finalized'`, `data={'reason': ...}`, `initiator=redactedBy`) in the same transaction.
  - E: Non-empty compact sweep SHALL emit exactly one `security_context_compacted` event; empty sweep SHALL emit none.
  - F: Non-empty purge sweep SHALL emit exactly one `security_context_purged` event; empty sweep SHALL emit none.
  - G: Redaction/compact/purge events SHALL themselves be immutable event_log rows (not security rows), so the action-of-redaction is permanently auditable.

  **REQ-EVENTS-NO-SECRETS** — assertions A-C:
  - A: Event `data` and `flowToken` SHALL NOT contain unhashed credentials, OTPs, recovery tokens, session tokens, or any other value whose mere knowledge confers authority.
  - B: Rationale: read-only access to `event_log` is broad (SIEM, backups, replicas, human auditors), so defense-in-depth requires keeping secrets out even when full-DB compromise would dominate the immediate threat.
  - C: Hashes (sha256 or stronger, with sufficient input entropy) MAY appear in `data` when needed for later verification correlation; the library SHALL NOT enforce this at runtime — callers own the contract.

  **REQ-MATERIALIZERS** — assertions A-F:
  - A: `Materializer` SHALL be abstract with `String get viewName`, `bool appliesTo(StoredEvent event)`, `Future<void> applyInTxn(Txn, StorageBackend, {event, def, aggregateHistory})`.
  - B: `EventStore` SHALL accept `List<Materializer> materializers` at construction and fire each matching materializer for each appended event.
  - C: When an event's `EntryTypeDefinition.materialize == false`, NO materializer SHALL be invoked for that event regardless of `appliesTo`.
  - D: `rebuildView(materializer, backend)` SHALL replay the event log into exactly one view; the function SHALL be idempotent (re-running produces the same view rows).
  - E: A throw from any materializer's `applyInTxn` SHALL roll back the entire append transaction — no event row, no security row, no other view rows.
  - F: `StorageBackend` SHALL expose generic view methods `readViewRowInTxn(txn, viewName, key)`, `upsertViewRowInTxn(txn, viewName, key, row)`, `deleteViewRowInTxn(txn, viewName, key)`, `findViewRows(viewName, {limit, offset})`, `clearViewInTxn(txn, viewName)`.

  **REQ-EVENTSTORE** — assertions A-D:
  - A: The class named `EntryService` SHALL be renamed to `EventStore` and SHALL live in `lib/src/event_store.dart`.
  - B: `EventStore.append({entryType, aggregateId, aggregateType, eventType, data, initiator, flowToken?, metadata?, security?, checkpointReason?, changeReason?, dedupeByContent=false})` SHALL be the single public write method serving both mobile widgets and portal callers.
  - C: Mobile widget call sites SHALL pass per-field arguments directly; there SHALL NOT be an intermediate `EventDraft` value type on the mobile write path.
  - D: Neither `EventStore` nor `SecurityContextStore` SHALL gate by user role, scope, or tenancy — access control lives in the widget / handler layer (permission-blind invariant).

  **REQ-SOURCE** — assertions A-C:
  - A: The class named `DeviceInfo` SHALL be renamed to `Source` and SHALL carry exactly three fields: `hopId: String`, `identifier: String`, `softwareVersion: String`; `Source` SHALL NOT carry `userId`.
  - B: `hopId` SHALL enumerate at least `'mobile-device'` and `'portal-server'` as well-known values; others are permitted.
  - C: `softwareVersion` SHALL conform to REQ-d00115-E (`"<package-name>@<semver>[+<build>]"`); `Source` SHALL NOT validate at runtime.

- [ ] **Step 3: Update REQ-d00120-B (in-place).** Edit the "Assertions" block of REQ-d00120 in `spec/dev-event-sourcing-mobile.md` so assertion B enumerates the new identity-field set: `{event_id, aggregate_id, entry_type, event_type, sequence_number, data, initiator, flow_token, client_timestamp, previous_event_hash, metadata}`. Drop `user_id` and `device_id` from the list; add `initiator`, `flow_token`, `metadata`. Recompute the REQ hash line per the spec-compliance template.

- [ ] **Step 4: Update REQ-d00134 (in-place).** Edit the REQ-d00134 entry to reflect the new bootstrap signature: returns `AppendOnlyDatastore` (not the 2-tuple); auto-registers three reserved system entry types before the caller-supplied list; caller-supplied id colliding with a reserved id throws `ArgumentError`. Recompute hash.

- [ ] **Step 5: Update `spec/INDEX.md`** to list the 8 new REQ topics. Follow existing entry format.

- [ ] **Step 6: Run spec-compliance validation.**

```bash
cd tools/requirements && python -m requirements.validate_all
```

Expected: no errors.

- [ ] **Step 7: Commit.**

```bash
git add spec/dev-event-sourcing-mobile.md spec/INDEX.md
git commit -m "[CUR-1154] Phase 4.4: claim 8 REQ topics; update REQ-d00120-B and REQ-d00134"
```

---

### Task 4: `Initiator` sealed class

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/storage/initiator.dart`
- Create: `apps/common-dart/append_only_datastore/test/storage/initiator_test.dart`

- [ ] **Step 1: Write the failing tests first.** Create `test/storage/initiator_test.dart`:

```dart
import 'package:append_only_datastore/src/storage/initiator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Initiator', () {
    test('REQ-INITIATOR-A: sealed pattern-match is exhaustive over three '
        'variants', () {
      String describe(Initiator i) => switch (i) {
        UserInitiator() => 'user',
        AutomationInitiator() => 'automation',
        AnonymousInitiator() => 'anonymous',
      };
      expect(describe(const UserInitiator('u')), 'user');
      expect(describe(const AutomationInitiator(service: 's')), 'automation');
      expect(describe(const AnonymousInitiator(ipAddress: null)), 'anonymous');
    });

    test('REQ-INITIATOR-B: UserInitiator JSON round-trips with type '
        'discriminator', () {
      const u = UserInitiator('user-123');
      expect(u.toJson(), {'type': 'user', 'user_id': 'user-123'});
      expect(Initiator.fromJson(u.toJson()), u);
    });

    test('REQ-INITIATOR-B: AutomationInitiator JSON round-trips with both '
        'required and optional fields', () {
      const a1 = AutomationInitiator(service: 'mobile-bg-sync');
      expect(a1.toJson(), {
        'type': 'automation',
        'service': 'mobile-bg-sync',
        'triggering_event_id': null,
      });
      expect(Initiator.fromJson(a1.toJson()), a1);

      const a2 = AutomationInitiator(
        service: 'email-service',
        triggeringEventId: 'evt-9',
      );
      expect(a2.toJson(), {
        'type': 'automation',
        'service': 'email-service',
        'triggering_event_id': 'evt-9',
      });
      expect(Initiator.fromJson(a2.toJson()), a2);
    });

    test('REQ-INITIATOR-E: AnonymousInitiator accepts null ipAddress', () {
      const a = AnonymousInitiator(ipAddress: null);
      expect(a.toJson(), {'type': 'anonymous', 'ip_address': null});
      expect(Initiator.fromJson(a.toJson()), a);
    });

    test('REQ-INITIATOR-B: AnonymousInitiator with ip round-trips', () {
      const a = AnonymousInitiator(ipAddress: '203.0.113.7');
      expect(a.toJson(), {'type': 'anonymous', 'ip_address': '203.0.113.7'});
      expect(Initiator.fromJson(a.toJson()), a);
    });

    test('REQ-INITIATOR-F: fromJson rejects unknown type with FormatException',
        () {
      expect(
        () => Initiator.fromJson({'type': 'bogus'}),
        throwsFormatException,
      );
    });

    test('REQ-INITIATOR-F: fromJson rejects missing user_id on user variant',
        () {
      expect(
        () => Initiator.fromJson({'type': 'user'}),
        throwsFormatException,
      );
    });

    test('REQ-INITIATOR-F: fromJson rejects missing service on automation '
        'variant', () {
      expect(
        () => Initiator.fromJson({'type': 'automation'}),
        throwsFormatException,
      );
    });

    test('equality and hashCode: equal variants compare equal', () {
      expect(const UserInitiator('x'), const UserInitiator('x'));
      expect(const UserInitiator('x').hashCode,
          const UserInitiator('x').hashCode);
      expect(const AutomationInitiator(service: 's'),
          const AutomationInitiator(service: 's'));
      expect(const AnonymousInitiator(ipAddress: null),
          const AnonymousInitiator(ipAddress: null));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure.** Run: `(cd apps/common-dart/append_only_datastore && dart test test/storage/initiator_test.dart)`. Expected: compilation errors (no `initiator.dart` yet).

- [ ] **Step 3: Implement `initiator.dart`.** Create:

```dart
/// Polymorphic actor identity stamped on every `StoredEvent`. Replaces the
/// flat `userId: String` field with a sealed hierarchy that names the kind
/// of actor — human user, automation service, or pre-auth anonymous flow —
/// so downstream audit and filtering can reason about causation without
/// guessing.
// Implements: REQ-INITIATOR-A — sealed Dart 3 class with three variants.
sealed class Initiator {
  const Initiator();

  Map<String, dynamic> toJson();

  // Implements: REQ-INITIATOR-B — JSON round-trip with type discriminator.
  // Implements: REQ-INITIATOR-F — rejects unknown type / missing required
  // fields with FormatException.
  static Initiator fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    switch (type) {
      case 'user':
        final userId = json['user_id'];
        if (userId is! String) {
          throw const FormatException(
            'Initiator(user): missing or non-string "user_id"',
          );
        }
        return UserInitiator(userId);
      case 'automation':
        final service = json['service'];
        if (service is! String) {
          throw const FormatException(
            'Initiator(automation): missing or non-string "service"',
          );
        }
        final triggering = json['triggering_event_id'];
        if (triggering != null && triggering is! String) {
          throw const FormatException(
            'Initiator(automation): "triggering_event_id" must be a String '
            'when present',
          );
        }
        return AutomationInitiator(
          service: service,
          triggeringEventId: triggering as String?,
        );
      case 'anonymous':
        final ip = json['ip_address'];
        if (ip != null && ip is! String) {
          throw const FormatException(
            'Initiator(anonymous): "ip_address" must be a String when present',
          );
        }
        return AnonymousInitiator(ipAddress: ip as String?);
      default:
        throw FormatException(
          'Initiator.fromJson: unknown discriminator "$type"; expected '
          'user | automation | anonymous',
        );
    }
  }
}

/// A human user acted; `userId` is the platform's user identifier.
class UserInitiator extends Initiator {
  const UserInitiator(this.userId);
  final String userId;

  @override
  Map<String, dynamic> toJson() => {'type': 'user', 'user_id': userId};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserInitiator && userId == other.userId);

  @override
  int get hashCode => Object.hash('user', userId);
}

/// An automated service acted. `triggeringEventId` is the upstream event
/// that caused this automation's action, or null for free-running triggers
/// (cron, lifecycle, observed external fact).
class AutomationInitiator extends Initiator {
  const AutomationInitiator({required this.service, this.triggeringEventId});
  final String service;
  final String? triggeringEventId;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'automation',
        'service': service,
        'triggering_event_id': triggeringEventId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AutomationInitiator &&
          service == other.service &&
          triggeringEventId == other.triggeringEventId);

  @override
  int get hashCode => Object.hash('automation', service, triggeringEventId);
}

/// A pre-auth anonymous actor (e.g., the PIN-login screen). `ipAddress` is
/// the best-known-by-actor IP at action time; `null` is valid on mobile
/// pre-auth flows.
class AnonymousInitiator extends Initiator {
  const AnonymousInitiator({required this.ipAddress});
  final String? ipAddress;

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'anonymous', 'ip_address': ipAddress};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnonymousInitiator && ipAddress == other.ipAddress);

  @override
  int get hashCode => Object.hash('anonymous', ipAddress);
}
```

- [ ] **Step 4: Re-run tests.** Run: `(cd apps/common-dart/append_only_datastore && dart test test/storage/initiator_test.dart)`. Expected: all pass.

- [ ] **Step 5: WORKLOG + commit + review (per controller workflow).**

```bash
git add apps/common-dart/append_only_datastore/lib/src/storage/initiator.dart \
        apps/common-dart/append_only_datastore/test/storage/initiator_test.dart
git commit -m "[CUR-1154] Phase 4.4 Task 4: Initiator sealed class"
```

Launch review sub-agent (per `PHASE_4.4_WORKLOG.md` workflow), log addressed/dismissed, commit fixes.

---

### Task 5: `Source` (rename from `DeviceInfo`)

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/storage/source.dart` (moves from `entry_service.dart`; drops `userId` field)
- Create: `apps/common-dart/append_only_datastore/test/storage/source_test.dart`

Deletion of `DeviceInfo` from `entry_service.dart` happens in Task 17 (EventStore rename). This task creates `Source` in its own file; once EventStore is renamed, `entry_service.dart` goes away entirely.

- [ ] **Step 1: Write the failing tests first.** Create `test/storage/source_test.dart`:

```dart
import 'package:append_only_datastore/src/storage/source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Source', () {
    test('REQ-SOURCE-A: construction carries three fields (no userId)', () {
      const s = Source(
        hopId: 'mobile-device',
        identifier: 'dev-1',
        softwareVersion: 'clinical_diary@1.2.3+4',
      );
      expect(s.hopId, 'mobile-device');
      expect(s.identifier, 'dev-1');
      expect(s.softwareVersion, 'clinical_diary@1.2.3+4');
    });

    test('equality and hashCode', () {
      const a = Source(hopId: 'h', identifier: 'i', softwareVersion: 'v');
      const b = Source(hopId: 'h', identifier: 'i', softwareVersion: 'v');
      const c = Source(hopId: 'x', identifier: 'i', softwareVersion: 'v');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('REQ-SOURCE-B: hopId accepts well-known values', () {
      const m = Source(
          hopId: 'mobile-device', identifier: 'd', softwareVersion: 'v');
      const p = Source(
          hopId: 'portal-server', identifier: 'h', softwareVersion: 'v');
      expect(m.hopId, 'mobile-device');
      expect(p.hopId, 'portal-server');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure.** Run: `(cd apps/common-dart/append_only_datastore && dart test test/storage/source_test.dart)`. Expected: file-not-found compilation error.

- [ ] **Step 3: Implement `source.dart`.** Create:

```dart
/// Constructor-time identity of the process writing events. Stamps
/// `metadata.provenance[0]` on every event written through `EventStore`.
///
/// Renamed from `DeviceInfo` (Phase 4.4) and narrowed: the old `userId`
/// field moved out to the per-append `Initiator` argument, so one `Source`
/// instance can serve many authenticated users.
// Implements: REQ-SOURCE-A — rename of DeviceInfo; carries three fields.
// Implements: REQ-SOURCE-B — hopId enumerates 'mobile-device' /
// 'portal-server' as well-known values.
// Implements: REQ-SOURCE-C — softwareVersion follows REQ-d00115-E format;
// no runtime validation at this type.
class Source {
  const Source({
    required this.hopId,
    required this.identifier,
    required this.softwareVersion,
  });

  final String hopId;
  final String identifier;
  final String softwareVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Source &&
          hopId == other.hopId &&
          identifier == other.identifier &&
          softwareVersion == other.softwareVersion);

  @override
  int get hashCode => Object.hash(hopId, identifier, softwareVersion);

  @override
  String toString() =>
      'Source(hopId: $hopId, identifier: $identifier, '
      'softwareVersion: $softwareVersion)';
}
```

- [ ] **Step 4: Re-run tests.** Expected: all pass.

- [ ] **Step 5: WORKLOG + commit + review.**

```bash
git add apps/common-dart/append_only_datastore/lib/src/storage/source.dart \
        apps/common-dart/append_only_datastore/test/storage/source_test.dart
git commit -m "[CUR-1154] Phase 4.4 Task 5: Source value type"
```

---

### Task 6: `StoredEvent` edits (drop top-level user/device/software; add initiator, flowToken)

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/stored_event.dart`
- Modify: `apps/common-dart/append_only_datastore/test/storage/value_types_test.dart` (if it tests StoredEvent) or create `test/storage/stored_event_test.dart`

- [ ] **Step 1: Inventory existing StoredEvent tests.** Run: `grep -rn "StoredEvent\." apps/common-dart/append_only_datastore/test | head -40` to locate tests that will need updating. List them in the WORKLOG under this task.

- [ ] **Step 2: Write failing tests.** Create (or edit) `test/storage/stored_event_test.dart`:

```dart
import 'package:append_only_datastore/src/storage/initiator.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StoredEvent Phase 4.4 shape', () {
    Map<String, Object?> _minimalMap({
      Object? initiator,
      Object? flowToken,
    }) => {
      'event_id': 'e',
      'aggregate_id': 'a',
      'aggregate_type': 'DiaryEntry',
      'entry_type': 'epistaxis_event',
      'event_type': 'finalized',
      'sequence_number': 1,
      'data': const {'answers': {'x': 1}},
      'metadata': const {'change_reason': 'initial', 'provenance': []},
      'initiator': initiator ?? const {'type': 'user', 'user_id': 'u'},
      'flow_token': flowToken,
      'client_timestamp': '2026-04-22T00:00:00.000Z',
      'event_hash': 'h',
    };

    test('REQ-INITIATOR-A: initiator round-trips through fromMap/toMap', () {
      final map = _minimalMap();
      final ev = StoredEvent.fromMap(map, 7);
      expect(ev.initiator, const UserInitiator('u'));
      expect(ev.toMap()['initiator'],
          {'type': 'user', 'user_id': 'u'});
    });

    test('REQ-FLOWTOKEN-A: flowToken is nullable and round-trips', () {
      final mapNull = _minimalMap();
      final ev1 = StoredEvent.fromMap(mapNull, 7);
      expect(ev1.flowToken, isNull);

      final mapWithToken = _minimalMap(flowToken: 'invite:ABC');
      final ev2 = StoredEvent.fromMap(mapWithToken, 7);
      expect(ev2.flowToken, 'invite:ABC');
      expect(ev2.toMap()['flow_token'], 'invite:ABC');
    });

    test('top-level userId / deviceId / softwareVersion fields are removed',
        () {
      final ev = StoredEvent.fromMap(_minimalMap(), 7);
      final map = ev.toMap();
      expect(map.containsKey('user_id'), isFalse);
      expect(map.containsKey('device_id'), isFalse);
      expect(map.containsKey('software_version'), isFalse);
    });

    test('fromMap throws FormatException on missing initiator', () {
      final map = _minimalMap();
      map.remove('initiator');
      expect(() => StoredEvent.fromMap(map, 7), throwsFormatException);
    });
  });
}
```

- [ ] **Step 3: Run tests to verify failure.** Expected: compilation errors (StoredEvent still uses old fields).

- [ ] **Step 4: Edit `stored_event.dart`.** Replace the class with the Phase 4.4 shape:
  - Drop fields: `userId`, `deviceId`, `softwareVersion`.
  - Add fields: `final Initiator initiator;`, `final String? flowToken;`.
  - Update `fromMap`: parse `map['initiator']` via `Initiator.fromJson` (throw FormatException on missing); parse `map['flow_token']` as nullable String.
  - Update `toMap`: emit `'initiator': initiator.toJson()`; emit `'flow_token': flowToken` (even when null).
  - Delete `_requireString` calls for the dropped fields.
  - Update the import to reference `initiator.dart`.

- [ ] **Step 5: Re-run tests.** Run: `(cd apps/common-dart/append_only_datastore && dart test test/storage/stored_event_test.dart)`. Expected: all pass.

- [ ] **Step 6: Observe downstream test breakage.** Run: `(cd apps/common-dart/append_only_datastore && dart analyze)`. Expected: many errors in test files that construct StoredEvent with the old shape. List them in the WORKLOG but do NOT fix here — they are addressed in Task 17/18 (EventStore tests) and Task 20 (EventRepository patch). The reason for deferring: those fixes require the new `EventStore.append` path and `EventRepository` drive-by patch landed first.

- [ ] **Step 7: Commit.**

```bash
git add apps/common-dart/append_only_datastore/lib/src/storage/stored_event.dart \
        apps/common-dart/append_only_datastore/test/storage/stored_event_test.dart
git commit -m "[CUR-1154] Phase 4.4 Task 6: StoredEvent initiator + flowToken; drop top-level user/device/software"
```

WORKLOG: record that build is intentionally red after this task until Task 20.

---

### Task 7: `EntryTypeDefinition.materialize` flag

**Files:**
- Modify: `apps/common-dart/trial_data_types/lib/src/entry_type_definition.dart`
- Modify: `apps/common-dart/trial_data_types/test/entry_type_definition_test.dart`

- [ ] **Step 1: Write failing test.** Append to `test/entry_type_definition_test.dart`:

```dart
  group('REQ-MATERIALIZERS-C: materialize flag', () {
    test('defaults to true', () {
      final def = EntryTypeDefinition(
        id: 'x',
        version: '1',
        name: 'X',
        widgetId: 'w',
        widgetConfig: const <String, Object?>{},
      );
      expect(def.materialize, isTrue);
    });

    test('false round-trips through JSON', () {
      final def = EntryTypeDefinition(
        id: 'x',
        version: '1',
        name: 'X',
        widgetId: 'w',
        widgetConfig: const <String, Object?>{},
        materialize: false,
      );
      expect(def.materialize, isFalse);
      final map = def.toJson();
      expect(map['materialize'], isFalse);
      final roundTripped = EntryTypeDefinition.fromJson(map);
      expect(roundTripped.materialize, isFalse);
    });

    test('absent "materialize" in JSON defaults to true', () {
      final def = EntryTypeDefinition.fromJson(<String, Object?>{
        'id': 'x',
        'version': '1',
        'name': 'X',
        'widget_id': 'w',
        'widget_config': const <String, Object?>{},
      });
      expect(def.materialize, isTrue);
    });
  });
```

- [ ] **Step 2: Run tests to verify failure.** Run: `(cd apps/common-dart/trial_data_types && dart test)`. Expected: failing on `materialize` getter.

- [ ] **Step 3: Edit `entry_type_definition.dart`.**
  - Add `final bool materialize;` field.
  - Constructor: `this.materialize = true`.
  - `fromJson`: read `json['materialize']`; default `true` when absent; throw `FormatException` when present and not a `bool`.
  - `toJson`: emit `'materialize': materialize`.
  - Include in equality and hashCode.

- [ ] **Step 4: Re-run tests.** Expected: all pass. Run both `dart test` and `dart analyze` in `trial_data_types`.

- [ ] **Step 5: Commit.**

```bash
git add apps/common-dart/trial_data_types/lib/src/entry_type_definition.dart \
        apps/common-dart/trial_data_types/test/entry_type_definition_test.dart
git commit -m "[CUR-1154] Phase 4.4 Task 7: EntryTypeDefinition.materialize flag"
```

---

### Task 8: `Materializer` abstract + `DiaryEntriesMaterializer` extract

**Files:**
- Rewrite: `apps/common-dart/append_only_datastore/lib/src/materialization/materializer.dart`
- Create: `apps/common-dart/append_only_datastore/lib/src/materialization/diary_entries_materializer.dart`
- Modify: `apps/common-dart/append_only_datastore/test/materialization/materializer_test.dart` (rename internally OR create new file `diary_entries_materializer_test.dart`)

The existing `Materializer.apply(...)` static function is pure-fold logic for `diary_entries`. This task extracts that logic into `DiaryEntriesMaterializer.applyInTxn` while preserving the same folding semantics, and introduces the abstract base class for pluggability.

- [ ] **Step 1: Read the existing Materializer.apply tests.** Run: `Read apps/common-dart/append_only_datastore/test/materialization/materializer_test.dart`. These remain valid against the new `DiaryEntriesMaterializer` fold logic — keep them, but port their invocations from `Materializer.apply(...)` (pure static) to exercise the concrete `DiaryEntriesMaterializer` via the generic view API.

  Because the fold is still pure, keep a pure helper on `DiaryEntriesMaterializer` for use in tests: `@visibleForTesting static DiaryEntry foldPure({previous, event, def, firstEventTimestamp})` — the in-txn method delegates to this helper after the prior-row read. This preserves the existing pure-fold test surface without re-wiring the whole test to exercise a `StorageBackend` double.

- [ ] **Step 2: Write new abstract-interface tests.** Create `test/materialization/diary_entries_materializer_test.dart` (or extend the existing materializer_test.dart with a new group). The tests below verify that `DiaryEntriesMaterializer` has the right `viewName`, `appliesTo`, and the pure fold contract is intact:

```dart
import 'package:append_only_datastore/src/materialization/diary_entries_materializer.dart';
import 'package:append_only_datastore/src/materialization/materializer.dart';
import 'package:append_only_datastore/src/storage/initiator.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trial_data_types/trial_data_types.dart';

StoredEvent _event(String entryType, String aggregateId, {
  String eventType = 'finalized',
  Map<String, Object?>? answers,
}) => StoredEvent.fromMap({
  'event_id': 'e-$aggregateId',
  'aggregate_id': aggregateId,
  'aggregate_type': 'DiaryEntry',
  'entry_type': entryType,
  'event_type': eventType,
  'sequence_number': 1,
  'data': {'answers': answers ?? const {'x': 1}},
  'metadata': const {'change_reason': 'initial', 'provenance': []},
  'initiator': const {'type': 'user', 'user_id': 'u'},
  'flow_token': null,
  'client_timestamp': '2026-04-22T00:00:00.000Z',
  'event_hash': 'h',
}, 0);

void main() {
  group('DiaryEntriesMaterializer', () {
    test('REQ-MATERIALIZERS-A: viewName is "diary_entries"', () {
      final m = DiaryEntriesMaterializer();
      expect(m.viewName, 'diary_entries');
    });

    test('REQ-MATERIALIZERS-A: appliesTo returns true for DiaryEntry '
        'aggregateType; false otherwise', () {
      final m = DiaryEntriesMaterializer();
      final diary = _event('epistaxis_event', 'a');
      expect(m.appliesTo(diary), isTrue);

      final security = StoredEvent.fromMap({
        ...diary.toMap(),
        'aggregate_type': 'security_context',
      }, 0);
      expect(m.appliesTo(security), isFalse);
    });

    test('Materializer is abstract — cannot be instantiated directly', () {
      // Compile-time check: the following is intentionally commented.
      // final m = Materializer(); // would not compile
      expect(DiaryEntriesMaterializer(), isA<Materializer>());
    });
  });
}
```

- [ ] **Step 3: Run tests to verify failure.** Expected: compilation errors (no `DiaryEntriesMaterializer`, `Materializer` still has static `apply`).

- [ ] **Step 4: Rewrite `materializer.dart`.** Replace the class body with an abstract contract:

```dart
import 'package:append_only_datastore/src/storage/storage_backend.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:append_only_datastore/src/storage/txn.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Pluggable fold contract. One `Materializer` maintains one
/// `StorageBackend` view. `EventStore.append` runs every materializer whose
/// `appliesTo(event)` is true for each appended event, inside the same
/// transaction as the append; a throw rolls back the whole append.
// Implements: REQ-MATERIALIZERS-A — abstract fold contract.
abstract class Materializer {
  const Materializer();

  /// Name of the backend view this materializer maintains. Used by
  /// `StorageBackend.{read,upsert,delete,find,clear}View*` methods to
  /// scope reads and writes.
  String get viewName;

  /// True iff this materializer folds [event] into its view.
  // Implements: REQ-MATERIALIZERS-A — appliesTo filter.
  bool appliesTo(StoredEvent event);

  /// Apply the fold step inside [txn]. Reads prior view rows and writes
  /// the next row via the generic view methods on [backend]. [aggregateHistory]
  /// is the aggregate's event list inside the same transaction (callers
  /// pass this to avoid a redundant read when the fold needs prior events).
  Future<void> applyInTxn(
    Txn txn,
    StorageBackend backend, {
    required StoredEvent event,
    required EntryTypeDefinition def,
    required List<StoredEvent> aggregateHistory,
  });
}
```

- [ ] **Step 5: Create `diary_entries_materializer.dart`.** The class lifts the existing fold logic out of `materializer.dart`:

```dart
import 'package:append_only_datastore/src/materialization/materializer.dart';
import 'package:append_only_datastore/src/storage/diary_entry.dart';
import 'package:append_only_datastore/src/storage/storage_backend.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:append_only_datastore/src/storage/txn.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:trial_data_types/trial_data_types.dart';

class DiaryEntriesMaterializer extends Materializer {
  const DiaryEntriesMaterializer();

  @override
  String get viewName => 'diary_entries';

  @override
  bool appliesTo(StoredEvent event) => event.aggregateType == 'DiaryEntry';

  @override
  Future<void> applyInTxn(
    Txn txn,
    StorageBackend backend, {
    required StoredEvent event,
    required EntryTypeDefinition def,
    required List<StoredEvent> aggregateHistory,
  }) async {
    final priorRowRaw =
        await backend.readViewRowInTxn(txn, viewName, event.aggregateId);
    final prior = priorRowRaw == null ? null : DiaryEntry.fromJson(priorRowRaw);
    final firstTs = aggregateHistory.isEmpty
        ? event.clientTimestamp
        : aggregateHistory.first.clientTimestamp;
    final next = foldPure(
      previous: prior,
      event: event,
      def: def,
      firstEventTimestamp: firstTs,
    );
    await backend.upsertViewRowInTxn(
        txn, viewName, next.entryId, next.toJson());
  }

  /// Pure fold (no I/O). Preserved from the Phase-3 `Materializer.apply`
  /// entry point for reuse by `rebuildView` and by unit tests.
  @visibleForTesting
  static DiaryEntry foldPure({
    required DiaryEntry? previous,
    required StoredEvent event,
    required EntryTypeDefinition def,
    required DateTime firstEventTimestamp,
  }) {
    // Body copied verbatim from Phase-3 Materializer.apply.
    // (Paste the switch over eventType: tombstone / finalized / checkpoint /
    // default-throw, plus _extractAnswers and _resolveEffectiveDate private
    // helpers in this file. Keep behavior byte-for-byte identical to the
    // Phase-3 implementation.)
  }
}
```

When copying, move the `_extractAnswers`, `_resolveEffectiveDate`, and `_walkDottedPath` helpers from the old `materializer.dart` into this file as top-level `_`-prefixed functions.

- [ ] **Step 6: Update `rebuild.dart`.** Edit:
  - Signature from `rebuildMaterializedView(backend, lookup)` to `rebuildView(materializer, backend, lookup)`.
  - Use `materializer.viewName` for clear + upsert via generic view methods (`backend.clearViewInTxn(txn, materializer.viewName)`, `backend.upsertViewRowInTxn(txn, materializer.viewName, aggregateId, row.toJson())`).
  - Replace direct `Materializer.apply(...)` calls with `DiaryEntriesMaterializer.foldPure(...)` when materializer is `DiaryEntriesMaterializer` — but for the generic case, call `materializer.applyInTxn(...)` per event. (The `DiaryEntriesMaterializer` has an accumulator-friendly path; keep the chunked rebuild semantics. Concrete shape: for each event in chunk, call `materializer.applyInTxn(txn, backend, event: ev, def: lookup.lookup(ev.entryType), aggregateHistory: [...eventsForAggregateSoFar])`.)

  **Decision to note in WORKLOG:** this changes `rebuildView` from an in-memory accumulator (O(distinct_aggregates × row_size) peak) to per-event write-through. The accumulator was a memory optimization, not a correctness optimization. The materializer contract now owns view semantics, so peak memory is whatever the concrete materializer's in-txn reads buffer — for `DiaryEntriesMaterializer`, one row at a time. Acceptable for mobile; portal can ship its own rebuild variant if needed.

- [ ] **Step 7: Update existing materializer_test.dart tests.** Replace `Materializer.apply(...)` call sites with `DiaryEntriesMaterializer.foldPure(...)`. The fold semantics are preserved, so the tests' expectations stay intact.

- [ ] **Step 8: Re-run tests.** Run: `(cd apps/common-dart/append_only_datastore && dart test test/materialization/)`. Expected: all pass (rebuild_test.dart may still fail if it depends on removed diary-view methods; that's fixed in Task 10).

- [ ] **Step 9: Commit.**

```bash
git add apps/common-dart/append_only_datastore/lib/src/materialization \
        apps/common-dart/append_only_datastore/test/materialization
git commit -m "[CUR-1154] Phase 4.4 Task 8: Materializer becomes abstract; DiaryEntriesMaterializer extracted"
```

---

### Task 9: `StorageBackend` contract — generic view methods; drop diary methods

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart`
- Create: `apps/common-dart/append_only_datastore/test/storage/storage_backend_views_test.dart` (written against `SembastBackend` as the concrete impl, since the contract is abstract)

This task edits the abstract contract only. The Sembast impl lands in Task 10.

- [ ] **Step 1: Write failing tests.** Create `test/storage/storage_backend_views_test.dart` (will fail compilation until Task 10 lands the impl):

```dart
import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<SembastBackend> _backend() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'views-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return SembastBackend(database: db);
}

void main() {
  group('REQ-MATERIALIZERS-F: generic view storage on StorageBackend', () {
    test('read missing key returns null', () async {
      final b = await _backend();
      final row = await b.transaction((txn) async =>
          b.readViewRowInTxn(txn, 'test_view', 'missing'));
      expect(row, isNull);
    });

    test('upsert then read round-trips', () async {
      final b = await _backend();
      await b.transaction((txn) async {
        await b.upsertViewRowInTxn(txn, 'test_view', 'k1', {'a': 1, 'b': 's'});
      });
      final row = await b.transaction(
          (txn) async => b.readViewRowInTxn(txn, 'test_view', 'k1'));
      expect(row, {'a': 1, 'b': 's'});
    });

    test('delete removes the row', () async {
      final b = await _backend();
      await b.transaction((txn) async {
        await b.upsertViewRowInTxn(txn, 'test_view', 'k', {'x': 1});
        await b.deleteViewRowInTxn(txn, 'test_view', 'k');
      });
      final row = await b.transaction(
          (txn) async => b.readViewRowInTxn(txn, 'test_view', 'k'));
      expect(row, isNull);
    });

    test('findViewRows iterates with limit', () async {
      final b = await _backend();
      await b.transaction((txn) async {
        for (var i = 0; i < 5; i++) {
          await b.upsertViewRowInTxn(txn, 'v', 'k$i', {'i': i});
        }
      });
      final all = await b.findViewRows('v');
      expect(all, hasLength(5));
      final two = await b.findViewRows('v', limit: 2);
      expect(two, hasLength(2));
    });

    test('clearViewInTxn empties one view without touching others', () async {
      final b = await _backend();
      await b.transaction((txn) async {
        await b.upsertViewRowInTxn(txn, 'a', 'k', {'x': 1});
        await b.upsertViewRowInTxn(txn, 'b', 'k', {'y': 2});
        await b.clearViewInTxn(txn, 'a');
      });
      expect(await b.findViewRows('a'), isEmpty);
      expect(await b.findViewRows('b'), hasLength(1));
    });

    test('viewName isolation: writing to "a" never affects "b"', () async {
      final b = await _backend();
      await b.transaction((txn) async {
        await b.upsertViewRowInTxn(txn, 'a', 'k', {'src': 'a'});
        await b.upsertViewRowInTxn(txn, 'b', 'k', {'src': 'b'});
      });
      final a = await b.transaction(
          (txn) async => b.readViewRowInTxn(txn, 'a', 'k'));
      final bb = await b.transaction(
          (txn) async => b.readViewRowInTxn(txn, 'b', 'k'));
      expect(a, {'src': 'a'});
      expect(bb, {'src': 'b'});
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure.** Expected: compilation errors (methods don't exist).

- [ ] **Step 3: Edit `storage_backend.dart`.**
  - Delete abstract declarations: `upsertEntry`, `clearEntries`, `findEntries`, `readEntryInTxn`. (These are the diary-specific methods per design doc §4.9; greenfield allows dropping.)
  - Add abstract declarations:
  ```dart
  Future<Map<String, dynamic>?> readViewRowInTxn(
   Txn txn, String viewName, String key);
  Future<void> upsertViewRowInTxn(
   Txn txn, String viewName, String key, Map<String, dynamic> row);
  Future<void> deleteViewRowInTxn(Txn txn, String viewName, String key);
  Future<List<Map<String, dynamic>>> findViewRows(
   String viewName, {int? limit, int? offset});
  Future<void> clearViewInTxn(Txn txn, String viewName);
  ```
  - Remove the `diary_entry.dart` import.
  - Keep `DiaryEntry` value type around (used by `DiaryEntriesMaterializer`) — it stays a public export.

- [ ] **Step 4: Don't run tests yet.** Sembast impl lands in Task 10; build stays red until then. Commit the contract-only change now.

```bash
git add apps/common-dart/append_only_datastore/lib/src/storage/storage_backend.dart \
        apps/common-dart/append_only_datastore/test/storage/storage_backend_views_test.dart
git commit -m "[CUR-1154] Phase 4.4 Task 9: StorageBackend generic view contract; drop diary methods"
```

WORKLOG: build intentionally red until Task 10.

---

### Task 10: `SembastBackend` — generic view impl + indexes

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart`

- [ ] **Step 1: Delete old diary-view impl code in `sembast_backend.dart`.**
  - Remove: `_entriesStore` StoreRef, `upsertEntry`, `clearEntries`, `findEntries`, `readEntryInTxn` implementations.
  - Remove: the `import 'diary_entry.dart'` if no longer used.

- [ ] **Step 2: Add generic view-store caching and impl.** In the class body:

```dart
final Map<String, StoreRef<String, Map<String, Object?>>> _viewStores = {};

StoreRef<String, Map<String, Object?>> _viewStore(String viewName) =>
    _viewStores.putIfAbsent(
        viewName, () => stringMapStoreFactory.store(viewName));

@override
Future<Map<String, dynamic>?> readViewRowInTxn(
    Txn txn, String viewName, String key) async {
  final t = _requireValidTxn(txn);
  final raw = await _viewStore(viewName).record(key).get(t._sembastTxn);
  if (raw == null) return null;
  return Map<String, dynamic>.from(raw);
}

@override
Future<void> upsertViewRowInTxn(
    Txn txn, String viewName, String key,
    Map<String, dynamic> row) async {
  final t = _requireValidTxn(txn);
  await _viewStore(viewName).record(key).put(
      t._sembastTxn, Map<String, Object?>.from(row));
}

@override
Future<void> deleteViewRowInTxn(
    Txn txn, String viewName, String key) async {
  final t = _requireValidTxn(txn);
  await _viewStore(viewName).record(key).delete(t._sembastTxn);
}

@override
Future<List<Map<String, dynamic>>> findViewRows(
    String viewName, {int? limit, int? offset}) async {
  final db = _database();
  final finder = Finder(limit: limit, offset: offset);
  final records = await _viewStore(viewName).find(db, finder: finder);
  return records
      .map((r) => Map<String, dynamic>.from(r.value))
      .toList(growable: false);
}

@override
Future<void> clearViewInTxn(Txn txn, String viewName) async {
  final t = _requireValidTxn(txn);
  await _viewStore(viewName).delete(t._sembastTxn);
}
```

- [ ] **Step 3: Add sembast index on `flow_token`** on the events store. Sembast supports field indexing via the store's `index` configuration OR via Finder filters that scan. For performance parity with the assertion REQ-FLOWTOKEN-D, add a dedicated query helper `findEventsByFlowToken(flowToken)` on SembastBackend and note in the WORKLOG that sembast itself doesn't use declarative indexes the same way postgres does — the "index" is really the Finder + Filter optimization path. Document this: for the spec-level assertion, sembast's Finder on a Filter.equals of `flow_token` runs in O(N) naive but with field-filter predicates on the underlying cache it is acceptable for mobile-scale logs; the PostgreSQL backend (future) will add a real GIN index.

  **Decision to note in WORKLOG:** REQ-FLOWTOKEN-D requires "indexed for query" — sembast has no CREATE INDEX primitive, so we satisfy the spec by making `flow_token` a first-class key the backend's query methods can filter on (not a nested path). This is consistent with how REQ-d00128-G treats `fill_cursor_<destinationId>`. The REQ text should say "queryable efficiently on mobile backend" rather than promising a literal B-tree. Update the REQ assertion wording in Task 3 if this hasn't happened yet.

- [ ] **Step 4: Run tests.** Run:
  - `(cd apps/common-dart/append_only_datastore && dart test test/storage/storage_backend_views_test.dart)` — all pass.
  - `(cd apps/common-dart/append_only_datastore && dart analyze)` — remaining errors are in test files referencing dropped `StoredEvent.userId` / `StoredEvent.deviceId` or legacy `upsertEntry`; those are fixed in subsequent tasks.

- [ ] **Step 5: Commit.**

```bash
git add apps/common-dart/append_only_datastore/lib/src/storage/sembast_backend.dart
git commit -m "[CUR-1154] Phase 4.4 Task 10: SembastBackend generic view impl"
```

---

### Task 11: `EventSecurityContext` value type

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/security/event_security_context.dart`
- Create: `apps/common-dart/append_only_datastore/test/security/event_security_context_test.dart`

- [ ] **Step 1: Write failing tests.**

```dart
import 'package:append_only_datastore/src/security/event_security_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EventSecurityContext', () {
    test('required + optional fields construct and round-trip to JSON', () {
      final ctx = EventSecurityContext(
        eventId: 'e-1',
        recordedAt: DateTime.utc(2026, 4, 22, 12, 0),
        ipAddress: '203.0.113.7',
        userAgent: 'UA/1',
        sessionId: 'sess-9',
        geoCountry: 'US',
        geoRegion: 'NY',
        requestId: 'req-1',
        redactedAt: null,
        redactionReason: null,
      );
      final json = ctx.toJson();
      expect(json['event_id'], 'e-1');
      expect(json['ip_address'], '203.0.113.7');
      expect(json['redacted_at'], isNull);
      final back = EventSecurityContext.fromJson(json);
      expect(back, ctx);
    });

    test('null optional fields round-trip as null', () {
      final ctx = EventSecurityContext(
        eventId: 'e-2',
        recordedAt: DateTime.utc(2026, 4, 22),
      );
      final json = ctx.toJson();
      expect(json['ip_address'], isNull);
      expect(EventSecurityContext.fromJson(json), ctx);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure.**

- [ ] **Step 3: Implement `event_security_context.dart`.**
  - Fields per design §4.7: `eventId`, `recordedAt`, `ipAddress?`, `userAgent?`, `sessionId?`, `geoCountry?`, `geoRegion?`, `requestId?`, `redactedAt?`, `redactionReason?`.
  - `toJson` emits snake_case keys; `fromJson` reverse with FormatException on missing required fields.
  - Implement `==` and `hashCode` and `toString` deterministically.

- [ ] **Step 4: Run tests; all pass.**

- [ ] **Step 5: Commit.**

```bash
git add apps/common-dart/append_only_datastore/lib/src/security/event_security_context.dart \
        apps/common-dart/append_only_datastore/test/security/event_security_context_test.dart
git commit -m "[CUR-1154] Phase 4.4 Task 11: EventSecurityContext value type"
```

---

### Task 12: `SecurityDetails` and `SecurityRetentionPolicy` value types

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/security/security_details.dart`
- Create: `apps/common-dart/append_only_datastore/lib/src/security/security_retention_policy.dart`
- Create: `apps/common-dart/append_only_datastore/test/security/retention_policy_test.dart`

- [ ] **Step 1: Write failing tests.** Create `test/security/retention_policy_test.dart`:

```dart
import 'package:append_only_datastore/src/security/security_retention_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecurityRetentionPolicy', () {
    test('REQ-RETENTION-A: defaults match spec', () {
      const p = SecurityRetentionPolicy.defaults;
      expect(p.fullRetention, const Duration(days: 90));
      expect(p.truncatedRetention, const Duration(days: 365));
      expect(p.truncateIpv4LastOctet, isTrue);
      expect(p.truncateIpv6Suffix, isTrue);
      expect(p.dropUserAgentAfterFull, isTrue);
      expect(p.dropGeoAfterFull, isFalse);
      expect(p.dropAllAfterTruncated, isTrue);
    });

    test('REQ-RETENTION-A: round-trips through toJson/fromJson', () {
      const p = SecurityRetentionPolicy(
        fullRetention: Duration(days: 30),
        truncatedRetention: Duration(days: 100),
        truncateIpv4LastOctet: false,
        truncateIpv6Suffix: true,
        dropUserAgentAfterFull: false,
        dropGeoAfterFull: true,
        dropAllAfterTruncated: false,
      );
      expect(SecurityRetentionPolicy.fromJson(p.toJson()), p);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify failure.**

- [ ] **Step 3: Implement `security_details.dart`:**

```dart
/// Immutable input passed by `EventStore.append` callers when the event
/// should carry security telemetry. Dispatcher stamps `eventId` and
/// `recordedAt` on write; redaction fields are set by the retention
/// policy, never by the caller.
class SecurityDetails {
  const SecurityDetails({
    this.ipAddress,
    this.userAgent,
    this.sessionId,
    this.geoCountry,
    this.geoRegion,
    this.requestId,
  });

  final String? ipAddress;
  final String? userAgent;
  final String? sessionId;
  final String? geoCountry;
  final String? geoRegion;
  final String? requestId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SecurityDetails &&
          ipAddress == other.ipAddress &&
          userAgent == other.userAgent &&
          sessionId == other.sessionId &&
          geoCountry == other.geoCountry &&
          geoRegion == other.geoRegion &&
          requestId == other.requestId);

  @override
  int get hashCode => Object.hash(
        ipAddress, userAgent, sessionId, geoCountry, geoRegion, requestId);
}
```

- [ ] **Step 4: Implement `security_retention_policy.dart`** per design §4.7. Include `static const SecurityRetentionPolicy defaults`, `toJson`, `fromJson`, `==`, `hashCode`.

- [ ] **Step 5: Run tests; all pass. Commit.**

```bash
git add apps/common-dart/append_only_datastore/lib/src/security/security_details.dart \
        apps/common-dart/append_only_datastore/lib/src/security/security_retention_policy.dart \
        apps/common-dart/append_only_datastore/test/security/retention_policy_test.dart
git commit -m "[CUR-1154] Phase 4.4 Task 12: SecurityDetails + SecurityRetentionPolicy"
```

---

### Task 13: `SecurityContextStore` abstract + `PagedAudit` + `AuditRow`

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/security/security_context_store.dart`

No tests at this task — the contract is abstract. Tests land in Task 14 against the sembast impl.

- [ ] **Step 1: Implement `security_context_store.dart`.**

```dart
import 'package:append_only_datastore/src/security/event_security_context.dart';
import 'package:append_only_datastore/src/storage/initiator.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:append_only_datastore/src/storage/txn.dart';

/// Read-side contract for the security-context sidecar. Mutations are
/// package-private — only `EventStore` writes, updates, or deletes rows so
/// each mutation commits atomically with the event it describes.
// Implements: REQ-SECCTX-A — sidecar store.
// Implements: REQ-SECCTX-E — mutations are package-private.
// Implements: REQ-SECCTX-F — queryAudit contract.
abstract class SecurityContextStore {
  Future<EventSecurityContext?> read(String eventId);

  Future<PagedAudit> queryAudit({
    Initiator? initiator,
    String? flowToken,
    String? ipAddress,
    DateTime? from,
    DateTime? to,
    int limit = 50,
    String? cursor,
  });
}

/// Package-private mutation API used only by `EventStore`. Concrete store
/// implementations extend this to expose writes without leaking the
/// mutation surface to application code.
abstract class InternalSecurityContextStore extends SecurityContextStore {
  Future<void> writeInTxn(Txn txn, EventSecurityContext row);
  Future<EventSecurityContext?> readInTxn(Txn txn, String eventId);
  Future<void> deleteInTxn(Txn txn, String eventId);
  Future<List<EventSecurityContext>> findUnredactedOlderThanInTxn(
      Txn txn, DateTime cutoff);
  Future<List<EventSecurityContext>> findOlderThanInTxn(
      Txn txn, DateTime cutoff);
  Future<void> upsertInTxn(Txn txn, EventSecurityContext row);
}

class PagedAudit {
  const PagedAudit({required this.rows, this.nextCursor});
  final List<AuditRow> rows;
  final String? nextCursor;
}

class AuditRow {
  const AuditRow({required this.event, required this.context});
  final StoredEvent event;
  final EventSecurityContext context;
}
```

- [ ] **Step 2: Run `dart analyze`.** Expected: no new errors.

- [ ] **Step 3: Commit.**

```bash
git add apps/common-dart/append_only_datastore/lib/src/security/security_context_store.dart
git commit -m "[CUR-1154] Phase 4.4 Task 13: SecurityContextStore abstract + PagedAudit + AuditRow"
```

---

### Task 14: `SembastSecurityContextStore` — read, queryAudit, package-private mutations

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/security/sembast_security_context_store.dart`
- Create: `apps/common-dart/append_only_datastore/test/security/sembast_security_context_store_test.dart`
- Create: `apps/common-dart/append_only_datastore/test/security/query_audit_test.dart`

- [ ] **Step 1: Write failing store-level tests.** Create `test/security/sembast_security_context_store_test.dart`:

```dart
import 'package:append_only_datastore/src/security/event_security_context.dart';
import 'package:append_only_datastore/src/security/sembast_security_context_store.dart';
import 'package:append_only_datastore/src/storage/sembast_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<(SembastBackend, SembastSecurityContextStore)> _setup() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'sec-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  final store = SembastSecurityContextStore(backend: backend);
  return (backend, store);
}

void main() {
  group('SembastSecurityContextStore', () {
    test('REQ-SECCTX-D: read on missing returns null', () async {
      final (_, store) = await _setup();
      expect(await store.read('nope'), isNull);
    });

    test('writeInTxn + read round-trip', () async {
      final (backend, store) = await _setup();
      final row = EventSecurityContext(
        eventId: 'e-1',
        recordedAt: DateTime.utc(2026, 4, 22),
        ipAddress: '198.51.100.2',
      );
      await backend.transaction((txn) async {
        await store.writeInTxn(txn, row);
      });
      expect(await store.read('e-1'), row);
    });

    test('one-way FK: deleting the security row does not touch event log',
        () async {
      final (backend, store) = await _setup();
      await backend.transaction((txn) async {
        await store.writeInTxn(
            txn,
            EventSecurityContext(
                eventId: 'e-2', recordedAt: DateTime.utc(2026, 4, 22)));
      });
      await backend.transaction((txn) async {
        await store.deleteInTxn(txn, 'e-2');
      });
      expect(await store.read('e-2'), isNull);
      expect(await backend.findAllEvents(), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Write failing queryAudit tests.** Create `test/security/query_audit_test.dart` asserting `REQ-SECCTX-F` contract (limit bounds, paging, filter combinations, corrupt cursor → ArgumentError, empty result shape). Build the fixture via `EventStore.append` (Task 17) — BUT since Task 17 lands later, scaffold the fixture by directly writing events via `SembastBackend.appendEvent` plus writing security rows via `store.writeInTxn`. Mark the test `@TestOn('!browser')` is unnecessary.

  Use `_setup()` from the previous test. Test cases:
  - `limit: 0` throws `ArgumentError`; `limit: 1001` throws `ArgumentError`.
  - No filters + 3 rows: returns 3 `AuditRow`s sorted by `recordedAt` desc.
  - `ipAddress` filter: returns only rows matching.
  - `initiator` filter (UserInitiator('u1')): returns only events with that user initiator.
  - `flowToken` filter: returns only events matching.
  - `from`/`to` range: returns rows within window.
  - `cursor`: first page + next-page continuation returns remainder with no overlap.
  - `'corrupt'` cursor throws `ArgumentError`.
  - Empty result: `rows=[]`, `nextCursor=null`.

  For the event fixture, construct each `StoredEvent` via `StoredEvent.fromMap(...)` with the Phase 4.4 shape (initiator + flowToken). Use the store's `writeInTxn` to stamp security rows. This does bypass the atomic `EventStore.append` path — note in the test file header that it tests queryAudit in isolation; atomicity is exercised elsewhere.

- [ ] **Step 3: Run tests to verify failure.**

- [ ] **Step 4: Implement `sembast_security_context_store.dart`.**

Key implementation details:
- Store name: `'security_context'` (string-map store, key = `eventId`).
- `writeInTxn`: `_store.record(row.eventId).put(t._sembastTxn, row.toJson())`.
- `readInTxn`/`read`: get by key.
- `deleteInTxn`: delete by key.
- `findUnredactedOlderThanInTxn(cutoff)`: finder with filter `redacted_at IS NULL AND recorded_at <= cutoff`.
- `findOlderThanInTxn(cutoff)`: finder with filter `recorded_at <= cutoff`.
- `upsertInTxn`: same as write.
- `queryAudit`:
  1. Validate `limit` in `[1, 1000]`; validate cursor parseable (throw `ArgumentError` on malformed).
  2. Build security-row finder with ipAddress + from/to filters.
  3. Fetch security rows matching; collect their `eventId`s.
  4. Fetch matching events from event_log: filter by `eventId IN eventIds`; apply `initiator` and `flowToken` filters.
  5. Inner-join on `eventId`; sort by `recordedAt desc`; apply cursor pagination.
  6. Return `PagedAudit`. Cursor encoding: `"$recordedAtIso|$eventId"` base64-encoded; decode and use as lower-bound filter for next page.

- [ ] **Step 5: Run tests; all pass.**

- [ ] **Step 6: Commit.**

```bash
git add apps/common-dart/append_only_datastore/lib/src/security/sembast_security_context_store.dart \
        apps/common-dart/append_only_datastore/test/security
git commit -m "[CUR-1154] Phase 4.4 Task 14: SembastSecurityContextStore + queryAudit"
```

---

### Task 15: System entry types (3 reserved)

**Files:**
- Create: `apps/common-dart/append_only_datastore/lib/src/security/system_entry_types.dart`

- [ ] **Step 1: Implement.** Constants for the three reserved system entry types:

```dart
import 'package:trial_data_types/trial_data_types.dart';

/// Reserved id for the per-event security-context redaction audit event.
const String kSecurityContextRedactedEntryType = 'security_context_redacted';

/// Reserved id for the bulk-truncation (retention compact) audit event.
const String kSecurityContextCompactedEntryType = 'security_context_compacted';

/// Reserved id for the bulk-delete (retention purge) audit event.
const String kSecurityContextPurgedEntryType = 'security_context_purged';

/// The three reserved system entry types that `bootstrapAppendOnlyDatastore`
/// auto-registers BEFORE the caller-supplied list. All three are
/// `materialize: false` so they never hit any view; they exist only to
/// stamp an immutable event_log row for every security-context mutation.
// Implements: REQ-RETENTION-D+E+F+G — system-entry-type registration.
const List<EntryTypeDefinition> kSystemEntryTypes = [
  EntryTypeDefinition(
    id: kSecurityContextRedactedEntryType,
    version: '1',
    name: 'Security Context Redacted',
    widgetId: '_system',
    widgetConfig: <String, Object?>{},
    materialize: false,
  ),
  EntryTypeDefinition(
    id: kSecurityContextCompactedEntryType,
    version: '1',
    name: 'Security Context Compacted',
    widgetId: '_system',
    widgetConfig: <String, Object?>{},
    materialize: false,
  ),
  EntryTypeDefinition(
    id: kSecurityContextPurgedEntryType,
    version: '1',
    name: 'Security Context Purged',
    widgetId: '_system',
    widgetConfig: <String, Object?>{},
    materialize: false,
  ),
];
```

- [ ] **Step 2: No test file needed for constants** — their wiring is tested in Task 18 (bootstrap).

- [ ] **Step 3: Commit.**

```bash
git add apps/common-dart/append_only_datastore/lib/src/security/system_entry_types.dart
git commit -m "[CUR-1154] Phase 4.4 Task 15: three reserved system entry types"
```

---

### Task 16: `StoredEvent.synthetic` test-fixture factory

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/storage/stored_event.dart`

- [ ] **Step 1: Write test.** Add to `test/storage/stored_event_test.dart`:

```dart
  group('StoredEvent.synthetic', () {
    test('constructs a minimally-valid StoredEvent for test fixtures', () {
      final ev = StoredEvent.synthetic(
        eventId: 'x',
        aggregateId: 'a',
        entryType: 't',
        initiator: const UserInitiator('u'),
        eventHash: 'h',
        clientTimestamp: DateTime.utc(2026, 4, 22),
      );
      expect(ev.eventId, 'x');
      expect(ev.aggregateId, 'a');
      expect(ev.initiator, const UserInitiator('u'));
      expect(ev.sequenceNumber, 0);
      expect(ev.data, isEmpty);
      expect(ev.metadata, isEmpty);
    });
  });
```

- [ ] **Step 2: Add factory.** In `stored_event.dart`:

```dart
  /// Test-only factory for constructing a `StoredEvent` without the hash
  /// chain. Downstream packages' in-memory `StorageBackend` doubles use
  /// this to seed events without re-implementing hash chaining.
  @visibleForTesting
  factory StoredEvent.synthetic({
    int key = 0,
    required String eventId,
    required String aggregateId,
    String aggregateType = 'DiaryEntry',
    required String entryType,
    String eventType = 'finalized',
    int sequenceNumber = 0,
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
    required Initiator initiator,
    String? flowToken,
    required DateTime clientTimestamp,
    required String eventHash,
    String? previousEventHash,
    DateTime? syncedAt,
  }) => StoredEvent(
    key: key,
    eventId: eventId,
    aggregateId: aggregateId,
    aggregateType: aggregateType,
    entryType: entryType,
    eventType: eventType,
    sequenceNumber: sequenceNumber,
    data: data ?? const <String, dynamic>{},
    metadata: metadata ?? const <String, dynamic>{},
    initiator: initiator,
    flowToken: flowToken,
    clientTimestamp: clientTimestamp,
    eventHash: eventHash,
    previousEventHash: previousEventHash,
    syncedAt: syncedAt,
  );
```

Import `package:flutter/foundation.dart' show visibleForTesting;`.

- [ ] **Step 3: Run tests; all pass. Commit.**

```bash
git add apps/common-dart/append_only_datastore/lib/src/storage/stored_event.dart \
        apps/common-dart/append_only_datastore/test/storage/stored_event_test.dart
git commit -m "[CUR-1154] Phase 4.4 Task 16: StoredEvent.synthetic test factory"
```

---

### Task 17: `EventStore` — rename + new `append` signature; keep retention/clear for Task 18

**Files:**
- Rename: `apps/common-dart/append_only_datastore/lib/src/entry_service.dart` → `apps/common-dart/append_only_datastore/lib/src/event_store.dart`
- Rename: `apps/common-dart/append_only_datastore/test/entry_service_test.dart` → `test/event_store_append_test.dart`
- Delete: `DeviceInfo` class from the (renamed) file — it's now in `Source`.

- [ ] **Step 1: `git mv` the two files.**

```bash
git mv apps/common-dart/append_only_datastore/lib/src/entry_service.dart \
       apps/common-dart/append_only_datastore/lib/src/event_store.dart
git mv apps/common-dart/append_only_datastore/test/entry_service_test.dart \
       apps/common-dart/append_only_datastore/test/event_store_append_test.dart
```

- [ ] **Step 2: Rewrite `event_store.dart`.** Replace the file contents with:
  - Import `initiator.dart`, `source.dart`, `stored_event.dart`, `storage_backend.dart`, `txn.dart`, `entry_type_registry.dart`, `materialization/materializer.dart`, `security/security_details.dart`, `security/security_context_store.dart`, `security/event_security_context.dart`, `security/system_entry_types.dart`, `sync/drain.dart` (for ClockFn).
  - Keep the `SyncCycleTrigger` typedef.
  - DELETE the `DeviceInfo` class entirely.
  - Create `class EventStore` with the constructor:

```dart
class EventStore {
  EventStore({
    required this.backend,
    required this.entryTypes,
    required this.source,
    required this.securityContexts,
    this.materializers = const <Materializer>[],
    this.syncCycleTrigger,
    ClockFn? clock,
    Uuid? uuid,
  }) : _clock = clock,
       _uuid = uuid ?? const Uuid();

  final StorageBackend backend;
  final EntryTypeRegistry entryTypes;
  final Source source;
  final InternalSecurityContextStore securityContexts;
  final List<Materializer> materializers;
  final SyncCycleTrigger? syncCycleTrigger;
  final ClockFn? _clock;
  final Uuid _uuid;
}
```

- Implement `append(...)` per design §5.1. Key points:
- Pre-transaction validation: eventType allowlist, entryType registration, non-empty aggregateType, build provenance0 from `source`.
- Inside transaction: if dedupeByContent, read aggregateHistory and compare content hash vs last event; if equal, return null.
- Read previousEventHash; reserve sequenceNumber; generate eventId.
- Build metadata: `{...caller, change_reason: changeReason ?? 'initial', provenance: [provenance0.toJson()]}`.
- Build eventRecord with identity fields; compute `event_hash` via SHA-256 over JCS-canonical subset `{event_id, aggregate_id, entry_type, event_type, sequence_number, data, initiator, flow_token, client_timestamp, previous_event_hash, metadata}`.
- Stamp `event_hash` into record; build `StoredEvent.fromMap(recordMap, 0)`.
- `backend.appendEvent(txn, event)`.
- If `security != null`: `securityContexts.writeInTxn(txn, EventSecurityContext(eventId, recordedAt: clock.now, …security))`.
- For each materializer matching the event AND `def.materialize == true`, call `m.applyInTxn(txn, backend, event: event, def: def, aggregateHistory: aggregateHistory)`.
- After commit: `unawaited(syncCycleTrigger?.call())`.
- Return the event.

- [ ] **Step 3: Port existing entry_service_test tests.** In the renamed `event_store_append_test.dart`:
  - `EntryService` → `EventStore` everywhere.
  - `DeviceInfo(deviceId, softwareVersion, userId)` → construct `EventStore` with `source: Source(hopId: 'mobile-device', identifier: 'device-1', softwareVersion: '…')` AND pass `initiator: UserInitiator('user-1')` on each `append(...)`.
  - `record(entryType, aggregateId, eventType, answers)` → `append(entryType, aggregateId, aggregateType: 'DiaryEntry', eventType, data: {'answers': answers}, initiator: UserInitiator('user-1'), dedupeByContent: true)`. The old `answers:` sugar is gone.
  - Update expectations: drop expectations on `event.userId`, `event.deviceId`; add expectations on `event.initiator`, `event.flowToken`.
  - The test fixture now also needs a `SembastSecurityContextStore` and an `InternalSecurityContextStore` cast — provide this via `EventStore`'s constructor param. Register `DiaryEntriesMaterializer()` on the fixture so happy-path folds still happen.
  - Auto-register an `EntryTypeDefinition('epistaxis_event', …, materialize: true)` in the registry.

- [ ] **Step 4: Add new tests for the REQ-EVENTSTORE contract.**

```dart
    test('REQ-EVENTSTORE-B: append returns the persisted StoredEvent with '
        'initiator round-tripped', () async {
      final fx = await _setupFixture();
      final ev = await fx.service.append(
        entryType: 'epistaxis_event',
        aggregateId: 'a',
        aggregateType: 'DiaryEntry',
        eventType: 'finalized',
        data: const {'answers': {'severity': 'mild'}},
        initiator: const UserInitiator('u1'),
      );
      expect(ev, isNotNull);
      expect(ev!.initiator, const UserInitiator('u1'));
    });

    test('REQ-SECCTX-C: happy path with security writes both rows atomically',
        () async {
      final fx = await _setupFixture();
      final ev = await fx.service.append(
        entryType: 'epistaxis_event',
        aggregateId: 'a',
        aggregateType: 'DiaryEntry',
        eventType: 'finalized',
        data: const {'answers': {}},
        initiator: const UserInitiator('u1'),
        security: const SecurityDetails(ipAddress: '203.0.113.7'),
      );
      final row = await fx.securityContexts.read(ev!.eventId);
      expect(row, isNotNull);
      expect(row!.ipAddress, '203.0.113.7');
    });

    test('REQ-SECCTX-C: atomicity — materializer throws, neither event nor '
        'security row persisted', () async { /* use a throwing Materializer
        spy; assert findAllEvents empty, store.read empty */ });

    test('REQ-MATERIALIZERS-C: def.materialize=false skips materializers',
        () async { /* register an entryType with materialize:false; append;
        assert no view row was written but event row present */ });

    test('REQ-FLOWTOKEN-A: flowToken persists through append', () async { /* */ });

    test('REQ-FLOWTOKEN-E: flow_token is part of event_hash input (changing '
        'flow_token changes hash)', () async { /* compute two events with
        identical inputs except flowToken; assert different eventHash */ });
```

- [ ] **Step 5: Run tests. Expect many passes, some may still be red** on cross-cutting test files (rebuild_test, bootstrap_test) — those land in later tasks. Goal here: `test/event_store_append_test.dart` is all green.

- [ ] **Step 6: Commit.**

```bash
git add apps/common-dart/append_only_datastore/lib/src/event_store.dart \
        apps/common-dart/append_only_datastore/test/event_store_append_test.dart
git commit -m "[CUR-1154] Phase 4.4 Task 17: EventStore rename + new append signature"
```

---

### Task 18: `EventStore.clearSecurityContext` + `applyRetentionPolicy`

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/event_store.dart`
- Create: `apps/common-dart/append_only_datastore/test/security/clear_security_context_emits_event_test.dart`
- Create: `apps/common-dart/append_only_datastore/test/security/apply_retention_emits_events_test.dart`

- [ ] **Step 1: Write failing tests.** Sketch (see design §5.2 and §5.3 for full flow):
  - `clearSecurityContext` happy path: security row deleted; event with entryType=`security_context_redacted`, aggregateType=`security_context`, aggregateId=eventId, initiator=redactedBy, data={'reason': 'GDPR request'} present in event_log.
  - Missing eventId: `ArgumentError`; no rows touched; no event emitted.
  - The redaction event is NOT materialized (def.materialize=false).
  - Sync trigger fires after redaction.
  - `applyRetentionPolicy`:
  - Empty sweep: no events; RetentionResult zero-zero.
  - Compact-only: 1 event with entryType=`security_context_compacted`, data.count correct, data.cutoff ISO.
  - Compact+purge: 2 events.
  - Throw during sweep: transaction rolls back; no row changed.
  - Return `RetentionResult(compactedCount, purgedCount)`.

- [ ] **Step 2: Implement `clearSecurityContext` and `applyRetentionPolicy`.** In `event_store.dart`, follow design §5.2 and §5.3 exactly. Add a top-level `class RetentionResult { final int compactedCount; final int purgedCount; }`.

  Notable detail: the recursive `append(...)` inside `clearSecurityContext` runs inside the SAME transaction that deleted the security row. Dart does not allow opening a nested transaction in Sembast; instead, factor out a private `_appendInTxn(txn, …)` that does all of `append`'s body without opening its own transaction and without firing the sync trigger, and have the public `append(...)` wrap it in `backend.transaction(...)` + sync trigger firing. `clearSecurityContext` uses `_appendInTxn(...)` inside its own transaction and fires sync trigger after commit.

  Apply the same refactor for `applyRetentionPolicy`: single backend.transaction body; multiple `_appendInTxn` calls for the compact/purge audit events inside it; one sync trigger fired post-commit.

- [ ] **Step 3: Implement policy truncation.** On `EventSecurityContext`, add:

```dart
EventSecurityContext applyTruncation(SecurityRetentionPolicy policy) { ... }
```

- Truncate IPv4 last octet when `truncateIpv4LastOctet` and `ipAddress` looks IPv4.
- Truncate IPv6 suffix to `/48` when `truncateIpv6Suffix` and IPv6.
- Drop userAgent if `dropUserAgentAfterFull`.
- Drop geoCountry/geoRegion if `dropGeoAfterFull`.

- [ ] **Step 4: Run tests; all pass. Commit.**

```bash
git add apps/common-dart/append_only_datastore/lib/src/event_store.dart \
        apps/common-dart/append_only_datastore/lib/src/security/event_security_context.dart \
        apps/common-dart/append_only_datastore/test/security
git commit -m "[CUR-1154] Phase 4.4 Task 18: clearSecurityContext + applyRetentionPolicy"
```

---

### Task 19: `bootstrapAppendOnlyDatastore` → `AppendOnlyDatastore` facade

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/bootstrap.dart`
- Modify: `apps/common-dart/append_only_datastore/test/bootstrap_test.dart`

- [ ] **Step 1: Write failing tests.** Update `test/bootstrap_test.dart` (following the existing test patterns):

```dart
    test('REQ-d00134-update: returns AppendOnlyDatastore facade with four '
        'collaborators', () async {
      final backend = await _openBackend();
      final ds = await bootstrapAppendOnlyDatastore(
        backend: backend,
        source: const Source(
            hopId: 'mobile-device', identifier: 'd', softwareVersion: 'v'),
        entryTypes: [_defn('demo_note')],
        destinations: const <Destination>[],
      );
      expect(ds.eventStore, isA<EventStore>());
      expect(ds.entryTypes.isRegistered('demo_note'), isTrue);
      expect(ds.destinations, isA<DestinationRegistry>());
      expect(ds.securityContexts, isA<SecurityContextStore>());
    });

    test('REQ-d00134-update: auto-registers 3 system entry types before '
        'caller-supplied types', () async {
      final backend = await _openBackend();
      final ds = await bootstrapAppendOnlyDatastore(
        backend: backend,
        source: const Source(
            hopId: 'mobile-device', identifier: 'd', softwareVersion: 'v'),
        entryTypes: [_defn('demo_note')],
        destinations: const <Destination>[],
      );
      expect(ds.entryTypes.isRegistered('security_context_redacted'), isTrue);
      expect(ds.entryTypes.isRegistered('security_context_compacted'), isTrue);
      expect(ds.entryTypes.isRegistered('security_context_purged'), isTrue);
    });

    test('REQ-d00134-update: caller-supplied id colliding with reserved id '
        'throws ArgumentError with "reserved"', () async {
      final backend = await _openBackend();
      await expectLater(
        bootstrapAppendOnlyDatastore(
          backend: backend,
          source: const Source(
              hopId: 'mobile-device', identifier: 'd', softwareVersion: 'v'),
          entryTypes: [_defn('security_context_redacted')],
          destinations: const <Destination>[],
        ),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message.toString(), 'message', contains('reserved'))),
      );
    });
```

- [ ] **Step 2: Rewrite `bootstrap.dart`.**
  - Define `class AppendOnlyDatastore { final EventStore eventStore; final EntryTypeRegistry entryTypes; final DestinationRegistry destinations; final SecurityContextStore securityContexts; const AppendOnlyDatastore({…}); }`.
  - Change `bootstrapAppendOnlyDatastore(...)` signature to return `Future<AppendOnlyDatastore>`; add required `Source source`; add optional `List<Materializer> materializers = const []`; add optional `SyncCycleTrigger? syncCycleTrigger`.
  - Body:
  1. Auto-register the 3 system entry types.
  2. For each caller-supplied type, if id is in `{security_context_redacted, security_context_compacted, security_context_purged}`, throw `ArgumentError` with message like `"entryType id '$id' is reserved for system events"`.
  3. Otherwise register.
  4. Build `SembastSecurityContextStore(backend: backend)`.
  5. Build `EventStore(backend, entryTypes, source, securityContexts, materializers, syncCycleTrigger)`.
  6. Iterate destinations through `DestinationRegistry.addDestination` sequentially (preserving fail-fast per REQ-d00134-D).
  7. Return `AppendOnlyDatastore(...)`.

- [ ] **Step 3: Update existing Phase 4.3 bootstrap tests** (`REQ-d00134-A+C`, `-B`, `-D`) to consume the new `AppendOnlyDatastore` return, not the 2-tuple. Pass the new required `source:` param.

- [ ] **Step 4: Run tests; all pass. Commit.**

```bash
git add apps/common-dart/append_only_datastore/lib/src/bootstrap.dart \
        apps/common-dart/append_only_datastore/test/bootstrap_test.dart
git commit -m "[CUR-1154] Phase 4.4 Task 19: AppendOnlyDatastore facade + system entry type auto-registration"
```

---

### Task 20: `EventRepository` drive-by patch

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/src/infrastructure/repositories/event_repository.dart`
- Modify: `apps/common-dart/append_only_datastore/test/event_repository_test.dart`

`EventRepository` is the legacy write path still used by `NosebleedService` in `clinical_diary`. Keep the external API (`append(..., userId: String, deviceId: String, ...)`) stable so `NosebleedService` stays untouched until Phase 5; wrap the `userId` internally into a `UserInitiator` and stamp `metadata.provenance[0]` from `deviceId`.

- [ ] **Step 1: Update `EventRepository.append` body.**
  - Construct `final initiator = UserInitiator(userId);`.
  - Replace `'user_id': userId` in `eventRecord` with `'initiator': initiator.toJson()`.
  - Replace `'device_id': deviceId` + absent provenance with:
  ```dart
  final provenance0 = ProvenanceEntry(
   hop: 'mobile-device',
   receivedAt: clientTs,
   identifier: deviceId,
   softwareVersion: '',  // legacy path has no software_version input
  );
  // ensure metadata.provenance exists
  final effectiveMetadata = <String, Object?>{
   ...?metadata,
   'provenance': <Map<String, Object?>>[provenance0.toJson()],
  };
  eventRecord['metadata'] = effectiveMetadata;
  ```
  - Add `'flow_token': null` to eventRecord.
  - Update `_calculateEventHash`: hashInput becomes `{event_id, aggregate_id, entry_type, event_type, sequence_number, data, initiator, flow_token, client_timestamp, previous_event_hash, metadata}`.

- [ ] **Step 2: Update test expectations.** In `test/event_repository_test.dart`:
  - Remove `expect(event.userId, ...)` and `expect(event.deviceId, ...)`.
  - Add `expect(event.initiator, const UserInitiator('user-456'))`.
  - Add `expect(event.metadata['provenance'], isA<List>())` with entry containing `identifier: 'device-789'`.

- [ ] **Step 3: Run `dart test`, `dart analyze` in `append_only_datastore`.** Expected: all green.

- [ ] **Step 4: Run clinical_diary tests** to confirm `NosebleedService` still compiles.

```bash
(cd apps/daily-diary/clinical_diary && flutter test && flutter analyze)
```

- [ ] **Step 5: Commit.**

```bash
git add apps/common-dart/append_only_datastore/lib/src/infrastructure/repositories/event_repository.dart \
        apps/common-dart/append_only_datastore/test/event_repository_test.dart
git commit -m "[CUR-1154] Phase 4.4 Task 20: EventRepository drive-by — initiator + provenance"
```

---

### Task 21: Library barrel + `rebuild` export updates

**Files:**
- Modify: `apps/common-dart/append_only_datastore/lib/append_only_datastore.dart`

- [ ] **Step 1: Edit the public exports.**
  - Remove: `export 'src/entry_service.dart' show DeviceInfo, EntryService, SyncCycleTrigger;`.
  - Add: `export 'src/event_store.dart' show EventStore, RetentionResult, SyncCycleTrigger;`.
  - Add: `export 'src/storage/initiator.dart' show Initiator, UserInitiator, AutomationInitiator, AnonymousInitiator;`.
  - Add: `export 'src/storage/source.dart' show Source;`.
  - Add: `export 'src/security/event_security_context.dart' show EventSecurityContext;`.
  - Add: `export 'src/security/security_context_store.dart' show SecurityContextStore, PagedAudit, AuditRow;`.
  - Add: `export 'src/security/security_details.dart' show SecurityDetails;`.
  - Add: `export 'src/security/security_retention_policy.dart' show SecurityRetentionPolicy;`.
  - Add: `export 'src/security/system_entry_types.dart' show kSecurityContextRedactedEntryType, kSecurityContextCompactedEntryType, kSecurityContextPurgedEntryType, kSystemEntryTypes;`.
  - Add: `export 'src/materialization/diary_entries_materializer.dart' show DiaryEntriesMaterializer;`.
  - Replace: `export 'src/materialization/materializer.dart' show Materializer;` (already present; keep).
  - Replace: `export 'src/materialization/rebuild.dart' show rebuildMaterializedView;` with `show rebuildView;`.
  - Update the top-of-file doc comment example code to pass `initiator: UserInitiator('user-456')` and drop `userId: 'user-456'`/`deviceId: 'device-789'`.

- [ ] **Step 2: Edit `bootstrap.dart` export.** Ensure the library barrel exports `bootstrapAppendOnlyDatastore` AND `AppendOnlyDatastore`.

- [ ] **Step 3: Run full library tests and analyze.**

```bash
(cd apps/common-dart/append_only_datastore && dart test && dart analyze)
```

- [ ] **Step 4: Commit.**

```bash
git add apps/common-dart/append_only_datastore/lib/append_only_datastore.dart
git commit -m "[CUR-1154] Phase 4.4 Task 21: library barrel exports for Phase 4.4 public surfaces"
```

---

### Task 22: Phase 4.4 full-suite verification

**Files:** none (verification only)

- [ ] **Step 1: Run all library test suites.**

```bash
(cd apps/common-dart/provenance && dart test && dart analyze)
(cd apps/common-dart/trial_data_types && dart test && dart analyze)
(cd apps/common-dart/append_only_datastore && dart test && dart analyze)
(cd apps/daily-diary/clinical_diary && flutter test && flutter analyze)
```

Expected: all green, zero analyze issues.

- [ ] **Step 2: Run spec-compliance validation.**

```bash
(cd tools/requirements && python -m requirements.validate_all)
```

Expected: no errors; 8 new REQs + two updated REQs present.

- [ ] **Step 3: Phase-squash prep.** Per the per-phase workflow in `PHASE_4.4_WORKLOG.md`: this phase's commit history will squash into one commit at PR merge time. Confirm the branch is rebased onto origin/main with no extraneous commits:

```bash
git fetch origin main
git log --oneline origin/main..HEAD
```

- [ ] **Step 4: Final WORKLOG entry.** Append a summary section to `PHASE_4.4_WORKLOG.md` listing: final test counts, all tasks completed, any carry-overs to Phase 4.5 / 4.6.

- [ ] **Step 5: Commit WORKLOG if edited.**

```bash
git add PHASE_4.4_WORKLOG.md
git commit -m "[CUR-1154] Phase 4.4 Task 22: full-suite verification + phase-squash prep"
```

---

## Self-review

1. **Spec coverage:** every REQ topic in Task 3's list maps to at least one implementation task (Tasks 4-20) and at least one test. Updates to REQ-d00120 and REQ-d00134 are covered by Tasks 6 (hash spec) and 19 (bootstrap facade).

2. **Placeholders:** search for "TBD", "TODO", "later" — none found. The one explicit "note in WORKLOG" in Task 8/10 is an intentional documentation step, not a work placeholder.

3. **Type consistency:** `EventStore.append` in Task 17, `EventStore.clearSecurityContext` / `applyRetentionPolicy` in Task 18, and `AppendOnlyDatastore` in Task 19 all match the design doc §4.5, §4.7, §4.10. `Initiator` signatures match across all references.

4. **Carry-forward items:** `EntryRepository` stays alive (Phase 5 deletes); `clinical_diary` untouched; rebuild API renamed but semantics preserved.

## Execution handoff

Inline execution via executing-plans (per-task controller workflow). Each task commits; after every task the controller workflow in `PHASE_4.4_WORKLOG.md` runs the review sub-agent and logs addressed / dismissed feedback.
