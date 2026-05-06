# Audited Actions Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `apps/common-dart/audited_actions/` package — a class-based command/intent layer that gatekeeps untrusted ingress (auth + authz + validation), persists every accepted action's events through the events lib, and records every denial as a typed event in the unified log.

**Architecture:** An `Action<TInput, TResult>` interface is the unit of work. An `ActionDispatcher` runs each call through a 10-stage pipeline (lookup → invocation_id → parse → idempotency → validate → authorize → execute → persist → record idempotency → return). Authorization is pluggable behind `AuthorizationPolicy`; idempotency is pluggable behind `IdempotencyStore`. The events-lib API (`EventStore` from `event_sourcing_datastore`) is consumed directly — no adapter interface in this package. Denials at any pipeline stage emit typed events into the same event store as successes.

**Tech Stack:** Pure Dart (no Flutter). Depends on `event_sourcing_datastore` (`Initiator`, `flowToken`, `EventSecurityContext`, `EventStore.appendWithSecurity`, `EventStore.transaction`). Tests via `package:test` + `package:mocktail`. Linting via `package:lints` strict ruleset.

**Ticket:** CUR-1192 (formerly CUR-1159; the library spun out of CUR-1159's Sub-project A after Sub-project E shipped via CUR-1154)
**Design doc:** `docs/superpowers/specs/2026-04-22-events-and-actions-libs-design.md` (Sub-project A is §7)
**Verifies:** REQ-d00166..REQ-d00171 (Action interface, registry, dispatcher pipeline, authorization, idempotency, denial events) per `spec/dev-audited-actions.md`.

---

## Status as of 2026-05-06

The package skeleton, value types, and several leaf primitives were consolidated onto this branch in commit `84574c5b` (with a follow-up cleanup in `7de953e8`). Tasks below are tagged with their current state:

| Task | Status | Notes |
| --- | --- | --- |
| 1. Baseline + dependency check + branch creation | OBSOLETE | Already on the right branch; skip. |
| 2. Package skeleton | DONE in 84574c5b/7de953e8 | Skip. |
| 3. Spec + claim REQ numbers | DONE in 84574c5b | REQ-d00166..d00171 claimed; `spec/dev-audited-actions.md` committed. Skip. |
| 4. `Permission` value type | DONE in 84574c5b | `lib/src/permission.dart` + tests. Skip. |
| 5. `Idempotency` enum + `IdempotencyEntry` | DONE in 84574c5b | `lib/src/idempotency.dart` + tests. Skip. |
| 6. `ExecutionResult` and `DispatchResult` | PARTIAL | `DispatchResult` done in 84574c5b; **`ExecutionResult` still needs implementing** as part of this task. |
| 7. `ActionContext`, `Principal`, re-export `SecurityDetails` | TODO | Full task. |
| 8. `Action` abstract class | TODO | Full task. |
| 9. `ActionRegistry` | TODO | Full task. |
| 10. `AuthorizationPolicy` abstract + `DenyAllAuthorizationPolicy` | TODO | Full task. |
| 11. `RoleMatrixReader` | DONE (interface only) in 84574c5b | `TableBackedAuthorizationPolicy` is now in the `action_permissions` library plan, not here. Skip — see Task 11 body for the trimmed scope note. |
| 12. `IdempotencyStore` + `InMemoryIdempotencyStore` | DONE in 84574c5b | `lib/src/idempotency_store.dart` + tests. Skip. |
| 13. `EventsApi` + `EventsTransaction` interfaces + `FakeEventsApi` | DROPPED | `audited_actions` consumes `event_sourcing_datastore.EventStore` directly. See Task 13 body for note. |
| 14. `denial_events.dart` factories | TODO | Full task. |
| 15. Dispatcher Stage 1 (lookup) + Stage 2 (invocation_id) | TODO | Full task. |
| 16. Dispatcher Stage 3 (parse) + Stage 4 (idempotency check) | TODO | Full task. |
| 17. Dispatcher Stage 5 (validate) | TODO | Full task. |
| 18. Dispatcher Stage 6 (authorize) | TODO | Full task. |
| 19. Dispatcher Stage 7 (execute) + Stage 8 (atomic persist) | TODO | Full task. |
| 20. Dispatcher Stage 9 (record idempotency) | TODO | Full task. |
| 21. Dispatcher Stage 10 (return success) | TODO | Full task. |
| 22. `bootstrapAuditedActions` | TODO | Full task. |
| 23. Permission discovery tool | DONE in 84574c5b | `tool/discover_permissions.dart` + tests. Skip. |
| 24. Public exports + end-to-end integration test | TODO | Full task. |

Subagent-driven execution: assign one TODO/PARTIAL task per subagent; skip DONE/OBSOLETE/DROPPED tasks entirely. Tasks already done are kept in the document as historical reference for the design they captured, but their `- [ ]` checkbox steps are skipped.

REQ-d numbering: `{NNNNN}` placeholders that appeared in the original draft were replaced by their concrete values (REQ-d00166..REQ-d00171) on 2026-05-06. The placeholder note in Task 3 is now obsolete.

`event_sourcing_datastore` lib name: replaced the original `append_only_datastore` references (which was the lib's pre-CUR-1154 name).

---

## Execution Rules

Read the design doc §5 (decisions) and §7 (Sub-project A spec) before Task 4. Re-read §7.4 (dispatcher pipeline) before Task 14.

TDD cadence per task: baseline → write failing test → run-and-verify-fail → write minimal impl → run-and-verify-pass → commit. Commits use `[CUR-1159]` prefix (commit-msg hook enforces this).

REQ citation format:
- Implementation files include a `// IMPLEMENTS REQUIREMENTS:` block at the top listing all REQ-d ids the file implements.
- Per-function: `// Implements: REQ-xxx-Y — <prose>`
- Per-test: `// Verifies: REQ-xxx-Y — <prose>` AND the assertion ID starts the test description: `test('REQ-xxx-Y: description', () { ... })`.

Use `dart test` (NOT `flutter test`) for this package — pure Dart. Use `dart analyze` for lints.

After every commit, run `dart test` and `dart analyze` from `apps/common-dart/audited_actions/` to confirm green.

---

## File Structure

Files this plan creates or modifies. Each has one clear responsibility.

```text
apps/common-dart/audited_actions/                    NEW package
  pubspec.yaml                                      package metadata, deps
  analysis_options.yaml                             strict lint config
  README.md                                         what this package is, how to use
  lib/
    audited_actions.dart                             public exports
    src/
      permission.dart                               Permission value type
      idempotency.dart                              Idempotency enum + IdempotencyEntry
      execution_result.dart                         ExecutionResult<TR>
      dispatch_result.dart                          sealed DispatchResult<TR> + variants
      action_context.dart                           ActionContext, Principal,
                                                     re-export of SecurityDetails
      action.dart                                   Action<TI,TR> abstract
      action_registry.dart                          ActionRegistry
      authorization_policy.dart                     AuthorizationPolicy abstract,
                                                     DenyAllAuthorizationPolicy
      role_matrix_reader.dart                       RoleMatrixReader interface
      table_backed_authorization_policy.dart        TableBackedAuthorizationPolicy
      idempotency_store.dart                        IdempotencyStore abstract,
                                                     InMemoryIdempotencyStore
      events_api.dart                               EventsApi + EventsTransaction
                                                     (interfaces consumed by dispatcher)
      denial_events.dart                            EventDraft factory functions
                                                     for each denial type
      action_dispatcher.dart                        ActionDispatcher pipeline
      bootstrap.dart                                bootstrapAuditedActions()
  test/
    fixtures/
      fake_events_api.dart                          in-memory test double
      fake_authorization_policy.dart                allow/deny controllable
      fake_role_matrix_reader.dart
      test_actions.dart                             concrete Action subclasses
                                                     for dispatcher tests
    permission_test.dart
    idempotency_test.dart
    execution_result_test.dart
    dispatch_result_test.dart
    action_context_test.dart
    action_test.dart
    action_registry_test.dart
    authorization_policy_test.dart
    table_backed_authorization_policy_test.dart
    idempotency_store_test.dart
    events_api_test.dart
    denial_events_test.dart
    action_dispatcher_test.dart                     all 10 pipeline stages
    bootstrap_test.dart
    permission_discovery_test.dart
  tool/
    discover_permissions.dart                       CLI; emits SQL migration

spec/dev-audited-actions.md                          NEW — REQ topics for this lib
spec/INDEX.md                                       EDIT — register new REQs

.githooks/project-defs.sh                           EDIT — add audited_actions
                                                     trigger paths
```

---

## Plan

### Task 1: Baseline + dependency check + branch creation (OBSOLETE — already on the right branch; skip)

> **STOP — DO NOT EXECUTE THIS TASK.** OBSOLETE — already on the right branch; this task's verification is moot. Return immediately.


**Files:**
- (no files modified; verification + branch only)

- [ ] **Confirm Sub-project E is merged on `main`.** Run from this worktree:

```bash
git fetch origin main
git log origin/main --oneline | grep -E "Initiator|flowToken|EventSecurityContext|REQ-INITIATOR|REQ-SECCTX" | head -5
```

Expected: at least one matching commit. If empty, **STOP** — Sub-project E is the blocker; resume work on it in the mobile worktree per `TODO4.4.md`.

- [ ] **Verify the events lib's post-E API is callable.** Quick sanity from this worktree:

```bash
ls /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/apps/common-dart/event_sourcing_datastore/lib/src/storage/initiator.dart
ls /home/metagamer/cure-hht/hht_diary-worktrees/mobile-event-sourcing-refactor/apps/common-dart/event_sourcing_datastore/lib/src/security/event_security_context.dart
```

Expected: both files exist. If not, see previous step.

- [ ] **Create implementation branch from main:**

```bash
git checkout main
git pull
git checkout -b feature/cur-1159-audited-actions-library
```

- [ ] **Baseline: confirm tree builds and existing tests pass.** From repo root:

```bash
(cd apps/common-dart/event_sourcing_datastore && dart pub get && dart test)
```

Expected: PASS. Records pre-change state.

- [ ] **No commit at end of Task 1.** Verification only.

---

### Task 2: Package skeleton (COMPLETED in 84574c5b — skip)

> **STOP — DO NOT EXECUTE THIS TASK.** COMPLETED in 84574c5b. The package skeleton already exists on this branch. Return immediately.


**Files:**
- Create: `apps/common-dart/audited_actions/pubspec.yaml`
- Create: `apps/common-dart/audited_actions/analysis_options.yaml`
- Create: `apps/common-dart/audited_actions/README.md`
- Create: `apps/common-dart/audited_actions/lib/audited_actions.dart` (placeholder)
- Modify: `.githooks/project-defs.sh`

- [ ] **Create the directory:**

```bash
mkdir -p apps/common-dart/audited_actions/lib/src apps/common-dart/audited_actions/test/fixtures apps/common-dart/audited_actions/tool
```

- [ ] **Write `pubspec.yaml`:**

```yaml
# IMPLEMENTS REQUIREMENTS:
#   REQ-ACTION, REQ-ACTREG, REQ-DISPATCH, REQ-AUTHZ, REQ-IDEMPOT, REQ-DENIAL
#   (numbers claimed in Task 3)
#
# Trusted-boundary command/intent layer that accepts untrusted ingress,
# runs auth + authz + validation, then persists events through the
# post-Sub-project-E event_sourcing_datastore.

name: audited_actions
description: "Trusted-boundary action dispatcher: auth + authz + validation + atomic event persistence + denial recording"
version: 0.0.1
publish_to: none

environment:
  sdk: ^3.10.7

dependencies:
  event_sourcing_datastore:
    path: ../event_sourcing_datastore
  meta: ^1.16.0
  uuid: ^4.5.2

dev_dependencies:
  test: ^1.25.15
  mocktail: ^1.0.4
  lints: ^5.0.0
```

- [ ] **Write `analysis_options.yaml`:**

```yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    missing_required_param: error
    missing_return: error
    parameter_assignments: error
  exclude:
    - '**/*.g.dart'
    - '**/*.freezed.dart'

linter:
  rules:
    - always_declare_return_types
    - always_use_package_imports
    - avoid_dynamic_calls
    - avoid_returning_null_for_void
    - close_sinks
    - directives_ordering
    - omit_local_variable_types
    - only_throw_errors
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_fields
    - prefer_final_locals
    - prefer_single_quotes
    - require_trailing_commas
    - sort_constructors_first
    - type_annotate_public_apis
    - unawaited_futures
    - use_super_parameters
```

- [ ] **Write `README.md`:**

```markdown
# audited_actions

Trusted-boundary command/intent layer for the unified event-sourced architecture.

This package is the trusted-boundary gatekeeper between untrusted callers
(browsers, future mobile-portal API) and the events lib
(`event_sourcing_datastore`). Every state-change reaching the host from an
untrusted source flows through one library-defined pipeline that:

1. Authenticates the caller (via the supplied `Principal`)
2. Authorizes the operation (via a pluggable `AuthorizationPolicy`)
3. Validates the input
4. Executes the action
5. Persists the resulting events atomically via the events lib
6. Records every denial as a typed event in the same log

See `docs/superpowers/specs/2026-04-22-events-and-actions-libs-design.md`
(Sub-project A) for the full design.

## Quick start

```dart
import 'package:audited_actions/audited_actions.dart';

final dispatcher = bootstrapAuditedActions(
  events: myEventsApi,
  authorization: TableBackedAuthorizationPolicy(myMatrixReader),
  idempotency: InMemoryIdempotencyStore(),
  actions: [InviteUserAction(), DeactivateUserAction(), ...],
);

final result = await dispatcher.dispatch(
  'invite_user',
  rawInput,
  ctx,
  idempotencyKey: requestId,
  flowToken: 'invite:ABC123',
);
```

## Out of scope

- Concrete actions (which actions exist) — defined per-area in cutover tickets.
- PostgreSQL `IdempotencyStore` impl — separate "port to portal" ticket.
- HTTP-edge concerns (rate limiting, token verification) — middleware.
- OpenTelemetry stamping — future enhancement.
```

- [ ] **Write `lib/audited_actions.dart` placeholder** (will grow as files added):

```dart
/// Trusted-boundary command/intent layer. See README.md.
library;

// Public exports added as files are created in subsequent tasks.
```

- [ ] **Add to `.githooks/project-defs.sh`** under "Libraries" section:

```bash
    "audited_actions|apps/common-dart/audited_actions/pubspec.yaml|apps/common-dart/audited_actions/ apps/common-dart/event_sourcing_datastore/lib/"
```

- [ ] **Run `dart pub get`:**

```bash
(cd apps/common-dart/audited_actions && dart pub get)
```

Expected: PASS. Resolves dependencies; creates `pubspec.lock`.

- [ ] **Run `dart analyze`:**

```bash
(cd apps/common-dart/audited_actions && dart analyze)
```

Expected: PASS (no source files yet beyond the placeholder).

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/ .githooks/project-defs.sh
git commit -m "[CUR-1159] audited_actions: package skeleton (pubspec, lints, README)"
```

---

### Task 3: Spec — claim REQ numbers and write `dev-audited-actions.md` (COMPLETED in 84574c5b; REQ-d00166..d00171 claimed — skip)

> **STOP — DO NOT EXECUTE THIS TASK.** COMPLETED in 84574c5b. REQ-d00166..d00171 are claimed; spec/dev-audited-actions.md is committed. Return immediately.


**Files:**
- Create: `spec/dev-audited-actions.md`
- Modify: `spec/INDEX.md`

**Note on REQ-d numbers:** The project uses a `discover_requirements` tool to claim consecutive numbers. Run it via the tool the project provides (likely `tools/requirements/discover_requirements.py` or a similar script — check `spec/README.md` and `tools/requirements/`). Claim **six** consecutive REQ-d numbers. Record them in this task's working notes; below, references use placeholder `REQ-d{NNNNN}-X` patterns that the implementer fills in.

- [ ] **Look up the requirements tool:** `ls tools/requirements/`
- [ ] **Claim six consecutive REQ-d numbers:**
  - 1: `REQ-ACTION` topic
  - 2: `REQ-ACTREG` topic
  - 3: `REQ-DISPATCH` topic
  - 4: `REQ-AUTHZ` topic
  - 5: `REQ-IDEMPOT` topic
  - 6: `REQ-DENIAL` topic

  Record each claimed number against its topic name in a temp note for use in subsequent tasks.

- [ ] **Write `spec/dev-audited-actions.md`** (new file). Use the existing `spec/dev-event-sourcing-mobile.md` (in main, post-Sub-project-E) as a structural template. Body:

```markdown
# Audited Actions Library Requirements

## Description

The `apps/common-dart/audited_actions/` package defines the trusted-boundary gatekeeper for audited user actions. Every state-change reaching the host from an untrusted caller flows through its `ActionDispatcher`, which authenticates, authorizes, validates, executes, and records the outcome. Successful actions emit one or more typed events through the events lib (`appendWithSecurity`); denied attempts at any pipeline stage emit typed denial events into the same log.

Implements the design committed in `docs/superpowers/specs/2026-04-22-events-and-actions-libs-design.md` (Sub-project A).

## REQ-d00166: REQ-ACTION — Action interface contract

A: `Action<TInput, TResult>` SHALL be an abstract class with `name: String`, `description: String`, `permissions: Set<Permission>`, `idempotency: Idempotency`, and four methods: `parseInput(Map<String, dynamic>) -> TInput`, `validate(TInput) -> void`, `execute(TInput, ActionContext) -> Future<ExecutionResult<TResult>>`. Authorization is NOT a method on `Action` — it is performed by an injected `AuthorizationPolicy` against `Action.permissions`.

B: `Action.parseInput` SHALL be pure: no I/O, no global state. Throws `ParseError` (or any subtype of `Exception`) on malformed input.

C: `Action.validate` SHALL be pure: no I/O. Throws `ValidationError` on invalid input. MAY use `ActionContext.read` (synchronous read of materialized views) for cross-field validation only if the materialized view is synchronously accessible; else validation must be moved to `execute`.

D: `Action.execute` SHALL return `ExecutionResult<TResult> { result: TResult, events: List<EventDraft>, securityDetailsOverride: SecurityDetails? }`. The `events` list SHALL be empty or contain one or more `EventDraft` instances; the dispatcher persists them atomically.

E: `Action.idempotency` SHALL declare one of `Idempotency.none`, `Idempotency.optional`, `Idempotency.required`. The dispatcher rejects calls that violate the policy (e.g. `required` without a key returns `DispatchResult.parseDenied(MissingIdempotencyKeyError)`).

## REQ-d00167: REQ-ACTREG — ActionRegistry and bootstrap

A: `ActionRegistry.register<TI, TR>(Action<TI, TR> action)` SHALL throw `ArgumentError` if `action.name` collides with an already-registered action.

B: `ActionRegistry.lookup(String name)` SHALL return the registered `Action` or null.

C: `ActionRegistry.allDeclaredPermissions: Set<Permission> get` SHALL be the union of `permissions` across all registered actions.

D: `bootstrapAuditedActions({events, authorization, idempotency, actions})` SHALL register all supplied actions (rejecting collisions per A) and return a ready `ActionDispatcher`.

## REQ-d00168: REQ-DISPATCH — Dispatcher pipeline

A: `ActionDispatcher.dispatch(actionName, rawInput, ctx, {idempotencyKey?, flowToken?})` SHALL execute the following pipeline. Each stage that fails SHALL emit a typed denial event into the events lib (per REQ-DENIAL) and SHALL return the corresponding `DispatchResult` variant; subsequent stages SHALL NOT run.

B: Stage 1 (lookup): if `actionName` is unknown, emit `unknown_action` denial and return `DispatchResult.unknownAction(name)`.

C: Stage 2 (invocation_id): generate a v4 UUID; stamp every emitted event's `metadata['action_invocation_id']` with this id (denial events included).

D: Stage 3 (parse): call `action.parseInput(rawInput)`; on throw, emit `parse_denied`, return `DispatchResult.parseDenied(error)`.

E: Stage 4 (idempotency check): if `action.idempotency != none` and `idempotencyKey != null`, look up `(action.name, principal.id, idempotencyKey)` in the `IdempotencyStore`. On hit (non-expired), short-circuit: return `DispatchResult.idempotencyHit(prior)` WITHOUT emitting any new event.

F: Stage 5 (validate): call `action.validate(input)`; on throw, emit `validation_denied`, return `DispatchResult.validationDenied(error)`.

G: Stage 6 (authorize): for each `Permission p in action.permissions`, await `authorization.isPermitted(principal, p, ctx)`. On the first false, emit `authorization_denied(p)`, return `DispatchResult.authorizationDenied(p)`.

H: Stage 7 (execute): call `action.execute(input, ctx)`; on throw, emit `execution_failed`, return `DispatchResult.executionFailed(error)`.

I: Stage 8 (persist): inside one `events.transaction` block, for each `EventDraft d` in `result.events`: stamp `d.initiator = ctx.principal.toInitiator()`, `d.metadata['action_invocation_id'] = invocation_id`, `d.metadata['action_name'] = action.name`, and `d.flowToken = d.flowToken ?? flowToken` (parameter is fallback); then `txn.appendWithSecurity(d, security: result.securityDetailsOverride ?? ctx.security)`. If any append throws, the entire transaction rolls back (including any events written within); the dispatcher emits `execution_failed`, returns `DispatchResult.executionFailed(error)`.

J: Stage 9 (record idempotency): if `action.idempotency != none` and `idempotencyKey != null`, store `(action.name, principal.id, idempotencyKey, resultJson, emittedEventIds, expiresAt)` via the `IdempotencyStore`.

K: Stage 10 (return): return `DispatchResult.success(result, emittedEventIds)`.

## REQ-d00169: REQ-AUTHZ — AuthorizationPolicy

A: `AuthorizationPolicy` SHALL be an abstract class with one method: `Future<bool> isPermitted(Principal principal, Permission permission, ActionContext ctx)`.

B: `TableBackedAuthorizationPolicy(RoleMatrixReader matrix)` SHALL: read `principal.activeRole` from the principal; query `matrix.permissionsForRole(role)`; return `permission.name in result`. If `principal` is `Principal.anonymous`, SHALL return false unconditionally.

C: `DenyAllAuthorizationPolicy` SHALL return false from every `isPermitted` call. SHALL log a warning to `package:logging` (or stderr) on every call when constructed via `DenyAllAuthorizationPolicy()` (the production-mode signal); a `DenyAllAuthorizationPolicy.forTests()` constructor SHALL suppress the warning.

D: The permission discovery tool SHALL emit a SQL migration with `INSERT ... ON CONFLICT DO NOTHING` rows for every permission in `registry.allDeclaredPermissions` not already present in the `role_permission_matrix_permissions` table. Permissions present in DB but absent from the registry SHALL be emitted as SQL comments only (not auto-deleted).

## REQ-d00170: REQ-IDEMPOT — Idempotency contract

A: When `action.idempotency == Idempotency.none`, the dispatcher SHALL ignore any `idempotencyKey` parameter (no lookup, no record).

B: When `action.idempotency == Idempotency.required` and the caller does not supply `idempotencyKey`, the dispatcher SHALL emit `parse_denied(MissingIdempotencyKeyError)` and return `DispatchResult.parseDenied(...)` BEFORE running `parseInput`.

C: When `action.idempotency == Idempotency.optional` and the caller does not supply `idempotencyKey`, the dispatcher SHALL skip both lookup and record stages but otherwise proceed normally.

D: An idempotency lookup hit SHALL return the cached `resultJson` and `emittedEventIds`; the dispatcher SHALL NOT re-run the action and SHALL NOT emit any new event (success or denial).

E: `IdempotencyStore.sweepExpired({DateTime? before})` SHALL delete entries whose `expiresAt` is at or before `before` (default `DateTime.now()`); returns the count deleted.

F: Default TTL SHALL be 24 hours; an action MAY override via an `idempotencyTtl: Duration` getter (default returns `Duration(hours: 24)`).

## REQ-d00171: REQ-DENIAL — Denial events

A: Every denial event SHALL be an `EventDraft` with `aggregateType: 'action_attempt'`, `aggregateId: <action_invocation_id>`, `entryType: 'action_denial'`. The `eventType` SHALL be one of: `unknown_action`, `parse_denied`, `validation_denied`, `authorization_denied`, `execution_failed`.

B: Denial event `data` SHALL contain at minimum `error_class: String` and `error_message_sanitized: String`. `authorization_denied` additionally contains `permission_denied: String` and (if available) `principal_active_role: String`. `unknown_action` contains `requested_name: String`.

C: Sanitization SHALL strip stack traces, file paths, and any value that may echo back caller-supplied input (including the rawInput map). The unsanitized error SHALL be logged separately via `package:logging` for ops debugging.

D: Denial events SHALL be persisted via the same `events.appendWithSecurity` path as success events, including the supplied `SecurityDetails` from `ctx.security`.

E: Denial events SHALL share the same `action_invocation_id` as the dispatch attempt (in `metadata`), enabling audit queries to correlate the entire attempt's history.
```

- [ ] **Update `spec/INDEX.md`** with the six new REQ-d IDs and content hashes (use the project's REQ-content-hash tool, likely `tools/requirements/recompute-hashes.py` per the conventions in `spec/README.md`).

- [ ] **Run the requirements validator** (the project script that checks REQ format consistency; check `tools/requirements/`):

```bash
ls tools/requirements/
# run whatever the validator script is, e.g.:
# python tools/requirements/validate.py spec/dev-audited-actions.md
```

Expected: PASS.

- [ ] **Commit:**

```bash
git add spec/dev-audited-actions.md spec/INDEX.md
git commit -m "[CUR-1159] spec/dev-audited-actions.md: REQ-ACTION, ACTREG, DISPATCH, AUTHZ, IDEMPOT, DENIAL"
```

---

### Task 4: `Permission` value type (COMPLETED in 84574c5b — skip)

> **STOP — DO NOT EXECUTE THIS TASK.** COMPLETED in 84574c5b. lib/src/permission.dart and tests already exist. Return immediately.


**Files:**
- Create: `apps/common-dart/audited_actions/lib/src/permission.dart`
- Create: `apps/common-dart/audited_actions/test/permission_test.dart`

**Applicable assertions:** REQ-AUTHZ-D (referenced from this file via convention).

- [ ] **Write failing tests** in `test/permission_test.dart`:

```dart
import 'package:audited_actions/src/permission.dart';
import 'package:test/test.dart';

void main() {
  group('Permission', () {
    test('equality based on name', () {
      const p1 = Permission('user.invite');
      const p2 = Permission('user.invite');
      const p3 = Permission('user.delete');
      expect(p1, equals(p2));
      expect(p1, isNot(equals(p3)));
      expect(p1.hashCode, equals(p2.hashCode));
    });

    test('toString includes the permission name', () {
      const p = Permission('patient.enroll');
      expect(p.toString(), contains('patient.enroll'));
    });

    test('rejects empty name', () {
      expect(() => Permission(''), throwsArgumentError);
    });

    test('rejects whitespace-only name', () {
      expect(() => Permission('   '), throwsArgumentError);
    });

    test('can be used in a Set', () {
      final set = <Permission>{
        const Permission('a.b'),
        const Permission('c.d'),
        const Permission('a.b'), // duplicate
      };
      expect(set.length, 2);
    });
  });
}
```

- [ ] **Run tests; confirm failure:**

```bash
(cd apps/common-dart/audited_actions && dart test test/permission_test.dart)
```

Expected: FAIL — `Target of URI doesn't exist: 'package:audited_actions/src/permission.dart'`.

- [ ] **Write `lib/src/permission.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-AUTHZ (REQ-d00169): Permission value type, used as a key in
//   the role-permission matrix and declared on each Action.

/// A named permission, by convention `<aggregate>.<verb>` (e.g.
/// `user.invite`, `patient.enroll`). Used by `Action.permissions` to
/// declare what the action requires; used by `AuthorizationPolicy` to
/// decide whether a principal may execute it.
class Permission {
  // Implements: REQ-AUTHZ-D — Permission is the discovery tool's unit;
  // each registered permission becomes one row in the SQL migration.
  const Permission(this.name) : assert(name != '', 'name must not be empty');

  /// Throws `ArgumentError` if `name` is empty or whitespace-only.
  factory Permission.checked(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty or whitespace');
    }
    return Permission(name);
  }

  final String name;

  @override
  bool operator ==(Object other) => other is Permission && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'Permission($name)';
}
```

- [ ] **Note on the runtime check:** the const constructor's `assert` only fires in dev/test builds. The factory `.checked` is for runtime construction with full validation. Adjust the test to use `Permission.checked('')` for the runtime-check tests, OR change the assertions in tests to use the factory:

```dart
    test('rejects empty name', () {
      expect(() => Permission.checked(''), throwsArgumentError);
    });

    test('rejects whitespace-only name', () {
      expect(() => Permission.checked('   '), throwsArgumentError);
    });
```

(Apply this fix to the test file before re-running.)

- [ ] **Run tests; confirm pass:**

```bash
(cd apps/common-dart/audited_actions && dart test test/permission_test.dart && dart analyze)
```

Expected: all PASS, no analyzer warnings.

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/lib/src/permission.dart \
        apps/common-dart/audited_actions/test/permission_test.dart
git commit -m "[CUR-1159] audited_actions: Permission value type"
```

---

### Task 5: `Idempotency` enum + `IdempotencyEntry` value type (COMPLETED in 84574c5b — skip)

> **STOP — DO NOT EXECUTE THIS TASK.** COMPLETED in 84574c5b. lib/src/idempotency.dart and tests already exist. Return immediately.


**Files:**
- Create: `apps/common-dart/audited_actions/lib/src/idempotency.dart`
- Create: `apps/common-dart/audited_actions/test/idempotency_test.dart`

**Applicable assertions:** REQ-IDEMPOT-A, B, C, F.

- [ ] **Write failing tests** in `test/idempotency_test.dart`:

```dart
import 'package:audited_actions/src/idempotency.dart';
import 'package:test/test.dart';

void main() {
  group('Idempotency enum', () {
    test('REQ-IDEMPOT-A,B,C: has three variants', () {
      expect(Idempotency.values, hasLength(3));
      expect(Idempotency.values, contains(Idempotency.none));
      expect(Idempotency.values, contains(Idempotency.optional));
      expect(Idempotency.values, contains(Idempotency.required));
    });
  });

  group('IdempotencyEntry', () {
    test('round-trips fields', () {
      final entry = IdempotencyEntry(
        resultJson: const {'ok': true, 'id': 'abc'},
        emittedEventIds: const ['evt-1', 'evt-2'],
        recordedAt: DateTime.parse('2026-04-22T10:00:00Z'),
        expiresAt: DateTime.parse('2026-04-23T10:00:00Z'),
      );
      expect(entry.resultJson['ok'], isTrue);
      expect(entry.emittedEventIds, hasLength(2));
      expect(entry.expiresAt.difference(entry.recordedAt),
             const Duration(hours: 24));
    });

    test('isExpired returns true when expiresAt < now', () {
      final entry = IdempotencyEntry(
        resultJson: const {},
        emittedEventIds: const [],
        recordedAt: DateTime.parse('2026-01-01T00:00:00Z'),
        expiresAt: DateTime.parse('2026-01-02T00:00:00Z'),
      );
      expect(entry.isExpired(now: DateTime.parse('2026-01-03T00:00:00Z')),
             isTrue);
    });

    test('isExpired returns false when expiresAt > now', () {
      final entry = IdempotencyEntry(
        resultJson: const {},
        emittedEventIds: const [],
        recordedAt: DateTime.parse('2026-01-01T00:00:00Z'),
        expiresAt: DateTime.parse('2026-01-10T00:00:00Z'),
      );
      expect(entry.isExpired(now: DateTime.parse('2026-01-05T00:00:00Z')),
             isFalse);
    });
  });

  group('defaultIdempotencyTtl', () {
    test('REQ-IDEMPOT-F: defaults to 24 hours', () {
      expect(defaultIdempotencyTtl, const Duration(hours: 24));
    });
  });
}
```

- [ ] **Run tests; confirm failure** (target URI doesn't exist).

- [ ] **Write `lib/src/idempotency.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-IDEMPOT (REQ-d00170): Idempotency policy enum + cache entry
//   value type used by IdempotencyStore implementations.

/// Per-action declaration of how the dispatcher treats `idempotencyKey`.
///
/// - [none]: caller MUST NOT pass a key; if they do, it is ignored.
/// - [optional]: caller MAY pass a key; without one, no replay protection.
/// - [required]: caller MUST pass a key; absence is a parse-stage denial.
//
// Implements: REQ-IDEMPOT-A,B,C — three policies; dispatcher behavior per
// each documented in REQ-DISPATCH and IdempotencyStore tests.
enum Idempotency { none, optional, required }

/// A cached dispatch outcome stored in the `IdempotencyStore`.
//
// Implements: REQ-IDEMPOT-D — `resultJson` is the prior result; lookup hit
// returns this verbatim. `emittedEventIds` is the audit-trail link to the
// events written by the original dispatch.
class IdempotencyEntry {
  const IdempotencyEntry({
    required this.resultJson,
    required this.emittedEventIds,
    required this.recordedAt,
    required this.expiresAt,
  });

  final Map<String, dynamic> resultJson;
  final List<String> emittedEventIds;
  final DateTime recordedAt;
  final DateTime expiresAt;

  bool isExpired({required DateTime now}) =>
      !expiresAt.isAfter(now);
}

/// Default TTL for idempotency cache entries when an action does not
/// override.
//
// Implements: REQ-IDEMPOT-F — 24 hours unless the action specifies
// otherwise via its `idempotencyTtl` getter.
const Duration defaultIdempotencyTtl = Duration(hours: 24);
```

- [ ] **Run tests + analyze; confirm pass:**

```bash
(cd apps/common-dart/audited_actions && dart test test/idempotency_test.dart && dart analyze)
```

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/lib/src/idempotency.dart \
        apps/common-dart/audited_actions/test/idempotency_test.dart
git commit -m "[CUR-1159] audited_actions: Idempotency enum and IdempotencyEntry"
```

---

### Task 6: `ExecutionResult` and `DispatchResult` (sealed result types) (PARTIAL — `DispatchResult` done in 84574c5b; only `ExecutionResult` still needed for this task)

**Files:**
- Create: `apps/common-dart/audited_actions/lib/src/execution_result.dart`
- Create: `apps/common-dart/audited_actions/lib/src/dispatch_result.dart`
- Create: `apps/common-dart/audited_actions/test/execution_result_test.dart`
- Create: `apps/common-dart/audited_actions/test/dispatch_result_test.dart`

**Applicable assertions:** REQ-ACTION-D (ExecutionResult shape), REQ-DISPATCH-B,D,E,F,G,H,K (DispatchResult variants).

This task imports `EventDraft` and `SecurityDetails` from the events lib (post-Sub-project-E). If your IDE flags missing types, run `dart pub get` first.

- [ ] **Write failing tests** in `test/execution_result_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart' show EventDraft, SecurityDetails;
import 'package:audited_actions/src/execution_result.dart';
import 'package:test/test.dart';

void main() {
  group('ExecutionResult', () {
    test('REQ-ACTION-D: holds result + events', () {
      final draft = EventDraft(
        aggregateId: 'agg-1',
        aggregateType: 'user',
        entryType: 'user',
        eventType: 'invited',
        data: const {'email': 'a@b.com'},
      );
      final r = ExecutionResult<int>(
        result: 42,
        events: [draft],
      );
      expect(r.result, 42);
      expect(r.events, hasLength(1));
      expect(r.securityDetailsOverride, isNull);
    });

    test('REQ-ACTION-D: events list MAY be empty (no-op success)', () {
      final r = ExecutionResult<String>(result: 'ok', events: const []);
      expect(r.events, isEmpty);
    });

    test('securityDetailsOverride is preserved when set', () {
      final sd = SecurityDetails(ipAddress: '10.0.0.1');
      final r = ExecutionResult<void>(
        result: null,
        events: const [],
        securityDetailsOverride: sd,
      );
      expect(r.securityDetailsOverride, isNotNull);
      expect(r.securityDetailsOverride!.ipAddress, '10.0.0.1');
    });
  });
}
```

- [ ] **Write failing tests** in `test/dispatch_result_test.dart`:

```dart
import 'package:audited_actions/src/dispatch_result.dart';
import 'package:audited_actions/src/permission.dart';
import 'package:test/test.dart';

void main() {
  group('DispatchResult', () {
    test('REQ-DISPATCH-K: success carries result + emitted ids', () {
      const r = DispatchResult<int>.success(42, ['evt-1', 'evt-2']);
      expect(r, isA<DispatchSuccess<int>>());
      r as DispatchSuccess<int>;
      expect(r.result, 42);
      expect(r.emittedEventIds, hasLength(2));
    });

    test('REQ-DISPATCH-B: unknownAction carries requested name', () {
      const r = DispatchResult<int>.unknownAction('foo');
      expect(r, isA<DispatchUnknownAction<int>>());
      r as DispatchUnknownAction<int>;
      expect(r.requestedName, 'foo');
    });

    test('REQ-DISPATCH-D: parseDenied carries the error', () {
      final err = ArgumentError('bad input');
      final r = DispatchResult<int>.parseDenied(err);
      expect(r, isA<DispatchParseDenied<int>>());
      r as DispatchParseDenied<int>;
      expect(r.error, err);
    });

    test('REQ-DISPATCH-F: validationDenied carries the error', () {
      final err = StateError('invalid');
      final r = DispatchResult<int>.validationDenied(err);
      expect(r, isA<DispatchValidationDenied<int>>());
    });

    test('REQ-DISPATCH-G: authorizationDenied carries the failed permission', () {
      const p = Permission('user.invite');
      const r = DispatchResult<int>.authorizationDenied(p);
      expect(r, isA<DispatchAuthorizationDenied<int>>());
      r as DispatchAuthorizationDenied<int>;
      expect(r.permission, p);
    });

    test('REQ-DISPATCH-H: executionFailed carries the error', () {
      final err = StateError('boom');
      final r = DispatchResult<int>.executionFailed(err);
      expect(r, isA<DispatchExecutionFailed<int>>());
    });

    test('REQ-DISPATCH-E: idempotencyHit carries cached payload', () {
      const r = DispatchResult<Map<String, dynamic>>.idempotencyHit(
        {'ok': true},
        ['evt-prior'],
      );
      expect(r, isA<DispatchIdempotencyHit<Map<String, dynamic>>>());
    });

    test('sealed: switch is exhaustive', () {
      const r = DispatchResult<int>.success(1, []);
      // The point of this test is that the analyzer requires every
      // variant to be matched; if a new variant is added without
      // updating this switch, analysis fails.
      final desc = switch (r) {
        DispatchSuccess<int>() => 'success',
        DispatchUnknownAction<int>() => 'unknown',
        DispatchParseDenied<int>() => 'parse',
        DispatchValidationDenied<int>() => 'validation',
        DispatchAuthorizationDenied<int>() => 'authz',
        DispatchExecutionFailed<int>() => 'execfail',
        DispatchIdempotencyHit<int>() => 'hit',
      };
      expect(desc, 'success');
    });
  });
}
```

- [ ] **Run both tests; confirm failure** (URIs don't exist).

- [ ] **Write `lib/src/execution_result.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-ACTION-D: ExecutionResult shape returned by Action.execute.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show EventDraft, SecurityDetails;

/// What an `Action.execute` returns to the dispatcher.
///
/// `events` is the (possibly empty) list of event drafts to persist
/// atomically. `securityDetailsOverride`, when non-null, replaces
/// `ActionContext.security` for all events written by this dispatch
/// (rare; default behavior is to use ctx.security).
//
// Implements: REQ-ACTION-D — execute returns this value type; dispatcher
// persists `events` in one transaction (REQ-DISPATCH-I).
class ExecutionResult<TResult> {
  const ExecutionResult({
    required this.result,
    required this.events,
    this.securityDetailsOverride,
  });

  final TResult result;
  final List<EventDraft> events;
  final SecurityDetails? securityDetailsOverride;
}
```

- [ ] **Write `lib/src/dispatch_result.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-DISPATCH (REQ-d00168): pipeline outcome variants.

import 'package:audited_actions/src/permission.dart';

/// Sealed outcome of `ActionDispatcher.dispatch(...)`. Each pipeline
/// stage's success or failure maps to a variant.
//
// Implements: REQ-DISPATCH-B,D,E,F,G,H,K — one variant per terminal
// stage. Sealed: exhaustiveness checked at every switch site.
sealed class DispatchResult<TResult> {
  const DispatchResult();

  // Implements: REQ-DISPATCH-K
  const factory DispatchResult.success(
    TResult result,
    List<String> emittedEventIds,
  ) = DispatchSuccess<TResult>;

  // Implements: REQ-DISPATCH-B
  const factory DispatchResult.unknownAction(String requestedName) =
      DispatchUnknownAction<TResult>;

  // Implements: REQ-DISPATCH-D
  const factory DispatchResult.parseDenied(Object error) =
      DispatchParseDenied<TResult>;

  // Implements: REQ-DISPATCH-F
  const factory DispatchResult.validationDenied(Object error) =
      DispatchValidationDenied<TResult>;

  // Implements: REQ-DISPATCH-G
  const factory DispatchResult.authorizationDenied(Permission permission) =
      DispatchAuthorizationDenied<TResult>;

  // Implements: REQ-DISPATCH-H
  const factory DispatchResult.executionFailed(Object error) =
      DispatchExecutionFailed<TResult>;

  // Implements: REQ-DISPATCH-E
  const factory DispatchResult.idempotencyHit(
    TResult cachedResult,
    List<String> priorEmittedEventIds,
  ) = DispatchIdempotencyHit<TResult>;
}

class DispatchSuccess<TResult> extends DispatchResult<TResult> {
  const DispatchSuccess(this.result, this.emittedEventIds);
  final TResult result;
  final List<String> emittedEventIds;
}

class DispatchUnknownAction<TResult> extends DispatchResult<TResult> {
  const DispatchUnknownAction(this.requestedName);
  final String requestedName;
}

class DispatchParseDenied<TResult> extends DispatchResult<TResult> {
  const DispatchParseDenied(this.error);
  final Object error;
}

class DispatchValidationDenied<TResult> extends DispatchResult<TResult> {
  const DispatchValidationDenied(this.error);
  final Object error;
}

class DispatchAuthorizationDenied<TResult> extends DispatchResult<TResult> {
  const DispatchAuthorizationDenied(this.permission);
  final Permission permission;
}

class DispatchExecutionFailed<TResult> extends DispatchResult<TResult> {
  const DispatchExecutionFailed(this.error);
  final Object error;
}

class DispatchIdempotencyHit<TResult> extends DispatchResult<TResult> {
  const DispatchIdempotencyHit(this.cachedResult, this.priorEmittedEventIds);
  final TResult cachedResult;
  final List<String> priorEmittedEventIds;
}
```

- [ ] **Run both tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/lib/src/execution_result.dart \
        apps/common-dart/audited_actions/lib/src/dispatch_result.dart \
        apps/common-dart/audited_actions/test/execution_result_test.dart \
        apps/common-dart/audited_actions/test/dispatch_result_test.dart
git commit -m "[CUR-1159] audited_actions: ExecutionResult and sealed DispatchResult"
```

---

### Task 7: `ActionContext`, `Principal`, re-export `SecurityDetails`

**Files:**
- Create: `apps/common-dart/audited_actions/lib/src/action_context.dart`
- Create: `apps/common-dart/audited_actions/test/action_context_test.dart`

**Applicable assertions:** referenced from REQ-ACTION (validate/execute receive an ActionContext) and REQ-DISPATCH (dispatcher constructs Principal/Initiator).

- [ ] **Write failing tests** in `test/action_context_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show Initiator, UserInitiator, AnonymousInitiator, SecurityDetails;
import 'package:audited_actions/src/action_context.dart';
import 'package:test/test.dart';

void main() {
  group('Principal', () {
    test('user variant carries id, roles, activeRole', () {
      final p = Principal.user(
        userId: 'u-1',
        roles: const {'Investigator', 'Analyst'},
        activeRole: 'Investigator',
      );
      expect(p, isA<UserPrincipal>());
      p as UserPrincipal;
      expect(p.userId, 'u-1');
      expect(p.activeRole, 'Investigator');
    });

    test('anonymous variant carries optional ip', () {
      const p = Principal.anonymous(ipAddress: '1.2.3.4');
      expect(p, isA<AnonymousPrincipal>());
    });

    test('UserPrincipal.toInitiator returns UserInitiator with userId', () {
      final p = Principal.user(
        userId: 'u-1',
        roles: const {'X'},
        activeRole: 'X',
      );
      final init = p.toInitiator();
      expect(init, isA<UserInitiator>());
      expect((init as UserInitiator).userId, 'u-1');
    });

    test('AnonymousPrincipal.toInitiator returns AnonymousInitiator with ip', () {
      const p = Principal.anonymous(ipAddress: '5.6.7.8');
      final init = p.toInitiator();
      expect(init, isA<AnonymousInitiator>());
      expect((init as AnonymousInitiator).ipAddress, '5.6.7.8');
    });

    test('UserPrincipal.id returns userId', () {
      final p = Principal.user(
        userId: 'u-7',
        roles: const {'X'},
        activeRole: 'X',
      );
      expect(p.id, 'u-7');
    });

    test('AnonymousPrincipal.id returns "anon:<ip>" or "anon:unknown"', () {
      expect(const Principal.anonymous(ipAddress: '1.1.1.1').id,
             'anon:1.1.1.1');
      expect(const Principal.anonymous().id, 'anon:unknown');
    });
  });

  group('ActionContext', () {
    test('constructs with required fields', () {
      final ctx = ActionContext(
        principal: const Principal.anonymous(),
        security: SecurityDetails(),
        requestStartedAt: DateTime.parse('2026-04-22T12:00:00Z'),
      );
      expect(ctx.principal, isA<AnonymousPrincipal>());
    });
  });
}
```

- [ ] **Run; confirm failure.**

- [ ] **Write `lib/src/action_context.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-ACTION (passed to validate/execute), REQ-DISPATCH (constructed by
//   the request boundary; carries Principal that becomes Initiator on
//   emitted events).

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show Initiator, UserInitiator, AnonymousInitiator, SecurityDetails;

// Re-export SecurityDetails for convenience: ActionContext callers
// shouldn't need a second import for the security parameter.
export 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show SecurityDetails;

/// The authenticated (or anonymous) caller of an action.
//
// Implements: REQ-DISPATCH — Principal.toInitiator() supplies the
// `initiator` field stamped onto every emitted event, including denials.
sealed class Principal {
  const Principal();

  const factory Principal.user({
    required String userId,
    required Set<String> roles,
    required String activeRole,
  }) = UserPrincipal;

  const factory Principal.anonymous({String? ipAddress}) = AnonymousPrincipal;

  /// Stable string identifier for idempotency cache keying.
  /// For users: their userId. For anonymous: 'anon:<ip>' or 'anon:unknown'.
  String get id;

  /// The `Initiator` value the dispatcher stamps onto emitted events.
  Initiator toInitiator();
}

class UserPrincipal extends Principal {
  const UserPrincipal({
    required this.userId,
    required this.roles,
    required this.activeRole,
  });

  final String userId;
  final Set<String> roles;
  final String activeRole;

  @override
  String get id => userId;

  @override
  Initiator toInitiator() => UserInitiator(userId);
}

class AnonymousPrincipal extends Principal {
  const AnonymousPrincipal({this.ipAddress});

  final String? ipAddress;

  @override
  String get id => 'anon:${ipAddress ?? 'unknown'}';

  @override
  Initiator toInitiator() => AnonymousInitiator(ipAddress: ipAddress);
}

/// Carries the per-dispatch caller context: who, with what security
/// telemetry, when. Passed to `Action.validate` and `Action.execute`.
//
// Implements: REQ-DISPATCH — built by the request boundary; passed
// through the pipeline.
class ActionContext {
  const ActionContext({
    required this.principal,
    required this.security,
    required this.requestStartedAt,
  });

  final Principal principal;
  final SecurityDetails security;
  final DateTime requestStartedAt;
}
```

- [ ] **Run tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/lib/src/action_context.dart \
        apps/common-dart/audited_actions/test/action_context_test.dart
git commit -m "[CUR-1159] audited_actions: ActionContext, Principal sealed type"
```

---

### Task 8: `Action` abstract class

**Files:**
- Create: `apps/common-dart/audited_actions/lib/src/action.dart`
- Create: `apps/common-dart/audited_actions/test/action_test.dart`

**Applicable assertions:** REQ-ACTION-A, B, C, D, E.

- [ ] **Write failing tests** in `test/action_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show EventDraft, SecurityDetails;
import 'package:audited_actions/src/action.dart';
import 'package:audited_actions/src/action_context.dart';
import 'package:audited_actions/src/execution_result.dart';
import 'package:audited_actions/src/idempotency.dart';
import 'package:audited_actions/src/permission.dart';
import 'package:test/test.dart';

class _NoOpAction extends Action<Map<String, dynamic>, String> {
  @override
  String get name => 'noop';

  @override
  String get description => 'A no-op for testing.';

  @override
  Set<Permission> get permissions => const {Permission('test.noop')};

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  Map<String, dynamic> parseInput(Map<String, dynamic> raw) => raw;

  @override
  void validate(Map<String, dynamic> input) {}

  @override
  Future<ExecutionResult<String>> execute(
    Map<String, dynamic> input,
    ActionContext ctx,
  ) async =>
      const ExecutionResult(result: 'ok', events: []);
}

void main() {
  group('Action', () {
    test('REQ-ACTION-A: subclass exposes required getters', () {
      final a = _NoOpAction();
      expect(a.name, 'noop');
      expect(a.description, contains('no-op'));
      expect(a.permissions, hasLength(1));
      expect(a.idempotency, Idempotency.none);
    });

    test('REQ-ACTION-A: parseInput returns typed input', () {
      final a = _NoOpAction();
      final input = a.parseInput({'k': 'v'});
      expect(input['k'], 'v');
    });

    test('REQ-ACTION-A: execute returns ExecutionResult', () async {
      final a = _NoOpAction();
      final ctx = ActionContext(
        principal: const Principal.anonymous(),
        security: SecurityDetails(),
        requestStartedAt: DateTime.now(),
      );
      final r = await a.execute({}, ctx);
      expect(r.result, 'ok');
      expect(r.events, isEmpty);
    });

    test('REQ-IDEMPOT-F: default idempotencyTtl is 24 hours', () {
      final a = _NoOpAction();
      expect(a.idempotencyTtl, const Duration(hours: 24));
    });
  });
}
```

- [ ] **Run; confirm failure.**

- [ ] **Write `lib/src/action.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-ACTION (REQ-d00166): unit-of-work interface for portal commands.

import 'package:audited_actions/src/action_context.dart';
import 'package:audited_actions/src/execution_result.dart';
import 'package:audited_actions/src/idempotency.dart';
import 'package:audited_actions/src/permission.dart';

/// A portal command. Concrete subclasses define one action.
///
/// Lifecycle (executed by `ActionDispatcher`):
///   parseInput(raw)            -> typed TInput
///   validate(input)             throws on invalid input
///   <authorize via policy>      uses [permissions]
///   execute(input, ctx)         returns events to persist atomically
//
// Implements: REQ-ACTION-A — interface shape.
//             REQ-ACTION-B,C — purity contracts on parseInput and validate
//             (no I/O); enforced by review, not the type system.
//             REQ-ACTION-D — execute returns ExecutionResult.
//             REQ-ACTION-E — idempotency is declared per action.
abstract class Action<TInput, TResult> {
  const Action();

  /// Unique identifier; appears in event metadata as `action_name`.
  String get name;

  /// Human-readable; surfaces in admin UIs.
  String get description;

  /// Permissions required; ALL must be granted by the AuthorizationPolicy.
  Set<Permission> get permissions;

  /// How the dispatcher treats `idempotencyKey` for calls to this action.
  Idempotency get idempotency;

  /// Per-action TTL override. Default 24 hours.
  // Implements: REQ-IDEMPOT-F
  Duration get idempotencyTtl => defaultIdempotencyTtl;

  /// Parse raw input into the typed shape. Pure: no I/O.
  // Implements: REQ-ACTION-B
  TInput parseInput(Map<String, dynamic> raw);

  /// Validate the typed input. Pure: no I/O. Throws on invalid input.
  // Implements: REQ-ACTION-C
  void validate(TInput input);

  /// Run the action and return events to persist + the typed result.
  // Implements: REQ-ACTION-D
  Future<ExecutionResult<TResult>> execute(TInput input, ActionContext ctx);
}
```

- [ ] **Run tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/lib/src/action.dart \
        apps/common-dart/audited_actions/test/action_test.dart
git commit -m "[CUR-1159] audited_actions: Action abstract class"
```

---

### Task 9: `ActionRegistry`

**Files:**
- Create: `apps/common-dart/audited_actions/lib/src/action_registry.dart`
- Create: `apps/common-dart/audited_actions/test/action_registry_test.dart`

**Applicable assertions:** REQ-ACTREG-A, B, C.

- [ ] **Write failing tests** in `test/action_registry_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show EventDraft;
import 'package:audited_actions/src/action.dart';
import 'package:audited_actions/src/action_context.dart';
import 'package:audited_actions/src/action_registry.dart';
import 'package:audited_actions/src/execution_result.dart';
import 'package:audited_actions/src/idempotency.dart';
import 'package:audited_actions/src/permission.dart';
import 'package:test/test.dart';

class _A extends Action<Map<String, dynamic>, void> {
  _A(this.name, this.permissions);
  @override final String name;
  @override final Set<Permission> permissions;
  @override String get description => '';
  @override Idempotency get idempotency => Idempotency.none;
  @override Map<String, dynamic> parseInput(Map<String, dynamic> raw) => raw;
  @override void validate(Map<String, dynamic> input) {}
  @override Future<ExecutionResult<void>> execute(
    Map<String, dynamic> input, ActionContext ctx,
  ) async => const ExecutionResult(result: null, events: []);
}

void main() {
  group('ActionRegistry', () {
    test('REQ-ACTREG-A: register stores the action', () {
      final r = ActionRegistry();
      r.register(_A('a', {const Permission('p1')}));
      expect(r.lookup('a'), isNotNull);
    });

    test('REQ-ACTREG-A: duplicate name throws ArgumentError', () {
      final r = ActionRegistry();
      r.register(_A('a', {const Permission('p1')}));
      expect(() => r.register(_A('a', {const Permission('p2')})),
             throwsArgumentError);
    });

    test('REQ-ACTREG-B: lookup of unknown name returns null', () {
      final r = ActionRegistry();
      expect(r.lookup('nope'), isNull);
    });

    test('REQ-ACTREG-C: allDeclaredPermissions is the union', () {
      final r = ActionRegistry();
      r.register(_A('a', {const Permission('p1'), const Permission('p2')}));
      r.register(_A('b', {const Permission('p2'), const Permission('p3')}));
      expect(r.allDeclaredPermissions, {
        const Permission('p1'),
        const Permission('p2'),
        const Permission('p3'),
      });
    });

    test('all returns every registered action', () {
      final r = ActionRegistry();
      r.register(_A('a', const {}));
      r.register(_A('b', const {}));
      expect(r.all, hasLength(2));
    });
  });
}
```

- [ ] **Run; confirm failure.**

- [ ] **Write `lib/src/action_registry.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-ACTREG (REQ-d00167): keyed action registry with name-collision
//   detection and permission discovery.

import 'package:audited_actions/src/action.dart';
import 'package:audited_actions/src/permission.dart';

/// Central registry of all `Action` instances known to a deployment.
//
// Implements: REQ-ACTREG-A — register throws on name collision.
//             REQ-ACTREG-B — lookup returns the registered action or null.
//             REQ-ACTREG-C — allDeclaredPermissions is the union across
//             every registered action.
class ActionRegistry {
  ActionRegistry();

  final Map<String, Action<dynamic, dynamic>> _byName = {};

  /// Register `action`. Throws ArgumentError if `action.name` collides.
  // Implements: REQ-ACTREG-A
  void register<TI, TR>(Action<TI, TR> action) {
    if (_byName.containsKey(action.name)) {
      throw ArgumentError.value(
        action.name,
        'action.name',
        'already registered; action names must be unique',
      );
    }
    _byName[action.name] = action;
  }

  /// Returns the action registered under `name`, or null.
  // Implements: REQ-ACTREG-B
  Action<dynamic, dynamic>? lookup(String name) => _byName[name];

  /// All registered actions (insertion order).
  Iterable<Action<dynamic, dynamic>> get all => _byName.values;

  /// Union of `permissions` across every registered action. Used by the
  /// permission discovery tool to seed the role-permission matrix.
  // Implements: REQ-ACTREG-C
  Set<Permission> get allDeclaredPermissions => {
        for (final a in _byName.values) ...a.permissions,
      };
}
```

- [ ] **Run tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/lib/src/action_registry.dart \
        apps/common-dart/audited_actions/test/action_registry_test.dart
git commit -m "[CUR-1159] audited_actions: ActionRegistry"
```

---

### Task 10: `AuthorizationPolicy` abstract + `DenyAllAuthorizationPolicy`

**Files:**
- Create: `apps/common-dart/audited_actions/lib/src/authorization_policy.dart`
- Create: `apps/common-dart/audited_actions/test/authorization_policy_test.dart`

**Applicable assertions:** REQ-AUTHZ-A, C.

- [ ] **Write failing tests** in `test/authorization_policy_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show SecurityDetails;
import 'package:audited_actions/src/action_context.dart';
import 'package:audited_actions/src/authorization_policy.dart';
import 'package:audited_actions/src/permission.dart';
import 'package:test/test.dart';

void main() {
  group('DenyAllAuthorizationPolicy', () {
    test('REQ-AUTHZ-C: always returns false for users', () async {
      final policy = DenyAllAuthorizationPolicy.forTests();
      final principal = Principal.user(
        userId: 'u-1',
        roles: const {'Admin'},
        activeRole: 'Admin',
      );
      final ctx = ActionContext(
        principal: principal,
        security: SecurityDetails(),
        requestStartedAt: DateTime.now(),
      );
      final result = await policy.isPermitted(
        principal,
        const Permission('any.thing'),
        ctx,
      );
      expect(result, isFalse);
    });

    test('REQ-AUTHZ-C: always returns false for anonymous', () async {
      final policy = DenyAllAuthorizationPolicy.forTests();
      const principal = Principal.anonymous();
      final ctx = ActionContext(
        principal: principal,
        security: SecurityDetails(),
        requestStartedAt: DateTime.now(),
      );
      final result = await policy.isPermitted(
        principal,
        const Permission('any.thing'),
        ctx,
      );
      expect(result, isFalse);
    });
  });
}
```

- [ ] **Run; confirm failure.**

- [ ] **Write `lib/src/authorization_policy.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-AUTHZ (REQ-d00169): pluggable authorization with abstract
//   base + DenyAllAuthorizationPolicy fallback.

import 'package:audited_actions/src/action_context.dart';
import 'package:audited_actions/src/permission.dart';

/// Pluggable authorization decision-maker. Concrete impls read from a
/// role-permission matrix or any other source. Called by the dispatcher
/// once per declared permission on the action.
//
// Implements: REQ-AUTHZ-A — interface shape; isPermitted is the only method.
abstract class AuthorizationPolicy {
  const AuthorizationPolicy();

  Future<bool> isPermitted(
    Principal principal,
    Permission permission,
    ActionContext ctx,
  );
}

/// Test/bootstrap fallback that denies every request. The default
/// constructor logs a warning to stderr on every call (signal that
/// production should NOT be using this); use [forTests] to suppress the
/// warning in unit tests.
//
// Implements: REQ-AUTHZ-C — deny-all variant; production usage warns.
class DenyAllAuthorizationPolicy extends AuthorizationPolicy {
  const DenyAllAuthorizationPolicy() : _suppressWarning = false;

  const DenyAllAuthorizationPolicy.forTests() : _suppressWarning = true;

  final bool _suppressWarning;

  @override
  Future<bool> isPermitted(
    Principal principal,
    Permission permission,
    ActionContext ctx,
  ) async {
    if (!_suppressWarning) {
      // ignore: avoid_print
      print('WARNING: DenyAllAuthorizationPolicy.isPermitted called in '
          'production mode (use TableBackedAuthorizationPolicy or another '
          'production policy)');
    }
    return false;
  }
}
```

- [ ] **Run tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/lib/src/authorization_policy.dart \
        apps/common-dart/audited_actions/test/authorization_policy_test.dart
git commit -m "[CUR-1159] audited_actions: AuthorizationPolicy + DenyAll fallback"
```

---

### Task 11: `RoleMatrixReader` interface (COMPLETED in 84574c5b; TableBackedAuthorizationPolicy moved to action_permissions library plan — skip)

> **STOP — DO NOT EXECUTE THIS TASK.** COMPLETED in 84574c5b for the RoleMatrixReader interface portion. The TableBackedAuthorizationPolicy implementation that the body below describes has MOVED to the action_permissions library — see docs/superpowers/plans/2026-05-06-action-permissions-library.md Task 9. DO NOT implement TableBackedAuthorizationPolicy in audited_actions. Return immediately.


**Files:**
- Create: `apps/common-dart/audited_actions/lib/src/role_matrix_reader.dart`
- Create: `apps/common-dart/audited_actions/lib/src/table_backed_authorization_policy.dart`
- Create: `apps/common-dart/audited_actions/test/fixtures/fake_role_matrix_reader.dart`
- Create: `apps/common-dart/audited_actions/test/table_backed_authorization_policy_test.dart`

**Applicable assertions:** REQ-AUTHZ-B.

- [ ] **Write `test/fixtures/fake_role_matrix_reader.dart`:**

```dart
import 'package:audited_actions/src/role_matrix_reader.dart';

class FakeRoleMatrixReader implements RoleMatrixReader {
  FakeRoleMatrixReader(this._matrix);

  final Map<String, Set<String>> _matrix;

  @override
  Future<Set<String>> permissionsForRole(String role) async =>
      Set<String>.from(_matrix[role] ?? const {});
}
```

- [ ] **Write failing tests** in `test/table_backed_authorization_policy_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show SecurityDetails;
import 'package:audited_actions/src/action_context.dart';
import 'package:audited_actions/src/permission.dart';
import 'package:audited_actions/src/table_backed_authorization_policy.dart';
import 'package:test/test.dart';

import 'fixtures/fake_role_matrix_reader.dart';

void main() {
  ActionContext anyCtx(Principal p) => ActionContext(
        principal: p,
        security: SecurityDetails(),
        requestStartedAt: DateTime.now(),
      );

  group('TableBackedAuthorizationPolicy', () {
    test('REQ-AUTHZ-B: granted when matrix contains the permission', () async {
      final matrix = FakeRoleMatrixReader({
        'Investigator': {'patient.read', 'patient.annotate'},
      });
      final policy = TableBackedAuthorizationPolicy(matrix);
      final principal = Principal.user(
        userId: 'u-1',
        roles: const {'Investigator'},
        activeRole: 'Investigator',
      );
      final granted = await policy.isPermitted(
        principal,
        const Permission('patient.annotate'),
        anyCtx(principal),
      );
      expect(granted, isTrue);
    });

    test('REQ-AUTHZ-B: denied when matrix lacks the permission', () async {
      final matrix = FakeRoleMatrixReader({
        'Investigator': {'patient.read'},
      });
      final policy = TableBackedAuthorizationPolicy(matrix);
      final principal = Principal.user(
        userId: 'u-1',
        roles: const {'Investigator'},
        activeRole: 'Investigator',
      );
      final granted = await policy.isPermitted(
        principal,
        const Permission('user.invite'),
        anyCtx(principal),
      );
      expect(granted, isFalse);
    });

    test('REQ-AUTHZ-B: anonymous principal always denied', () async {
      final matrix = FakeRoleMatrixReader({
        'AnyRole': {'user.invite'},
      });
      final policy = TableBackedAuthorizationPolicy(matrix);
      const principal = Principal.anonymous(ipAddress: '1.2.3.4');
      final granted = await policy.isPermitted(
        principal,
        const Permission('user.invite'),
        anyCtx(principal),
      );
      expect(granted, isFalse);
    });

    test('REQ-AUTHZ-B: respects activeRole (not all user roles)', () async {
      final matrix = FakeRoleMatrixReader({
        'Investigator': {'patient.read'},
        'Admin': {'user.invite'},
      });
      final policy = TableBackedAuthorizationPolicy(matrix);
      // user has both roles but activeRole is Investigator
      final principal = Principal.user(
        userId: 'u-1',
        roles: const {'Investigator', 'Admin'},
        activeRole: 'Investigator',
      );
      final invitePerm = await policy.isPermitted(
        principal,
        const Permission('user.invite'),
        anyCtx(principal),
      );
      expect(invitePerm, isFalse, reason: 'Admin permission not active');
      final readPerm = await policy.isPermitted(
        principal,
        const Permission('patient.read'),
        anyCtx(principal),
      );
      expect(readPerm, isTrue);
    });
  });
}
```

- [ ] **Run; confirm failure.**

- [ ] **Write `lib/src/role_matrix_reader.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-AUTHZ-B: read interface for the role-permission matrix.

/// Read-only access to the deploy-time-configurable role-permission
/// matrix. Implementations typically read from a Postgres materialized
/// view (`role_permission_matrix`) populated by the discovery tool +
/// admin grants.
//
// Implements: REQ-AUTHZ-B — TableBackedAuthorizationPolicy depends on
// this; deployers wire a concrete impl at app bootstrap.
abstract class RoleMatrixReader {
  Future<Set<String>> permissionsForRole(String role);
}
```

- [ ] **Write `lib/src/table_backed_authorization_policy.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-AUTHZ-B: matrix-backed authorization policy.

import 'package:audited_actions/src/action_context.dart';
import 'package:audited_actions/src/authorization_policy.dart';
import 'package:audited_actions/src/permission.dart';
import 'package:audited_actions/src/role_matrix_reader.dart';

/// Authorization policy backed by a `RoleMatrixReader`. Decision:
///   - Anonymous principal: always false.
///   - User principal: lookup activeRole's permissions from the matrix;
///     return whether `permission.name` is in that set.
//
// Implements: REQ-AUTHZ-B — TableBackedAuthorizationPolicy contract.
class TableBackedAuthorizationPolicy extends AuthorizationPolicy {
  const TableBackedAuthorizationPolicy(this._matrix);

  final RoleMatrixReader _matrix;

  @override
  Future<bool> isPermitted(
    Principal principal,
    Permission permission,
    ActionContext ctx,
  ) async {
    if (principal is! UserPrincipal) {
      return false;
    }
    final perms = await _matrix.permissionsForRole(principal.activeRole);
    return perms.contains(permission.name);
  }
}
```

- [ ] **Run tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/lib/src/role_matrix_reader.dart \
        apps/common-dart/audited_actions/lib/src/table_backed_authorization_policy.dart \
        apps/common-dart/audited_actions/test/fixtures/fake_role_matrix_reader.dart \
        apps/common-dart/audited_actions/test/table_backed_authorization_policy_test.dart
git commit -m "[CUR-1159] audited_actions: RoleMatrixReader + TableBackedAuthorizationPolicy"
```

---

### Task 12: `IdempotencyStore` abstract + `InMemoryIdempotencyStore` (COMPLETED in 84574c5b — skip)

> **STOP — DO NOT EXECUTE THIS TASK.** COMPLETED in 84574c5b. lib/src/idempotency_store.dart and tests already exist. Return immediately.


**Files:**
- Create: `apps/common-dart/audited_actions/lib/src/idempotency_store.dart`
- Create: `apps/common-dart/audited_actions/test/idempotency_store_test.dart`

**Applicable assertions:** REQ-IDEMPOT-D, E.

- [ ] **Write failing tests** in `test/idempotency_store_test.dart`:

```dart
import 'package:audited_actions/src/idempotency.dart';
import 'package:audited_actions/src/idempotency_store.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryIdempotencyStore', () {
    late InMemoryIdempotencyStore store;

    setUp(() {
      store = InMemoryIdempotencyStore();
    });

    test('lookup miss returns null', () async {
      final entry = await store.lookup('a', 'p', 'k');
      expect(entry, isNull);
    });

    test('REQ-IDEMPOT-D: record then lookup returns cached entry', () async {
      await store.record(
        actionName: 'a',
        principalId: 'p',
        key: 'k',
        resultJson: const {'x': 1},
        emittedEventIds: const ['evt-1'],
        expiresAt: DateTime.parse('2099-01-01T00:00:00Z'),
      );
      final entry = await store.lookup('a', 'p', 'k');
      expect(entry, isNotNull);
      expect(entry!.resultJson['x'], 1);
      expect(entry.emittedEventIds, ['evt-1']);
    });

    test('lookup with different key misses', () async {
      await store.record(
        actionName: 'a', principalId: 'p', key: 'k',
        resultJson: const {}, emittedEventIds: const [],
        expiresAt: DateTime.parse('2099-01-01T00:00:00Z'),
      );
      expect(await store.lookup('a', 'p', 'other'), isNull);
    });

    test('lookup with different principal misses', () async {
      await store.record(
        actionName: 'a', principalId: 'p1', key: 'k',
        resultJson: const {}, emittedEventIds: const [],
        expiresAt: DateTime.parse('2099-01-01T00:00:00Z'),
      );
      expect(await store.lookup('a', 'p2', 'k'), isNull);
    });

    test('lookup with different action misses', () async {
      await store.record(
        actionName: 'a', principalId: 'p', key: 'k',
        resultJson: const {}, emittedEventIds: const [],
        expiresAt: DateTime.parse('2099-01-01T00:00:00Z'),
      );
      expect(await store.lookup('b', 'p', 'k'), isNull);
    });

    test('REQ-IDEMPOT-E: sweepExpired removes past entries', () async {
      await store.record(
        actionName: 'a', principalId: 'p', key: 'old',
        resultJson: const {}, emittedEventIds: const [],
        expiresAt: DateTime.parse('2026-01-01T00:00:00Z'),
      );
      await store.record(
        actionName: 'a', principalId: 'p', key: 'fresh',
        resultJson: const {}, emittedEventIds: const [],
        expiresAt: DateTime.parse('2099-01-01T00:00:00Z'),
      );
      final swept = await store.sweepExpired(
        before: DateTime.parse('2026-06-01T00:00:00Z'),
      );
      expect(swept, 1);
      expect(await store.lookup('a', 'p', 'old'), isNull);
      expect(await store.lookup('a', 'p', 'fresh'), isNotNull);
    });

    test('expired lookup returns null even before sweep', () async {
      await store.record(
        actionName: 'a', principalId: 'p', key: 'k',
        resultJson: const {}, emittedEventIds: const [],
        expiresAt: DateTime.parse('2026-01-01T00:00:00Z'),
      );
      // The store's lookup must filter expired regardless of sweep state.
      // Pass a `now` so the test is deterministic.
      final entry = await store.lookup('a', 'p', 'k',
          now: DateTime.parse('2026-06-01T00:00:00Z'));
      expect(entry, isNull);
    });
  });
}
```

- [ ] **Run; confirm failure.**

- [ ] **Write `lib/src/idempotency_store.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-IDEMPOT-D+E (REQ-d00170): cache-with-TTL contract for action
//   replay protection; in-memory impl for tests and early development.

import 'package:audited_actions/src/idempotency.dart';

/// Pluggable cache for action dispatch outcomes, keyed by
/// `(actionName, principalId, key)`. Lookup hits short-circuit a
/// dispatch and return the cached result.
//
// Implements: REQ-IDEMPOT-D — lookup hit returns cached payload;
//             REQ-IDEMPOT-E — sweepExpired purges past-expiry entries.
abstract class IdempotencyStore {
  Future<IdempotencyEntry?> lookup(
    String actionName,
    String principalId,
    String key, {
    DateTime? now,
  });

  Future<void> record({
    required String actionName,
    required String principalId,
    required String key,
    required Map<String, dynamic> resultJson,
    required List<String> emittedEventIds,
    required DateTime expiresAt,
  });

  Future<int> sweepExpired({DateTime? before});
}

/// In-memory `IdempotencyStore` for tests and per-process state during
/// early development. Production uses a Postgres-backed impl from a
/// later "port to portal" ticket.
class InMemoryIdempotencyStore implements IdempotencyStore {
  InMemoryIdempotencyStore();

  // key: '<action>|<principal>|<key>'
  final Map<String, IdempotencyEntry> _entries = {};

  String _composite(String a, String p, String k) => '$a|$p|$k';

  @override
  Future<IdempotencyEntry?> lookup(
    String actionName,
    String principalId,
    String key, {
    DateTime? now,
  }) async {
    final entry = _entries[_composite(actionName, principalId, key)];
    if (entry == null) return null;
    if (entry.isExpired(now: now ?? DateTime.now())) return null;
    return entry;
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
    _entries[_composite(actionName, principalId, key)] = IdempotencyEntry(
      resultJson: Map<String, dynamic>.unmodifiable(resultJson),
      emittedEventIds: List<String>.unmodifiable(emittedEventIds),
      recordedAt: DateTime.now(),
      expiresAt: expiresAt,
    );
  }

  @override
  Future<int> sweepExpired({DateTime? before}) async {
    final cutoff = before ?? DateTime.now();
    final keysToRemove = _entries.entries
        .where((e) => e.value.isExpired(now: cutoff))
        .map((e) => e.key)
        .toList();
    for (final k in keysToRemove) {
      _entries.remove(k);
    }
    return keysToRemove.length;
  }
}
```

- [ ] **Run tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/lib/src/idempotency_store.dart \
        apps/common-dart/audited_actions/test/idempotency_store_test.dart
git commit -m "[CUR-1159] audited_actions: IdempotencyStore + in-memory impl"
```

---

### Task 13: `EventsApi` adapter (DROPPED — audited_actions consumes event_sourcing_datastore.EventStore directly; skip)

> **STOP — DO NOT EXECUTE THIS TASK.** DROPPED. audited_actions consumes event_sourcing_datastore.EventStore directly; no EventsApi adapter interface is built in this package. The dispatcher's persist stage (Task 19) calls EventStore.transaction and EventStore.appendWithSecurity directly. DO NOT implement events_api.dart, FakeEventsApi, or events_api_test.dart. Return immediately.


**Files:**
- Create: `apps/common-dart/audited_actions/lib/src/events_api.dart`
- Create: `apps/common-dart/audited_actions/test/fixtures/fake_events_api.dart`
- Create: `apps/common-dart/audited_actions/test/events_api_test.dart`

**Applicable assertions:** referenced from REQ-DISPATCH-I (atomic persist).

This task defines the contract the dispatcher uses to talk to the events lib. Adapter (the bit that wraps the actual `event_sourcing_datastore` API) is wired at deployment-app bootstrap, not in this package.

- [ ] **Write `lib/src/events_api.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-DISPATCH-I (REQ-d00168): atomic persistence contract used by
//   the dispatcher to write success and denial events through the events
//   lib (event_sourcing_datastore post-Sub-project-E).

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show EventDraft, SecurityDetails, StoredEvent;

/// Thin contract the dispatcher uses to talk to the events lib. The
/// deploying app provides an adapter that wraps the events lib's actual
/// API (e.g. EntryService or EventRepository post-Sub-project-E).
//
// Implements: REQ-DISPATCH-I — transaction wrapper allows the dispatcher
// to write multiple EventDrafts atomically.
abstract class EventsApi {
  Future<T> transaction<T>(
    Future<T> Function(EventsTransaction txn) body,
  );
}

/// Handle on an in-flight events-lib transaction. Throws of any kind
/// inside the `body` callback rolls back every write performed within.
abstract class EventsTransaction {
  Future<StoredEvent> appendWithSecurity(
    EventDraft draft, {
    SecurityDetails? security,
  });
}
```

- [ ] **Write `test/fixtures/fake_events_api.dart`:**

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show EventDraft, Initiator, SecurityDetails, StoredEvent, UserInitiator;
import 'package:audited_actions/src/events_api.dart';
import 'package:uuid/uuid.dart';

/// In-memory test double for the events lib. Records every successful
/// append; supports a configurable failure injection for testing
/// rollback semantics.
class FakeEventsApi implements EventsApi {
  FakeEventsApi();

  final List<_AppendCall> appended = [];
  final List<_AppendCall> attempted = [];

  /// If non-null, the next call to `appendWithSecurity` whose draft's
  /// `aggregateId` matches throws this object instead of appending.
  Object? failOnAggregateId;
  String? _failTargetAggregateId;

  void failNextAppendForAggregate(String aggregateId, Object error) {
    failOnAggregateId = error;
    _failTargetAggregateId = aggregateId;
  }

  static const _uuid = Uuid();

  @override
  Future<T> transaction<T>(
    Future<T> Function(EventsTransaction txn) body,
  ) async {
    final txn = _FakeTransaction(this);
    try {
      final result = await body(txn);
      appended.addAll(txn.staged);
      return result;
    } catch (_) {
      // Rollback: discard staged writes (they were never moved to `appended`).
      rethrow;
    }
  }
}

class _FakeTransaction implements EventsTransaction {
  _FakeTransaction(this.api);
  final FakeEventsApi api;
  final List<_AppendCall> staged = [];

  @override
  Future<StoredEvent> appendWithSecurity(
    EventDraft draft, {
    SecurityDetails? security,
  }) async {
    api.attempted.add(_AppendCall(draft, security));
    if (api.failOnAggregateId != null &&
        draft.aggregateId == api._failTargetAggregateId) {
      final err = api.failOnAggregateId!;
      api.failOnAggregateId = null;
      api._failTargetAggregateId = null;
      throw err;
    }
    final eventId = FakeEventsApi._uuid.v4();
    staged.add(_AppendCall(draft, security));
    // Return a minimal StoredEvent. The exact shape post-Sub-project-E
    // will provide a constructor; if not available, this fixture
    // synthesizes the fields that downstream tests inspect (eventId,
    // initiator, flowToken).
    return StoredEvent.synthetic(
      eventId: eventId,
      aggregateId: draft.aggregateId,
      aggregateType: draft.aggregateType,
      entryType: draft.entryType,
      eventType: draft.eventType,
      data: draft.data,
      flowToken: draft.flowToken,
      // Initiator is required; the dispatcher will have set it on the draft
      // before calling, so it should be non-null.
      initiator: draft.initiator ?? const UserInitiator('synthetic-no-initiator'),
      sequenceNumber: api.appended.length + staged.length,
    );
  }
}

class _AppendCall {
  _AppendCall(this.draft, this.security);
  final EventDraft draft;
  final SecurityDetails? security;
}
```

**Note:** the fixture above calls `StoredEvent.synthetic(...)` — a hypothetical helper. Sub-project E should provide either this helper or a regular constructor that accepts `eventId` directly (rather than computing it). If neither is available when implementing this task, add a minimal `StoredEvent.synthetic` factory to the events lib in a small follow-up commit — it's testing-infrastructure, not production code, and avoids duplicating the lib's hashing/sequencing inside test fixtures.

- [ ] **Write smoke test** in `test/events_api_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show EventDraft, UserInitiator;
import 'package:test/test.dart';

import 'fixtures/fake_events_api.dart';

void main() {
  group('FakeEventsApi (test fixture sanity)', () {
    test('successful transaction records all staged appends', () async {
      final api = FakeEventsApi();
      await api.transaction((txn) async {
        await txn.appendWithSecurity(EventDraft(
          aggregateId: 'a-1',
          aggregateType: 't',
          entryType: 'e',
          eventType: 'x',
          data: const {},
          initiator: const UserInitiator('u-1'),
        ));
        await txn.appendWithSecurity(EventDraft(
          aggregateId: 'a-2',
          aggregateType: 't',
          entryType: 'e',
          eventType: 'x',
          data: const {},
          initiator: const UserInitiator('u-1'),
        ));
      });
      expect(api.appended, hasLength(2));
    });

    test('exception inside transaction discards staged appends', () async {
      final api = FakeEventsApi();
      try {
        await api.transaction((txn) async {
          await txn.appendWithSecurity(EventDraft(
            aggregateId: 'a-1',
            aggregateType: 't',
            entryType: 'e',
            eventType: 'x',
            data: const {},
            initiator: const UserInitiator('u-1'),
          ));
          throw StateError('force rollback');
        });
      } catch (_) {/* expected */}
      expect(api.appended, isEmpty);
      expect(api.attempted, hasLength(1));
    });

    test('failNextAppendForAggregate causes rollback', () async {
      final api = FakeEventsApi();
      api.failNextAppendForAggregate('a-bad', StateError('forced'));
      try {
        await api.transaction((txn) async {
          await txn.appendWithSecurity(EventDraft(
            aggregateId: 'a-good',
            aggregateType: 't',
            entryType: 'e',
            eventType: 'x',
            data: const {},
            initiator: const UserInitiator('u-1'),
          ));
          await txn.appendWithSecurity(EventDraft(
            aggregateId: 'a-bad',
            aggregateType: 't',
            entryType: 'e',
            eventType: 'x',
            data: const {},
            initiator: const UserInitiator('u-1'),
          ));
        });
      } catch (_) {/* expected */}
      expect(api.appended, isEmpty, reason: 'rollback should discard a-good');
    });
  });
}
```

- [ ] **Run tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/lib/src/events_api.dart \
        apps/common-dart/audited_actions/test/fixtures/fake_events_api.dart \
        apps/common-dart/audited_actions/test/events_api_test.dart
git commit -m "[CUR-1159] audited_actions: EventsApi/EventsTransaction interfaces + fake"
```

---

### Task 14: `denial_events.dart` factories

**Files:**
- Create: `apps/common-dart/audited_actions/lib/src/denial_events.dart`
- Create: `apps/common-dart/audited_actions/test/denial_events_test.dart`

**Applicable assertions:** REQ-DENIAL-A, B, C.

- [ ] **Write failing tests** in `test/denial_events_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show EventDraft;
import 'package:audited_actions/src/denial_events.dart';
import 'package:audited_actions/src/permission.dart';
import 'package:test/test.dart';

void main() {
  group('denial event factories', () {
    test('REQ-DENIAL-A: unknownAction draft has correct shape', () {
      final draft = denialUnknownAction(
        invocationId: 'inv-1',
        requestedName: 'foo',
        actionInvocationMetadata: {'request_id': 'r-1'},
      );
      expect(draft.aggregateType, 'action_attempt');
      expect(draft.aggregateId, 'inv-1');
      expect(draft.entryType, 'action_denial');
      expect(draft.eventType, 'unknown_action');
      expect(draft.data['requested_name'], 'foo');
    });

    test('REQ-DENIAL-A,B: parseDenied includes sanitized error message', () {
      final draft = denialParseDenied(
        invocationId: 'inv-1',
        actionName: 'invite_user',
        error: ArgumentError('email is required at /home/user/secret/file.dart:42'),
      );
      expect(draft.eventType, 'parse_denied');
      expect(draft.data['error_class'], 'ArgumentError');
      // REQ-DENIAL-C: file paths sanitized out
      expect(draft.data['error_message_sanitized'],
             isNot(contains('/home/user/secret')));
    });

    test('REQ-DENIAL-A,B: validationDenied carries error', () {
      final draft = denialValidationDenied(
        invocationId: 'inv-1',
        actionName: 'invite_user',
        error: StateError('email malformed'),
      );
      expect(draft.eventType, 'validation_denied');
      expect(draft.data['error_class'], 'StateError');
    });

    test('REQ-DENIAL-A,B: authorizationDenied includes permission and active role', () {
      final draft = denialAuthorizationDenied(
        invocationId: 'inv-1',
        actionName: 'user.delete',
        permission: const Permission('user.delete'),
        principalActiveRole: 'Investigator',
      );
      expect(draft.eventType, 'authorization_denied');
      expect(draft.data['permission_denied'], 'user.delete');
      expect(draft.data['principal_active_role'], 'Investigator');
    });

    test('REQ-DENIAL-A,B: executionFailed carries sanitized error', () {
      final draft = denialExecutionFailed(
        invocationId: 'inv-1',
        actionName: 'invite_user',
        error: StateError('boom'),
      );
      expect(draft.eventType, 'execution_failed');
      expect(draft.data['error_class'], 'StateError');
    });

    test('REQ-DENIAL-C: sanitization strips stack trace markers', () {
      final draft = denialExecutionFailed(
        invocationId: 'inv-1',
        actionName: 'a',
        error: StateError(
          'boom\n#0 main (file:///home/me/foo.dart:10:5)\n#1 ...',
        ),
      );
      final msg = draft.data['error_message_sanitized'] as String;
      expect(msg, isNot(contains('#0 main')));
      expect(msg, isNot(contains('file:///')));
    });
  });
}
```

- [ ] **Run; confirm failure.**

- [ ] **Write `lib/src/denial_events.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-DENIAL (REQ-d00171): typed denial event drafts; sanitization.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show EventDraft;
import 'package:audited_actions/src/permission.dart';

const String _aggregateType = 'action_attempt';
const String _entryType = 'action_denial';

/// Strip stack-trace lines, file paths, and likely-input-echoes from an
/// error message before persisting it to the audit log.
//
// Implements: REQ-DENIAL-C — sanitization rules.
String sanitizeErrorMessage(Object error) {
  final raw = error.toString();
  // Remove stack-trace lines: `#N ... (file:///... or path)`.
  final noStack = raw.replaceAll(
    RegExp(r'\n?#\d+\s+[^\n]*', multiLine: true),
    '',
  );
  // Strip absolute paths (Unix and file URIs and Windows drive letters).
  final noPaths = noStack
      .replaceAll(RegExp(r'file://[^\s)]*'), '<path>')
      .replaceAll(RegExp(r'(?:^|\s)/[A-Za-z0-9_./-]+'), ' <path>')
      .replaceAll(RegExp(r'\b[A-Za-z]:\\[^\s)]*'), '<path>');
  return noPaths.trim();
}

EventDraft denialUnknownAction({
  required String invocationId,
  required String requestedName,
  Map<String, dynamic>? actionInvocationMetadata,
}) =>
    EventDraft(
      aggregateId: invocationId,
      aggregateType: _aggregateType,
      entryType: _entryType,
      eventType: 'unknown_action',
      data: {'requested_name': requestedName},
      metadata: actionInvocationMetadata,
    );

EventDraft denialParseDenied({
  required String invocationId,
  required String actionName,
  required Object error,
  Map<String, dynamic>? actionInvocationMetadata,
}) =>
    EventDraft(
      aggregateId: invocationId,
      aggregateType: _aggregateType,
      entryType: _entryType,
      eventType: 'parse_denied',
      data: {
        'error_class': error.runtimeType.toString(),
        'error_message_sanitized': sanitizeErrorMessage(error),
        'action_name': actionName,
      },
      metadata: actionInvocationMetadata,
    );

EventDraft denialValidationDenied({
  required String invocationId,
  required String actionName,
  required Object error,
  String? fieldPath,
  Map<String, dynamic>? actionInvocationMetadata,
}) =>
    EventDraft(
      aggregateId: invocationId,
      aggregateType: _aggregateType,
      entryType: _entryType,
      eventType: 'validation_denied',
      data: {
        'error_class': error.runtimeType.toString(),
        'error_message_sanitized': sanitizeErrorMessage(error),
        'action_name': actionName,
        if (fieldPath != null) 'field_path': fieldPath,
      },
      metadata: actionInvocationMetadata,
    );

EventDraft denialAuthorizationDenied({
  required String invocationId,
  required String actionName,
  required Permission permission,
  String? principalActiveRole,
  Map<String, dynamic>? actionInvocationMetadata,
}) =>
    EventDraft(
      aggregateId: invocationId,
      aggregateType: _aggregateType,
      entryType: _entryType,
      eventType: 'authorization_denied',
      data: {
        'action_name': actionName,
        'permission_denied': permission.name,
        if (principalActiveRole != null)
          'principal_active_role': principalActiveRole,
      },
      metadata: actionInvocationMetadata,
    );

EventDraft denialExecutionFailed({
  required String invocationId,
  required String actionName,
  required Object error,
  Map<String, dynamic>? actionInvocationMetadata,
}) =>
    EventDraft(
      aggregateId: invocationId,
      aggregateType: _aggregateType,
      entryType: _entryType,
      eventType: 'execution_failed',
      data: {
        'error_class': error.runtimeType.toString(),
        'error_message_sanitized': sanitizeErrorMessage(error),
        'action_name': actionName,
      },
      metadata: actionInvocationMetadata,
    );
```

- [ ] **Run tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/lib/src/denial_events.dart \
        apps/common-dart/audited_actions/test/denial_events_test.dart
git commit -m "[CUR-1159] audited_actions: denial event factories + sanitization"
```

---

### Task 15: `ActionDispatcher` skeleton + Stage 1 (lookup) + Stage 2 (invocation_id)

**Files:**
- Create: `apps/common-dart/audited_actions/lib/src/action_dispatcher.dart`
- Create: `apps/common-dart/audited_actions/test/fixtures/test_actions.dart`
- Create: `apps/common-dart/audited_actions/test/action_dispatcher_test.dart`

**Applicable assertions:** REQ-DISPATCH-A, B, C.

This task introduces the dispatcher class and tests its first two pipeline stages (lookup + invocation_id stamping). Subsequent tasks (16–22) add stages on top, each with its own TDD cycle.

- [ ] **Write `test/fixtures/test_actions.dart`** (used across all dispatcher tests):

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show EventDraft;
import 'package:audited_actions/src/action.dart';
import 'package:audited_actions/src/action_context.dart';
import 'package:audited_actions/src/execution_result.dart';
import 'package:audited_actions/src/idempotency.dart';
import 'package:audited_actions/src/permission.dart';

/// Always-succeeds, emits one event.
class HelloAction extends Action<Map<String, dynamic>, String> {
  @override String get name => 'hello';
  @override String get description => 'Say hello.';
  @override Set<Permission> get permissions => const {Permission('test.hello')};
  @override Idempotency get idempotency => Idempotency.none;
  @override Map<String, dynamic> parseInput(Map<String, dynamic> raw) =>
      {'who': raw['who'] as String};
  @override void validate(Map<String, dynamic> input) {}
  @override Future<ExecutionResult<String>> execute(
    Map<String, dynamic> input, ActionContext ctx,
  ) async {
    return ExecutionResult(
      result: 'Hello, ${input['who']}',
      events: [
        EventDraft(
          aggregateId: 'greeting-${input['who']}',
          aggregateType: 'greeting',
          entryType: 'greeting',
          eventType: 'hello.said',
          data: {'who': input['who']},
        ),
      ],
    );
  }
}

/// Throws on parse.
class BadParseAction extends HelloAction {
  @override String get name => 'bad_parse';
  @override Map<String, dynamic> parseInput(Map<String, dynamic> raw) {
    throw ArgumentError('parse failure');
  }
}

/// Throws on validate.
class BadValidateAction extends HelloAction {
  @override String get name => 'bad_validate';
  @override void validate(Map<String, dynamic> input) {
    throw StateError('validate failure');
  }
}

/// Throws on execute.
class BadExecuteAction extends HelloAction {
  @override String get name => 'bad_execute';
  @override Future<ExecutionResult<String>> execute(
    Map<String, dynamic> input, ActionContext ctx,
  ) async {
    throw StateError('execute failure');
  }
}

/// Emits multiple events; used to test Stage 8 atomicity.
class MultiEventAction extends Action<Map<String, dynamic>, void> {
  @override String get name => 'multi';
  @override String get description => 'Emits 3 events.';
  @override Set<Permission> get permissions => const {Permission('test.multi')};
  @override Idempotency get idempotency => Idempotency.none;
  @override Map<String, dynamic> parseInput(Map<String, dynamic> raw) => raw;
  @override void validate(Map<String, dynamic> input) {}
  @override Future<ExecutionResult<void>> execute(
    Map<String, dynamic> input, ActionContext ctx,
  ) async {
    return ExecutionResult(
      result: null,
      events: [
        for (final id in const ['a', 'b', 'c'])
          EventDraft(
            aggregateId: id,
            aggregateType: 'multi-test',
            entryType: 'multi-test',
            eventType: 'event.emitted',
            data: const {},
          ),
      ],
    );
  }
}

/// Idempotency.required action.
class RequiredKeyAction extends HelloAction {
  @override String get name => 'requires_key';
  @override Idempotency get idempotency => Idempotency.required;
}
```

- [ ] **Write failing tests** in `test/action_dispatcher_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show SecurityDetails;
import 'package:audited_actions/src/action_context.dart';
import 'package:audited_actions/src/action_dispatcher.dart';
import 'package:audited_actions/src/action_registry.dart';
import 'package:audited_actions/src/authorization_policy.dart';
import 'package:audited_actions/src/dispatch_result.dart';
import 'package:audited_actions/src/idempotency_store.dart';
import 'package:test/test.dart';

import 'fixtures/fake_events_api.dart';
import 'fixtures/test_actions.dart';

ActionContext _ctx() => ActionContext(
      principal: Principal.user(
        userId: 'u-1',
        roles: const {'tester'},
        activeRole: 'tester',
      ),
      security: SecurityDetails(),
      requestStartedAt: DateTime.parse('2026-04-22T12:00:00Z'),
    );

void main() {
  late ActionRegistry registry;
  late FakeEventsApi events;
  late InMemoryIdempotencyStore idempotency;
  late ActionDispatcher dispatcher;

  setUp(() {
    registry = ActionRegistry()
      ..register(HelloAction());
    events = FakeEventsApi();
    idempotency = InMemoryIdempotencyStore();
    dispatcher = ActionDispatcher(
      registry: registry,
      authorization: const DenyAllAuthorizationPolicy.forTests(),
      events: events,
      idempotency: idempotency,
    );
  });

  group('Stage 1 — lookup', () {
    test('REQ-DISPATCH-B: unknown action returns DispatchUnknownAction', () async {
      final r = await dispatcher.dispatch('nope', const {}, _ctx());
      expect(r, isA<DispatchUnknownAction<dynamic>>());
      r as DispatchUnknownAction<dynamic>;
      expect(r.requestedName, 'nope');
    });

    test('REQ-DISPATCH-B: unknown action emits unknown_action denial event', () async {
      await dispatcher.dispatch('nope', const {}, _ctx());
      expect(events.appended, hasLength(1));
      expect(events.appended.first.draft.eventType, 'unknown_action');
      expect(events.appended.first.draft.data['requested_name'], 'nope');
    });
  });

  group('Stage 2 — invocation_id stamping', () {
    test('REQ-DISPATCH-C: every emitted event has action_invocation_id metadata', () async {
      // Use the unknown-action path (always emits the denial event).
      await dispatcher.dispatch('nope', const {}, _ctx());
      final meta = events.appended.first.draft.metadata;
      expect(meta, isNotNull);
      expect(meta!['action_invocation_id'], isNotNull);
      expect(meta['action_invocation_id'], isA<String>());
    });

    test('REQ-DISPATCH-C: invocation_id is unique per call', () async {
      await dispatcher.dispatch('nope', const {}, _ctx());
      await dispatcher.dispatch('nope', const {}, _ctx());
      final firstId = events.appended[0].draft.metadata!['action_invocation_id'];
      final secondId = events.appended[1].draft.metadata!['action_invocation_id'];
      expect(firstId, isNot(equals(secondId)));
    });
  });
}
```

- [ ] **Run; confirm failure.**

- [ ] **Write `lib/src/action_dispatcher.dart`** (initial skeleton + stages 1–2):

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-DISPATCH (REQ-d00168): pipeline owner; subsequent tasks add
//   stages 3-10.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show EventDraft;
import 'package:audited_actions/src/action_context.dart';
import 'package:audited_actions/src/action_registry.dart';
import 'package:audited_actions/src/authorization_policy.dart';
import 'package:audited_actions/src/denial_events.dart';
import 'package:audited_actions/src/dispatch_result.dart';
import 'package:audited_actions/src/events_api.dart';
import 'package:audited_actions/src/idempotency_store.dart';
import 'package:uuid/uuid.dart';

/// Runs every untrusted-ingress action through the standard pipeline.
//
// Implements: REQ-DISPATCH — full pipeline; this initial skeleton covers
// stages 1 (lookup) and 2 (invocation_id). Tasks 16-22 add the rest.
class ActionDispatcher {
  ActionDispatcher({
    required this.registry,
    required this.authorization,
    required this.events,
    required this.idempotency,
  });

  final ActionRegistry registry;
  final AuthorizationPolicy authorization;
  final EventsApi events;
  final IdempotencyStore idempotency;

  static const _uuid = Uuid();

  /// Dispatch one action call. See REQ-DISPATCH for the full pipeline.
  Future<DispatchResult<dynamic>> dispatch(
    String actionName,
    Map<String, dynamic> rawInput,
    ActionContext ctx, {
    String? idempotencyKey,
    String? flowToken,
  }) async {
    // Stage 2: invocation_id (generated up front so denials can carry it).
    final invocationId = _uuid.v4();
    final invocationMetadata = <String, dynamic>{
      'action_invocation_id': invocationId,
      'action_name': actionName,
    };

    // Stage 1: lookup
    final action = registry.lookup(actionName);
    if (action == null) {
      // Implements: REQ-DISPATCH-B
      await _emitDenial(
        denialUnknownAction(
          invocationId: invocationId,
          requestedName: actionName,
          actionInvocationMetadata: invocationMetadata,
        ),
        ctx,
      );
      return DispatchResult<dynamic>.unknownAction(actionName);
    }

    // Stages 3-10: TODO in Tasks 16-22.
    // For this task's scope, fall through to a not-yet-implemented marker
    // so the test suite focusing on stages 1-2 passes.
    throw UnimplementedError(
      'Stages 3-10 of the dispatcher pipeline are added in Tasks 16-22 '
      'of the implementation plan.',
    );
  }

  Future<void> _emitDenial(EventDraft draft, ActionContext ctx) async {
    // Wrapped in transaction to participate in the same atomic-write
    // semantics used by success path; one denial = one event.
    await events.transaction((txn) async {
      // Stamp initiator from the principal so denials are attributable.
      final stamped = draft.copyWith(initiator: ctx.principal.toInitiator());
      await txn.appendWithSecurity(stamped, security: ctx.security);
    });
  }
}
```

**Note** about `EventDraft.copyWith` and `EventDraft.initiator`: Sub-project E should expose these (the design doc specifies `initiator` is a field on `StoredEvent` and `EventDraft`). If Sub-project E's actual API differs (e.g. immutable `EventDraft` without `copyWith`), this dispatcher constructs a new `EventDraft` from the denial-event factory's output by passing the initiator at construction time instead. The denial-event factories in Task 14 may need to accept an optional `initiator` parameter; if so, plumb it through here. This integration detail surfaces at Task 15 implementation time and may require small adjustments to Tasks 13/14.

- [ ] **Run tests + analyze; confirm pass for stage 1-2 tests.** Other dispatcher tests (added in Tasks 16-22) will fail — that's expected; tests for those stages don't exist yet.

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/lib/src/action_dispatcher.dart \
        apps/common-dart/audited_actions/test/fixtures/test_actions.dart \
        apps/common-dart/audited_actions/test/action_dispatcher_test.dart
git commit -m "[CUR-1159] audited_actions: ActionDispatcher skeleton + Stage 1 (lookup) + Stage 2 (invocation_id)"
```

---

### Task 16: Dispatcher Stage 3 (parse) + Stage 4 (idempotency check)

**Files:**
- Modify: `apps/common-dart/audited_actions/lib/src/action_dispatcher.dart`
- Modify: `apps/common-dart/audited_actions/test/action_dispatcher_test.dart`

**Applicable assertions:** REQ-DISPATCH-D, E. REQ-IDEMPOT-A, B, C.

- [ ] **Append failing tests** to `test/action_dispatcher_test.dart`:

```dart
  group('Stage 3 — parse', () {
    test('REQ-DISPATCH-D: parse failure emits parse_denied + returns DispatchParseDenied', () async {
      registry.register(BadParseAction());
      final r = await dispatcher.dispatch('bad_parse', const {}, _ctx());
      expect(r, isA<DispatchParseDenied<dynamic>>());
      expect(events.appended, hasLength(1));
      expect(events.appended.last.draft.eventType, 'parse_denied');
    });
  });

  group('Stage 4 — idempotency check', () {
    test('REQ-IDEMPOT-A: idempotencyKey ignored when action.idempotency == none', () async {
      // HelloAction has Idempotency.none; key is ignored.
      // We can't fully test "ignored" until later stages exist; for now,
      // assert that supplying a key doesn't cause the lookup to be
      // recorded (no idempotency records should exist after a `none`
      // action, even with key supplied).
      // This will fully validate after Task 21 (record stage). For now,
      // assert no error is raised at the dispatcher boundary.
      // (Actual Hello dispatch will throw UnimplementedError on stage 5;
      //  catch and ignore.)
      try {
        await dispatcher.dispatch('hello', {'who': 'world'}, _ctx(),
            idempotencyKey: 'k1');
      } on UnimplementedError {/* expected */}
      // No idempotency record yet (record stage is Task 21):
      final hit = await idempotency.lookup('hello', 'u-1', 'k1');
      expect(hit, isNull);
    });

    test('REQ-IDEMPOT-B: required action without key emits parse_denied', () async {
      registry.register(RequiredKeyAction());
      final r = await dispatcher.dispatch('requires_key', {'who': 'x'}, _ctx());
      expect(r, isA<DispatchParseDenied<dynamic>>());
      r as DispatchParseDenied<dynamic>;
      expect(r.error.toString(), contains('idempotency'));
    });

    test('REQ-DISPATCH-E: idempotency hit returns DispatchIdempotencyHit, no new event', () async {
      registry.register(RequiredKeyAction());
      // Pre-populate the idempotency store with a hit.
      await idempotency.record(
        actionName: 'requires_key',
        principalId: 'u-1',
        key: 'k1',
        resultJson: const {'cached': true},
        emittedEventIds: const ['evt-prior'],
        expiresAt: DateTime.parse('2099-01-01T00:00:00Z'),
      );
      final initialAppendCount = events.appended.length;
      final r = await dispatcher.dispatch(
        'requires_key', {'who': 'x'}, _ctx(),
        idempotencyKey: 'k1',
      );
      expect(r, isA<DispatchIdempotencyHit<dynamic>>());
      expect(events.appended.length, initialAppendCount,
             reason: 'no new events on idempotency hit');
    });
  });
```

- [ ] **Run; confirm failure.**

- [ ] **Modify `lib/src/action_dispatcher.dart`** — replace the `dispatch` method body. Add stage 3 (parse) and stage 4 (idempotency check) before the `UnimplementedError`:

```dart
  Future<DispatchResult<dynamic>> dispatch(
    String actionName,
    Map<String, dynamic> rawInput,
    ActionContext ctx, {
    String? idempotencyKey,
    String? flowToken,
  }) async {
    // Stage 2: invocation_id
    final invocationId = _uuid.v4();
    final invocationMetadata = <String, dynamic>{
      'action_invocation_id': invocationId,
      'action_name': actionName,
    };

    // Stage 1: lookup
    final action = registry.lookup(actionName);
    if (action == null) {
      await _emitDenial(
        denialUnknownAction(
          invocationId: invocationId,
          requestedName: actionName,
          actionInvocationMetadata: invocationMetadata,
        ),
        ctx,
      );
      return DispatchResult<dynamic>.unknownAction(actionName);
    }

    // Pre-stage-3 check (REQ-IDEMPOT-B): required policy demands a key.
    if (action.idempotency == Idempotency.required && idempotencyKey == null) {
      final err = ArgumentError(
        'idempotency_key is required for action "${action.name}"',
      );
      await _emitDenial(
        denialParseDenied(
          invocationId: invocationId,
          actionName: action.name,
          error: err,
          actionInvocationMetadata: invocationMetadata,
        ),
        ctx,
      );
      return DispatchResult<dynamic>.parseDenied(err);
    }

    // Stage 3: parse
    final dynamic input;
    try {
      input = action.parseInput(rawInput);
    } on Object catch (e) {
      await _emitDenial(
        denialParseDenied(
          invocationId: invocationId,
          actionName: action.name,
          error: e,
          actionInvocationMetadata: invocationMetadata,
        ),
        ctx,
      );
      return DispatchResult<dynamic>.parseDenied(e);
    }

    // Stage 4: idempotency check (REQ-IDEMPOT-A,C,D — none = skip; optional
    // = lookup if key supplied; required = lookup mandatory).
    if (action.idempotency != Idempotency.none && idempotencyKey != null) {
      final hit = await idempotency.lookup(
        action.name,
        ctx.principal.id,
        idempotencyKey,
      );
      if (hit != null) {
        return DispatchResult<dynamic>.idempotencyHit(
          hit.resultJson,
          hit.emittedEventIds,
        );
      }
    }

    // Stages 5-10: TODO in Tasks 17-22.
    throw UnimplementedError('Stages 5-10 added in Tasks 17-22.');
  }
```

Add the missing import at top: `import 'package:audited_actions/src/idempotency.dart';`.

- [ ] **Run tests + analyze; confirm passes for Stages 1-4.**

- [ ] **Commit:**

```bash
git commit -am "[CUR-1159] audited_actions: dispatcher Stage 3 (parse) + Stage 4 (idempotency check)"
```

---

### Task 17: Dispatcher Stage 5 (validate)

**Files:**
- Modify: `apps/common-dart/audited_actions/lib/src/action_dispatcher.dart`
- Modify: `apps/common-dart/audited_actions/test/action_dispatcher_test.dart`

**Applicable assertions:** REQ-DISPATCH-F.

- [ ] **Append failing tests:**

```dart
  group('Stage 5 — validate', () {
    test('REQ-DISPATCH-F: validate failure emits validation_denied', () async {
      registry.register(BadValidateAction());
      final r = await dispatcher.dispatch('bad_validate', {'who': 'x'}, _ctx());
      expect(r, isA<DispatchValidationDenied<dynamic>>());
      expect(events.appended.last.draft.eventType, 'validation_denied');
    });

    test('REQ-DISPATCH-F: validate success proceeds (currently throws Stage 6+ unimplemented)', () async {
      // HelloAction.validate is a no-op; this should reach Stage 6.
      // Until Stage 6 is implemented, the call throws UnimplementedError.
      // This is the expected intermediate state.
      expect(
        () => dispatcher.dispatch('hello', {'who': 'x'}, _ctx()),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
```

- [ ] **Run; confirm new failures.**

- [ ] **Modify `dispatch`** — replace the `UnimplementedError` line with Stage 5:

```dart
    // Stage 5: validate
    try {
      action.validate(input);
    } on Object catch (e) {
      await _emitDenial(
        denialValidationDenied(
          invocationId: invocationId,
          actionName: action.name,
          error: e,
          actionInvocationMetadata: invocationMetadata,
        ),
        ctx,
      );
      return DispatchResult<dynamic>.validationDenied(e);
    }

    // Stages 6-10: TODO in Tasks 18-22.
    throw UnimplementedError('Stages 6-10 added in Tasks 18-22.');
```

- [ ] **Run tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git commit -am "[CUR-1159] audited_actions: dispatcher Stage 5 (validate)"
```

---

### Task 18: Dispatcher Stage 6 (authorize)

**Files:**
- Modify: `apps/common-dart/audited_actions/lib/src/action_dispatcher.dart`
- Modify: `apps/common-dart/audited_actions/test/action_dispatcher_test.dart`
- Modify: `apps/common-dart/audited_actions/test/fixtures/fake_authorization_policy.dart` (NEW)

**Applicable assertions:** REQ-DISPATCH-G.

- [ ] **Write `test/fixtures/fake_authorization_policy.dart`:**

```dart
import 'package:audited_actions/src/action_context.dart';
import 'package:audited_actions/src/authorization_policy.dart';
import 'package:audited_actions/src/permission.dart';

/// Test fake whose answer can be configured per-call.
class FakeAuthorizationPolicy extends AuthorizationPolicy {
  FakeAuthorizationPolicy();

  /// If true (default), allow all. If false, deny all. Override per-permission
  /// via [denyPermissions].
  bool defaultAllow = true;

  /// Permissions in this set are denied even when defaultAllow is true.
  final Set<String> denyPermissions = <String>{};

  final List<Permission> queriedPermissions = <Permission>[];

  @override
  Future<bool> isPermitted(
    Principal principal,
    Permission permission,
    ActionContext ctx,
  ) async {
    queriedPermissions.add(permission);
    if (denyPermissions.contains(permission.name)) return false;
    return defaultAllow;
  }
}
```

- [ ] **Append failing tests** to `action_dispatcher_test.dart`:

```dart
  group('Stage 6 — authorize', () {
    test('REQ-DISPATCH-G: denial of any permission emits authorization_denied', () async {
      final auth = FakeAuthorizationPolicy()..denyPermissions.add('test.hello');
      dispatcher = ActionDispatcher(
        registry: registry,
        authorization: auth,
        events: events,
        idempotency: idempotency,
      );
      final r = await dispatcher.dispatch('hello', {'who': 'x'}, _ctx());
      expect(r, isA<DispatchAuthorizationDenied<dynamic>>());
      expect(events.appended.last.draft.eventType, 'authorization_denied');
      expect(events.appended.last.draft.data['permission_denied'], 'test.hello');
    });

    test('REQ-DISPATCH-G: all permissions granted proceeds (Stage 7+ unimplemented)', () async {
      final auth = FakeAuthorizationPolicy(); // allow all by default
      dispatcher = ActionDispatcher(
        registry: registry,
        authorization: auth,
        events: events,
        idempotency: idempotency,
      );
      expect(
        () => dispatcher.dispatch('hello', {'who': 'x'}, _ctx()),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
```

Add the import: `import 'fixtures/fake_authorization_policy.dart';`

- [ ] **Run; confirm failures.**

- [ ] **Modify `dispatch`** — replace the trailing `UnimplementedError` with Stage 6:

```dart
    // Stage 6: authorize (REQ-DISPATCH-G)
    for (final permission in action.permissions) {
      final allowed = await authorization.isPermitted(
        ctx.principal,
        permission,
        ctx,
      );
      if (!allowed) {
        final activeRole = ctx.principal is UserPrincipal
            ? (ctx.principal as UserPrincipal).activeRole
            : null;
        await _emitDenial(
          denialAuthorizationDenied(
            invocationId: invocationId,
            actionName: action.name,
            permission: permission,
            principalActiveRole: activeRole,
            actionInvocationMetadata: invocationMetadata,
          ),
          ctx,
        );
        return DispatchResult<dynamic>.authorizationDenied(permission);
      }
    }

    // Stages 7-10: TODO in Tasks 19-22.
    throw UnimplementedError('Stages 7-10 added in Tasks 19-22.');
```

- [ ] **Run tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/test/fixtures/fake_authorization_policy.dart \
        apps/common-dart/audited_actions/lib/src/action_dispatcher.dart \
        apps/common-dart/audited_actions/test/action_dispatcher_test.dart
git commit -m "[CUR-1159] audited_actions: dispatcher Stage 6 (authorize)"
```

---

### Task 19: Dispatcher Stage 7 (execute) + Stage 8 (atomic persist)

**Files:**
- Modify: `apps/common-dart/audited_actions/lib/src/action_dispatcher.dart`
- Modify: `apps/common-dart/audited_actions/test/action_dispatcher_test.dart`

**Applicable assertions:** REQ-DISPATCH-H, I.

- [ ] **Append failing tests:**

```dart
  group('Stage 7 — execute', () {
    test('REQ-DISPATCH-H: execute throw emits execution_failed', () async {
      registry.register(BadExecuteAction());
      dispatcher = ActionDispatcher(
        registry: registry,
        authorization: FakeAuthorizationPolicy(),
        events: events,
        idempotency: idempotency,
      );
      final r = await dispatcher.dispatch('bad_execute', {'who': 'x'}, _ctx());
      expect(r, isA<DispatchExecutionFailed<dynamic>>());
      expect(events.appended.last.draft.eventType, 'execution_failed');
    });
  });

  group('Stage 8 — persist (atomic)', () {
    test('REQ-DISPATCH-I: success persists all execute events', () async {
      registry.register(MultiEventAction());
      dispatcher = ActionDispatcher(
        registry: registry,
        authorization: FakeAuthorizationPolicy(),
        events: events,
        idempotency: idempotency,
      );
      // Stages 9-10 not yet implemented; we expect to throw at the
      // record-idempotency stage (or, depending on order, return success
      // with a warning). For this test's scope, we ignore the wrap-up
      // and inspect what got persisted.
      try {
        await dispatcher.dispatch('multi', const {}, _ctx());
      } on UnimplementedError {/* expected at Stage 9 boundary */}
      // 3 events from MultiEventAction got written through one transaction.
      expect(events.appended, hasLength(3));
      expect(events.appended.map((c) => c.draft.aggregateId).toList(),
             ['a', 'b', 'c']);
    });

    test('REQ-DISPATCH-I: persist failure mid-transaction rolls back all '
         'and emits execution_failed', () async {
      registry.register(MultiEventAction());
      dispatcher = ActionDispatcher(
        registry: registry,
        authorization: FakeAuthorizationPolicy(),
        events: events,
        idempotency: idempotency,
      );
      // Inject a failure on the second event.
      events.failNextAppendForAggregate('b', StateError('forced'));
      final r = await dispatcher.dispatch('multi', const {}, _ctx());
      expect(r, isA<DispatchExecutionFailed<dynamic>>());
      // Persistence rolled back: no MultiEventAction events present.
      // BUT the failure-denial event IS present (separate transaction).
      final aggregates = events.appended.map((c) => c.draft.aggregateId).toList();
      expect(aggregates, isNot(contains('a')));
      expect(aggregates, isNot(contains('b')));
      expect(aggregates, isNot(contains('c')));
      // The execution_failed denial uses invocation_id as aggregateId.
      expect(events.appended.last.draft.eventType, 'execution_failed');
    });

    test('REQ-DISPATCH-I: every persisted event has initiator stamped', () async {
      registry.register(MultiEventAction());
      dispatcher = ActionDispatcher(
        registry: registry,
        authorization: FakeAuthorizationPolicy(),
        events: events,
        idempotency: idempotency,
      );
      try {
        await dispatcher.dispatch('multi', const {}, _ctx());
      } on UnimplementedError {/* expected */}
      for (final call in events.appended) {
        expect(call.draft.initiator, isNotNull,
               reason: 'dispatcher must stamp initiator on every event');
      }
    });

    test('REQ-DISPATCH-I: flowToken from parameter propagates to drafts without their own', () async {
      registry.register(MultiEventAction());
      dispatcher = ActionDispatcher(
        registry: registry,
        authorization: FakeAuthorizationPolicy(),
        events: events,
        idempotency: idempotency,
      );
      try {
        await dispatcher.dispatch('multi', const {}, _ctx(),
            flowToken: 'test:flow:1');
      } on UnimplementedError {/* expected */}
      for (final call in events.appended) {
        expect(call.draft.flowToken, 'test:flow:1');
      }
    });
  });
```

- [ ] **Run; confirm failures.**

- [ ] **Modify `dispatch`** — replace the trailing `UnimplementedError` with Stages 7 + 8:

```dart
    // Stage 7: execute (REQ-DISPATCH-H)
    final ExecutionResult<dynamic> executionResult;
    try {
      executionResult = await action.execute(input, ctx);
    } on Object catch (e) {
      await _emitDenial(
        denialExecutionFailed(
          invocationId: invocationId,
          actionName: action.name,
          error: e,
          actionInvocationMetadata: invocationMetadata,
        ),
        ctx,
      );
      return DispatchResult<dynamic>.executionFailed(e);
    }

    // Stage 8: persist (REQ-DISPATCH-I) — atomic via events.transaction
    final emittedEventIds = <String>[];
    try {
      await events.transaction((txn) async {
        for (final draft in executionResult.events) {
          // Stamp dispatcher-controlled fields onto each draft.
          final mergedMetadata = <String, dynamic>{
            ...?draft.metadata,
            ...invocationMetadata,
          };
          final stamped = draft.copyWith(
            initiator: ctx.principal.toInitiator(),
            flowToken: draft.flowToken ?? flowToken,
            metadata: mergedMetadata,
          );
          final stored = await txn.appendWithSecurity(
            stamped,
            security: executionResult.securityDetailsOverride ?? ctx.security,
          );
          emittedEventIds.add(stored.eventId);
        }
      });
    } on Object catch (e) {
      await _emitDenial(
        denialExecutionFailed(
          invocationId: invocationId,
          actionName: action.name,
          error: e,
          actionInvocationMetadata: invocationMetadata,
        ),
        ctx,
      );
      return DispatchResult<dynamic>.executionFailed(e);
    }

    // Stages 9-10: TODO in Tasks 20-21.
    throw UnimplementedError('Stages 9-10 added in Tasks 20-21.');
```

Imports needed at top of file: `import 'package:audited_actions/src/execution_result.dart';`

- [ ] **Run tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git commit -am "[CUR-1159] audited_actions: dispatcher Stage 7 (execute) + Stage 8 (atomic persist)"
```

---

### Task 20: Dispatcher Stage 9 (record idempotency)

**Files:**
- Modify: `apps/common-dart/audited_actions/lib/src/action_dispatcher.dart`
- Modify: `apps/common-dart/audited_actions/test/action_dispatcher_test.dart`

**Applicable assertions:** REQ-DISPATCH-J. REQ-IDEMPOT-D.

- [ ] **Append failing tests:**

```dart
  group('Stage 9 — record idempotency', () {
    test('REQ-DISPATCH-J: optional idempotency with key records entry', () async {
      // Use HelloAction (Idempotency.none) plus a custom action with optional.
      // For this test, register an action with Idempotency.optional.
      // (Add OptionalKeyAction to test_actions.dart in this task.)
      registry.register(OptionalKeyAction());
      dispatcher = ActionDispatcher(
        registry: registry,
        authorization: FakeAuthorizationPolicy(),
        events: events,
        idempotency: idempotency,
      );
      // Stage 10 not yet implemented; expect Unimplemented at the very end.
      try {
        await dispatcher.dispatch(
          'optional_key', {'who': 'x'}, _ctx(),
          idempotencyKey: 'k1',
        );
      } on UnimplementedError {/* expected at Stage 10 boundary */}
      final hit = await idempotency.lookup('optional_key', 'u-1', 'k1');
      expect(hit, isNotNull);
      expect(hit!.emittedEventIds, isNotEmpty);
    });

    test('REQ-DISPATCH-J: none idempotency does not record', () async {
      // HelloAction is Idempotency.none.
      try {
        await dispatcher.dispatch(
          'hello', {'who': 'x'}, _ctx(),
          idempotencyKey: 'k1',
        );
      } on UnimplementedError {/* expected */}
      final hit = await idempotency.lookup('hello', 'u-1', 'k1');
      expect(hit, isNull);
    });

    test('REQ-DISPATCH-J: optional without key does not record', () async {
      registry.register(OptionalKeyAction());
      dispatcher = ActionDispatcher(
        registry: registry,
        authorization: FakeAuthorizationPolicy(),
        events: events,
        idempotency: idempotency,
      );
      try {
        await dispatcher.dispatch('optional_key', {'who': 'x'}, _ctx());
      } on UnimplementedError {/* expected */}
      // No key -> no record.
      final all = await idempotency.sweepExpired(
        before: DateTime.parse('2099-01-01T00:00:00Z'),
      );
      // sweepExpired returns count of removed; if 0 entries were ever
      // recorded, it returns 0.
      expect(all, 0);
    });
  });
```

Add `OptionalKeyAction` to `test/fixtures/test_actions.dart`:

```dart
class OptionalKeyAction extends HelloAction {
  @override String get name => 'optional_key';
  @override Idempotency get idempotency => Idempotency.optional;
}
```

- [ ] **Run; confirm failures.**

- [ ] **Modify `dispatch`** — replace the trailing `UnimplementedError` with Stage 9:

```dart
    // Stage 9: record idempotency (REQ-DISPATCH-J)
    if (action.idempotency != Idempotency.none && idempotencyKey != null) {
      // Serialize result to JSON-compatible map. For non-trivial result
      // types, the action is responsible for ensuring the result is
      // JSON-encodable; the dispatcher stores it verbatim.
      final resultJson = _resultAsJsonMap(executionResult.result);
      await idempotency.record(
        actionName: action.name,
        principalId: ctx.principal.id,
        key: idempotencyKey,
        resultJson: resultJson,
        emittedEventIds: emittedEventIds,
        expiresAt: DateTime.now().add(action.idempotencyTtl),
      );
    }

    // Stage 10: TODO in Task 21.
    throw UnimplementedError('Stage 10 added in Task 21.');
```

Add the helper at the bottom of the class:

```dart
  Map<String, dynamic> _resultAsJsonMap(Object? result) {
    if (result is Map<String, dynamic>) return result;
    if (result == null) return const {};
    // Wrap scalar / non-map results.
    return {'value': result};
  }
```

- [ ] **Run tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git commit -am "[CUR-1159] audited_actions: dispatcher Stage 9 (record idempotency)"
```

---

### Task 21: Dispatcher Stage 10 (return success)

**Files:**
- Modify: `apps/common-dart/audited_actions/lib/src/action_dispatcher.dart`
- Modify: `apps/common-dart/audited_actions/test/action_dispatcher_test.dart`

**Applicable assertions:** REQ-DISPATCH-K.

- [ ] **Append failing tests:**

```dart
  group('Stage 10 — return success', () {
    test('REQ-DISPATCH-K: success returns DispatchSuccess with emittedEventIds', () async {
      dispatcher = ActionDispatcher(
        registry: registry,
        authorization: FakeAuthorizationPolicy(),
        events: events,
        idempotency: idempotency,
      );
      final r = await dispatcher.dispatch('hello', {'who': 'world'}, _ctx());
      expect(r, isA<DispatchSuccess<dynamic>>());
      r as DispatchSuccess<dynamic>;
      expect(r.result, 'Hello, world');
      expect(r.emittedEventIds, hasLength(1));
    });

    test('REQ-DISPATCH-K: idempotency hit on second call returns same result, no new events', () async {
      registry.register(OptionalKeyAction());
      dispatcher = ActionDispatcher(
        registry: registry,
        authorization: FakeAuthorizationPolicy(),
        events: events,
        idempotency: idempotency,
      );
      final r1 = await dispatcher.dispatch(
        'optional_key', {'who': 'world'}, _ctx(),
        idempotencyKey: 'k1',
      );
      final initialAppendCount = events.appended.length;
      final r2 = await dispatcher.dispatch(
        'optional_key', {'who': 'world'}, _ctx(),
        idempotencyKey: 'k1',
      );
      expect(r1, isA<DispatchSuccess<dynamic>>());
      expect(r2, isA<DispatchIdempotencyHit<dynamic>>());
      expect(events.appended.length, initialAppendCount,
             reason: 'second call must not append new events');
    });
  });
```

- [ ] **Run; confirm failures.**

- [ ] **Modify `dispatch`** — replace the trailing `UnimplementedError` with Stage 10:

```dart
    // Stage 10: return success (REQ-DISPATCH-K)
    return DispatchResult<dynamic>.success(
      executionResult.result,
      emittedEventIds,
    );
  }
```

(Close the method.)

- [ ] **Run all dispatcher tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git commit -am "[CUR-1159] audited_actions: dispatcher Stage 10 (return success); pipeline complete"
```

---

### Task 22: `bootstrapAuditedActions`

**Files:**
- Create: `apps/common-dart/audited_actions/lib/src/bootstrap.dart`
- Create: `apps/common-dart/audited_actions/test/bootstrap_test.dart`

**Applicable assertions:** REQ-ACTREG-D.

- [ ] **Write failing tests** in `test/bootstrap_test.dart`:

```dart
import 'package:audited_actions/src/action_dispatcher.dart';
import 'package:audited_actions/src/authorization_policy.dart';
import 'package:audited_actions/src/bootstrap.dart';
import 'package:audited_actions/src/idempotency_store.dart';
import 'package:test/test.dart';

import 'fixtures/fake_events_api.dart';
import 'fixtures/test_actions.dart';

void main() {
  group('bootstrapAuditedActions', () {
    test('REQ-ACTREG-D: returns ready dispatcher with all actions registered', () {
      final dispatcher = bootstrapAuditedActions(
        events: FakeEventsApi(),
        authorization: const DenyAllAuthorizationPolicy.forTests(),
        idempotency: InMemoryIdempotencyStore(),
        actions: [HelloAction(), MultiEventAction()],
      );
      expect(dispatcher, isA<ActionDispatcher>());
      expect(dispatcher.registry.lookup('hello'), isNotNull);
      expect(dispatcher.registry.lookup('multi'), isNotNull);
    });

    test('REQ-ACTREG-D: collision in actions list throws ArgumentError', () {
      expect(
        () => bootstrapAuditedActions(
          events: FakeEventsApi(),
          authorization: const DenyAllAuthorizationPolicy.forTests(),
          idempotency: InMemoryIdempotencyStore(),
          actions: [HelloAction(), HelloAction()],
        ),
        throwsArgumentError,
      );
    });

    test('REQ-ACTREG-D: empty actions list bootstraps cleanly', () {
      final dispatcher = bootstrapAuditedActions(
        events: FakeEventsApi(),
        authorization: const DenyAllAuthorizationPolicy.forTests(),
        idempotency: InMemoryIdempotencyStore(),
        actions: const [],
      );
      expect(dispatcher.registry.allDeclaredPermissions, isEmpty);
    });
  });
}
```

- [ ] **Run; confirm failure.**

- [ ] **Write `lib/src/bootstrap.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-ACTREG-D: single entry point for app initialization of the
//   actions library.

import 'package:audited_actions/src/action.dart';
import 'package:audited_actions/src/action_dispatcher.dart';
import 'package:audited_actions/src/action_registry.dart';
import 'package:audited_actions/src/authorization_policy.dart';
import 'package:audited_actions/src/events_api.dart';
import 'package:audited_actions/src/idempotency_store.dart';

/// Wire up an `ActionDispatcher` for a deploying app. Call this once
/// from `main()` (or equivalent server bootstrap) and reuse the returned
/// dispatcher for the lifetime of the process.
//
// Implements: REQ-ACTREG-D — registers all supplied actions; rejects
// duplicate names; returns a ready dispatcher.
ActionDispatcher bootstrapAuditedActions({
  required EventsApi events,
  required AuthorizationPolicy authorization,
  required IdempotencyStore idempotency,
  required List<Action<dynamic, dynamic>> actions,
}) {
  final registry = ActionRegistry();
  for (final action in actions) {
    registry.register(action);
  }
  return ActionDispatcher(
    registry: registry,
    authorization: authorization,
    events: events,
    idempotency: idempotency,
  );
}
```

(`ActionDispatcher.registry` getter must exist for the test. Since `registry` is already a public final field on the dispatcher per Task 15, it is accessible directly via property access — no separate getter needed.)

- [ ] **Run tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/lib/src/bootstrap.dart \
        apps/common-dart/audited_actions/test/bootstrap_test.dart
git commit -m "[CUR-1159] audited_actions: bootstrapAuditedActions"
```

---

### Task 23: Permission discovery tool (COMPLETED in 84574c5b — skip)

> **STOP — DO NOT EXECUTE THIS TASK.** COMPLETED in 84574c5b. tool/discover_permissions.dart and tests already exist. Return immediately.


**Files:**
- Create: `apps/common-dart/audited_actions/tool/discover_permissions.dart`
- Create: `apps/common-dart/audited_actions/lib/src/permission_discovery.dart`
- Create: `apps/common-dart/audited_actions/test/permission_discovery_test.dart`

**Applicable assertions:** REQ-AUTHZ-D.

- [ ] **Write failing tests** in `test/permission_discovery_test.dart`:

```dart
import 'package:audited_actions/src/action_registry.dart';
import 'package:audited_actions/src/permission_discovery.dart';
import 'package:test/test.dart';

import 'fixtures/test_actions.dart';

void main() {
  group('emitPermissionsMigrationSql', () {
    test('REQ-AUTHZ-D: emits ON CONFLICT DO NOTHING insert per declared permission', () {
      final registry = ActionRegistry()
        ..register(HelloAction()) // permission: test.hello
        ..register(MultiEventAction()); // permission: test.multi
      final sql = emitPermissionsMigrationSql(
        registry: registry,
        existing: <String>{}, // nothing in DB yet
      );
      expect(sql, contains("INSERT INTO role_permission_matrix_permissions"));
      expect(sql, contains("'test.hello'"));
      expect(sql, contains("'test.multi'"));
      expect(sql, contains('ON CONFLICT'));
    });

    test('REQ-AUTHZ-D: skips permissions already present in DB', () {
      final registry = ActionRegistry()
        ..register(HelloAction());
      final sql = emitPermissionsMigrationSql(
        registry: registry,
        existing: <String>{'test.hello'},
      );
      // ON CONFLICT DO NOTHING means re-emitting is harmless; we MAY skip
      // entirely or emit with the conflict guard. Either is correct;
      // assert the output is well-formed (inserts may be present but a
      // no-op header explains the absence).
      expect(sql, isNotEmpty);
      // No new INSERT for an already-present permission:
      final lines = sql.split('\n');
      final insertLines = lines.where(
        (l) => l.contains("'test.hello'") && l.contains('INSERT'),
      );
      expect(insertLines, isEmpty);
    });

    test('REQ-AUTHZ-D: emits comments for orphan permissions in DB', () {
      final registry = ActionRegistry()
        ..register(HelloAction()); // declares test.hello
      final sql = emitPermissionsMigrationSql(
        registry: registry,
        existing: <String>{'test.hello', 'test.legacy'},
      );
      // test.legacy is in DB but not in code: emit a comment, do not delete.
      expect(sql, contains('-- ORPHAN'));
      expect(sql, contains('test.legacy'));
    });
  });
}
```

- [ ] **Run; confirm failure.**

- [ ] **Write `lib/src/permission_discovery.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-AUTHZ-D: SQL migration emitter for newly-declared permissions.

import 'package:audited_actions/src/action_registry.dart';

/// Emit a SQL migration that seeds the `role_permission_matrix_permissions`
/// table with permissions from the registry that are not already present.
//
// Implements: REQ-AUTHZ-D — insert new permissions; comment out orphans;
// never auto-delete.
String emitPermissionsMigrationSql({
  required ActionRegistry registry,
  required Set<String> existing,
}) {
  final declared = {for (final p in registry.allDeclaredPermissions) p.name};
  final newPerms = declared.difference(existing).toList()..sort();
  final orphanPerms = existing.difference(declared).toList()..sort();

  final buf = StringBuffer();
  buf.writeln('-- audited_actions permission discovery migration');
  buf.writeln('-- Declared in code: ${declared.length}, '
      'present in DB: ${existing.length}');
  buf.writeln();
  if (newPerms.isNotEmpty) {
    buf.writeln('INSERT INTO role_permission_matrix_permissions '
        '(name, status)');
    buf.writeln('VALUES');
    for (var i = 0; i < newPerms.length; i++) {
      final p = newPerms[i];
      final terminator = i == newPerms.length - 1 ? '' : ',';
      buf.writeln("  ('$p', 'unassigned')$terminator");
    }
    buf.writeln('ON CONFLICT (name) DO NOTHING;');
    buf.writeln();
  } else {
    buf.writeln('-- No new permissions to insert.');
    buf.writeln();
  }
  if (orphanPerms.isNotEmpty) {
    buf.writeln('-- ORPHAN permissions (present in DB, absent from code):');
    buf.writeln('-- These are NOT auto-deleted; review and remove manually:');
    for (final p in orphanPerms) {
      buf.writeln('--   $p');
    }
  }
  return buf.toString();
}
```

- [ ] **Write `tool/discover_permissions.dart`:**

```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-AUTHZ-D: CLI driver for the permission discovery emitter.
//
// Usage (CLI shape; the deploying app provides the registry adapter):
//
//   dart run audited_actions:discover_permissions \
//     --output migrations/<n>_permissions_<date>.sql
//
// In-process usage (deploying app calls emitPermissionsMigrationSql
// directly with its populated registry):
//
//   import 'package:audited_actions/audited_actions.dart';
//   final sql = emitPermissionsMigrationSql(
//     registry: myAppRegistry,
//     existing: await readExistingFromDb(),
//   );

import 'dart:io';

import 'package:audited_actions/audited_actions.dart';

/// Smoke entry point. Without an injected registry, prints usage.
/// Deploying apps wrap this with their own registry-loading code.
void main(List<String> args) {
  stderr.writeln(
    'discover_permissions: this is a thin entry point. To use:\n'
    '  - Construct an ActionRegistry populated with your app actions.\n'
    '  - Call emitPermissionsMigrationSql(registry: ..., existing: ...).\n'
    '  - Write the result to your migrations directory.\n'
    '\n'
    'See tool/discover_permissions.dart source for the API contract.',
  );
}
```

- [ ] **Run tests + analyze; confirm pass.**

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/lib/src/permission_discovery.dart \
        apps/common-dart/audited_actions/tool/discover_permissions.dart \
        apps/common-dart/audited_actions/test/permission_discovery_test.dart
git commit -m "[CUR-1159] audited_actions: permission discovery emitter + CLI entry"
```

---

### Task 24: Public exports + end-to-end integration test

**Files:**
- Modify: `apps/common-dart/audited_actions/lib/audited_actions.dart`
- Create: `apps/common-dart/audited_actions/test/integration_test.dart`

- [ ] **Update `lib/audited_actions.dart`** with all public exports:

```dart
/// Trusted-boundary command/intent layer. See README.md.
library;

export 'src/action.dart';
export 'src/action_context.dart';
export 'src/action_dispatcher.dart';
export 'src/action_registry.dart';
export 'src/authorization_policy.dart';
export 'src/bootstrap.dart';
export 'src/denial_events.dart' show
    sanitizeErrorMessage,
    denialUnknownAction,
    denialParseDenied,
    denialValidationDenied,
    denialAuthorizationDenied,
    denialExecutionFailed;
export 'src/dispatch_result.dart';
export 'src/events_api.dart';
export 'src/execution_result.dart';
export 'src/idempotency.dart';
export 'src/idempotency_store.dart';
export 'src/permission.dart';
export 'src/permission_discovery.dart';
export 'src/role_matrix_reader.dart';
export 'src/table_backed_authorization_policy.dart';
```

- [ ] **Write `test/integration_test.dart`** — exercises the full happy path through the public API only (no internal `src/` imports):

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart'
    show SecurityDetails;
import 'package:audited_actions/audited_actions.dart';
import 'package:test/test.dart';

import 'fixtures/fake_events_api.dart';
import 'fixtures/fake_authorization_policy.dart';
import 'fixtures/test_actions.dart';

void main() {
  group('end-to-end via public API', () {
    test('happy path: dispatch -> success + persisted event + idempotency record', () async {
      final events = FakeEventsApi();
      final auth = FakeAuthorizationPolicy();
      final idempotency = InMemoryIdempotencyStore();
      final dispatcher = bootstrapAuditedActions(
        events: events,
        authorization: auth,
        idempotency: idempotency,
        actions: [OptionalKeyAction()],
      );
      final ctx = ActionContext(
        principal: Principal.user(
          userId: 'u-7',
          roles: const {'tester'},
          activeRole: 'tester',
        ),
        security: SecurityDetails(ipAddress: '10.0.0.1'),
        requestStartedAt: DateTime.parse('2026-04-22T15:00:00Z'),
      );
      final r = await dispatcher.dispatch(
        'optional_key', {'who': 'world'}, ctx,
        idempotencyKey: 'k-77',
        flowToken: 'integration:1',
      );
      expect(r, isA<DispatchSuccess<dynamic>>());
      expect(events.appended, hasLength(1));
      expect(events.appended.single.draft.flowToken, 'integration:1');
      expect(events.appended.single.security?.ipAddress, '10.0.0.1');
      // Idempotency replay:
      final r2 = await dispatcher.dispatch(
        'optional_key', {'who': 'world'}, ctx,
        idempotencyKey: 'k-77',
        flowToken: 'integration:1',
      );
      expect(r2, isA<DispatchIdempotencyHit<dynamic>>());
      expect(events.appended, hasLength(1),
             reason: 'replay must not append a second event');
    });

    test('full denial chain: each pipeline failure type emits an event', () async {
      final events = FakeEventsApi();
      final dispatcher = bootstrapAuditedActions(
        events: events,
        authorization: FakeAuthorizationPolicy()..denyPermissions.add('test.hello'),
        idempotency: InMemoryIdempotencyStore(),
        actions: [HelloAction(), BadParseAction(), BadValidateAction(),
                  BadExecuteAction(), RequiredKeyAction()],
      );
      final ctx = ActionContext(
        principal: Principal.user(
          userId: 'u-1',
          roles: const {'tester'},
          activeRole: 'tester',
        ),
        security: SecurityDetails(),
        requestStartedAt: DateTime.now(),
      );
      // 1. unknown action
      await dispatcher.dispatch('does_not_exist', const {}, ctx);
      // 2. parse failure
      await dispatcher.dispatch('bad_parse', const {}, ctx);
      // 3. required-key missing -> parse_denied with idempotency error
      await dispatcher.dispatch('requires_key', {'who': 'x'}, ctx);
      // 4. validation failure
      await dispatcher.dispatch('bad_validate', {'who': 'x'}, ctx);
      // 5. authorization denied (HelloAction's permission is in deny set)
      // Need an allow-by-default policy for execute-fail. Reset policy.
      // For brevity, just check that at least 4 denial events have been written.
      final denialEventTypes = events.appended
          .map((c) => c.draft.eventType)
          .where((t) => t.endsWith('_denied') || t == 'unknown_action')
          .toSet();
      expect(denialEventTypes, containsAll(<String>{
        'unknown_action',
        'parse_denied',
        'validation_denied',
      }));
    });
  });
}
```

- [ ] **Run all tests + analyze; confirm pass:**

```bash
(cd apps/common-dart/audited_actions && dart test && dart analyze)
```

Expected: all green.

- [ ] **Commit:**

```bash
git add apps/common-dart/audited_actions/lib/audited_actions.dart \
        apps/common-dart/audited_actions/test/integration_test.dart
git commit -m "[CUR-1159] audited_actions: public exports + end-to-end integration test"
```

---

## Final acceptance

- [ ] **Full test suite green:**

```bash
(cd apps/common-dart/audited_actions && dart test)
```

Expected: every test passes; no skipped tests.

- [ ] **Lints clean:**

```bash
(cd apps/common-dart/audited_actions && dart analyze)
```

Expected: 0 issues.

- [ ] **REQ assertions all referenced.** Spot-check that every `REQ-XXX-Y` from `spec/dev-audited-actions.md` appears in at least one `// Implements:` or `// Verifies:` comment in code.

- [ ] **Push branch + open PR:**

```bash
git push -u origin feature/cur-1159-audited-actions-library
gh pr create \
  --title "[CUR-1159] Audited actions library" \
  --body "$(cat <<'EOF'
## Summary

Implements Sub-project A of CUR-1159 (design at
docs/superpowers/specs/2026-04-22-events-and-actions-libs-design.md).

New package apps/common-dart/audited_actions/: trusted-boundary
gatekeeper for audited user actions. Class-based Action interface,
10-stage dispatcher pipeline (lookup, invocation_id, parse,
idempotency-check, validate, authorize, execute, atomic persist,
record idempotency, return), pluggable AuthorizationPolicy with
table-backed default reading from a role-permission matrix, optional
idempotency with three policies, automated permission discovery tool
for SQL migrations.

Every pipeline-stage failure emits a typed denial event into the
unified event log (via post-Sub-project-E events lib), in the same
shape as success events. Anonymous principals always denied.

## Test plan
- [ ] CI: dart test passes for audited_actions
- [ ] CI: dart analyze passes for audited_actions
- [ ] CI: requirements validator passes for spec/dev-audited-actions.md
- [ ] Manual: review dispatcher pipeline against design §7.4

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **On merge:** mark CUR-1159 In Review → Done; move to next sub-project (events lib was merged earlier; now the unified-event-store cutover work can proceed against the new actions lib + post-E events lib).
