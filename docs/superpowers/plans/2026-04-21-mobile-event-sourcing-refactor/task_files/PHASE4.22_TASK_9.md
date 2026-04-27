# Phase 4.22 Task 9 — Demo per-pane install UUID (REQ-d00142-D demonstration)

## Goal

The example app is the only consumer of this library. Until Task 9, it hardcoded `Source.identifier` to `'demo-device'` (mobile pane) and `'demo-portal'` (portal pane). REQ-d00142-D requires `Source.identifier` to be a per-installation globally-unique value (UUIDv4 recommended). The example violated that contract; Task 9 fixes it by minting + persisting per-pane `UUIDv4`s on first boot and reading them on every subsequent boot.

While here, the example's portal `Source.hopId` was aligned to the REQ-d00142-B canonical enumeration (`'mobile-device'`, `'portal-server'`); the example previously used `'portal'` for the portal pane.

## Implementation

### Step 1 — Add `_readOrMintUUID` helper + boot-time UUID assembly

`apps/common-dart/event_sourcing_datastore/example/lib/main.dart`:

- New helper near the top of the file:

```dart
/// Reads a persisted install UUID from [path], or mints + persists a new
/// UUIDv4 if the file does not exist.
// Implements: REQ-d00142-D — demo demonstrates per-installation unique
//   identity by persisting a UUIDv4 per pane to disk on first boot and
//   reading the same value on every subsequent boot.
Future<String> _readOrMintUUID(String path) async {
  final f = File(path);
  try {
    return (await f.readAsString()).trim();
  } on PathNotFoundException {
    final id = const Uuid().v4();
    await f.writeAsString(id);
    return id;
  }
}
```

- In `main()`, immediately after `await demoDir.create(recursive: true);`:

```dart
final mobileInstallUUID = await _readOrMintUUID(
  p.join(demoDir.path, 'MOBILE.install.uuid'),
);
final portalInstallUUID = await _readOrMintUUID(
  p.join(demoDir.path, 'PORTAL.install.uuid'),
);
```

- Both UUIDs are echoed to stdout alongside the storage paths for visibility.

- The two `_bootstrapPane` calls construct `Source` with the read/minted UUIDs (no longer `const`):

```dart
source: Source(
  hopId: 'portal-server',  // REQ-d00142-B canonical
  identifier: portalInstallUUID,
  softwareVersion: 'event_sourcing_datastore_demo@0.1.0+1',
),
```

```dart
source: Source(
  hopId: 'mobile-device',
  identifier: mobileInstallUUID,
  softwareVersion: 'event_sourcing_datastore_demo@0.1.0+1',
),
```

- Added `import 'package:uuid/uuid.dart';` (already in `pubspec.yaml` at `^4.5.2`).

### Step 2 — Lint fix: avoid_slow_async_io

The first cut used `if (await f.exists()) { ... } else { ... }`, which `flutter analyze` flagged as `avoid_slow_async_io`. Replaced the existence check with a `try { readAsString } on PathNotFoundException { mint + write }` pattern. This also makes the common (already-installed) path one `readAsString` rather than `exists` + `readAsString` — common-fast-rare-possible.

### Step 3 — Update tests that hardcoded `'demo-device'` / `'demo-portal'`

`grep` revealed exactly four test files using these strings as `Source.identifier`. None asserted on the specific identifier value (so no test was a bug exposing implementation detail); they all just constructed Sources for two-pane sync setups. Updated each to use deterministic UUID literals so test diagnostics stay readable:

- portal pane: `'11111111-1111-4111-8111-111111111111'`
- mobile pane: `'22222222-2222-4222-8222-222222222222'`

Files touched:

- `example/test/portal_sync_test.dart` — 3 test setups (`Source(portal=...)` x3 + `Source(mobile=...)` x3); hopId `'portal'` -> `'portal-server'` x3; one provenance hops assertion updated to expect `'portal-server'`.
- `example/test/portal_soak_test.dart` — 1 test setup; hopId; one provenance hops assertion (and its reason-string literal).
- `example/test/downstream_bridge_test.dart` — 1 helper (`_bootstrapPortal`).
- `example/integration_test/dual_pane_test.dart` — 1 helper (`_setupDualApp`).

`example/test/app_state_test.dart` already uses `'demo-test'` (not `'demo-device'`/`'demo-portal'`) and required no change.

### Step 4 — Verification

```text
$ (cd apps/common-dart/event_sourcing_datastore/example && flutter test ...)
01:05 +81: All tests passed!

$ (cd apps/common-dart/event_sourcing_datastore/example && flutter analyze ...)
No issues found! (ran in 0.7s)

$ (cd apps/common-dart/event_sourcing_datastore && flutter test ...)
00:07 +703: All tests passed!
```

- example test count: 81 -> 81 (Task 1 baseline preserved).
- lib test count: 703 -> 703 (Task 8 count preserved — Task 9 is example-only).

## Files Touched

### lib/

- `apps/common-dart/event_sourcing_datastore/example/lib/main.dart` — `_readOrMintUUID` helper added; UUID-driven Source construction; portal hopId aligned to `'portal-server'`; uuid import added.

### test/ + integration_test/

- `apps/common-dart/event_sourcing_datastore/example/test/portal_sync_test.dart`
- `apps/common-dart/event_sourcing_datastore/example/test/portal_soak_test.dart`
- `apps/common-dart/event_sourcing_datastore/example/test/downstream_bridge_test.dart`
- `apps/common-dart/event_sourcing_datastore/example/integration_test/dual_pane_test.dart`

### worklog / task file

- `PHASE_4.22_WORKLOG.md` — Task 9 checkbox flipped; Task 9 details section appended.
- This file (`PHASE4.22_TASK_9.md`).

## Outcome

The example app now demonstrates the REQ-d00142-D contract: each pane's `Source.identifier` is a per-installation `UUIDv4` persisted to the demo's app-support directory on first boot. Stdout on every run prints both UUIDs, so a user re-running the demo can confirm the values are stable across boots. All hardcoded `'demo-device'` / `'demo-portal'` strings are gone from the example app (lib/, test/, integration_test/) — verified via `grep`.

REQ-d00142-B canonical hopId values now hold throughout the example: `'mobile-device'` for the mobile pane, `'portal-server'` for the portal pane.
