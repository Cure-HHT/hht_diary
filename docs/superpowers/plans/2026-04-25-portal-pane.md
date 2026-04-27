# Portal Pane Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a second `AppendOnlyDatastore` instance to the `event_sourcing_datastore` example, rendered as a "portal" pane below the existing "mobile" pane, with one-way wire sync from mobile's `Native` destination to the portal via `EventStore.ingestBatch`.

**Architecture:** One Flutter process. One `MaterialApp`. Two datastores (separate sembast DBs). Mobile's `NativeDemoDestination.send()` is extended with an optional `DownstreamBridge` that calls `portal.eventStore.ingestBatch(payload.bytes, wireFormat: payload.contentType)` and maps the result back to a `SendResult`. Portal pane runs the existing demo UI unchanged, wired to its own datastore. Existing connection/latency knobs simulate link failure.

**Tech Stack:** Dart 3.10 / Flutter 3.38, sembast (file + memory factories), `event_sourcing_datastore` library (already exposes `EventStore.ingestBatch`, `WirePayload`, `Source`, `BatchEnvelope.wireFormat = 'esd/batch@1'`), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-04-25-portal-pane-design.md`

**Working directory for all relative paths below:** `apps/common-dart/event_sourcing_datastore/example`

---

## Task 1: `DownstreamBridge` value type

**Files:**
- Create: `apps/common-dart/event_sourcing_datastore/example/lib/downstream_bridge.dart`
- Test: `apps/common-dart/event_sourcing_datastore/example/test/downstream_bridge_test.dart`

The bridge is a thin adapter that calls a target `EventStore.ingestBatch` and maps `IngestBatchResult` / thrown ingest errors to a `SendResult`. Pure glue — no state, no Flutter, no UI.

- [ ] **Step 1: Write the failing tests**

Create `apps/common-dart/event_sourcing_datastore/example/test/downstream_bridge_test.dart`:

```dart
import 'dart:typed_data';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/demo_types.dart';
import 'package:event_sourcing_datastore_demo/downstream_bridge.dart';
import 'package:event_sourcing_datastore_demo/synthetic_ingest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<AppendOnlyDatastore> _bootstrapPortal(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  final backend = SembastBackend(database: db);
  return bootstrapAppendOnlyDatastore(
    backend: backend,
    source: const Source(
      hopId: 'portal',
      identifier: 'demo-portal',
      softwareVersion: 'event_sourcing_datastore_demo@0.1.0+1',
    ),
    entryTypes: allDemoEntryTypes,
    destinations: const <Destination>[],
    materializers: const <Materializer>[DiaryEntriesMaterializer()],
  );
}

WirePayload _wirePayload(Uint8List bytes) => WirePayload(
      bytes: bytes,
      contentType: BatchEnvelope.wireFormat,
      transformVersion: null,
    );

void main() {
  var pathCounter = 0;
  String nextPath() => 'bridge-${++pathCounter}.db';

  group('DownstreamBridge.deliver', () {
    test('valid esd/batch@1 envelope returns SendOk', () async {
      final portal = await _bootstrapPortal(nextPath());
      final bridge = DownstreamBridge(portal.eventStore);
      final envelope = SyntheticBatchBuilder().buildSingleEventBatch();
      final result = await bridge.deliver(_wirePayload(envelope.encode()));
      expect(result, isA<SendOk>());
    });

    test('garbage bytes return SendPermanent (decode failure)', () async {
      final portal = await _bootstrapPortal(nextPath());
      final bridge = DownstreamBridge(portal.eventStore);
      final result = await bridge.deliver(
        _wirePayload(Uint8List.fromList(<int>[0, 1, 2, 3])),
      );
      expect(result, isA<SendPermanent>());
    });

    test('unsupported wireFormat returns SendPermanent', () async {
      final portal = await _bootstrapPortal(nextPath());
      final bridge = DownstreamBridge(portal.eventStore);
      final envelope = SyntheticBatchBuilder().buildSingleEventBatch();
      final payload = WirePayload(
        bytes: envelope.encode(),
        contentType: 'application/x-unknown',
        transformVersion: null,
      );
      final result = await bridge.deliver(payload);
      expect(result, isA<SendPermanent>());
    });

    test('thrown StateError maps to SendTransient', () async {
      final bridge = DownstreamBridge(_ThrowingEventStore());
      final envelope = SyntheticBatchBuilder().buildSingleEventBatch();
      final result = await bridge.deliver(_wirePayload(envelope.encode()));
      expect(result, isA<SendTransient>());
    });
  });
}

class _ThrowingEventStore implements EventStore {
  @override
  Future<IngestBatchResult> ingestBatch(
    Uint8List bytes, {
    required String wireFormat,
  }) {
    throw StateError('boom');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `(cd apps/common-dart/event_sourcing_datastore/example && flutter test test/downstream_bridge_test.dart)`
Expected: FAIL — `Target of URI doesn't exist: 'package:event_sourcing_datastore_demo/downstream_bridge.dart'` (or similar import error).

- [ ] **Step 3: Write the bridge implementation**

Create `apps/common-dart/event_sourcing_datastore/example/lib/downstream_bridge.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';

/// In-memory bridge from one datastore's outgoing `Native` wire payload
/// to another datastore's [EventStore.ingestBatch]. Demo-only glue used
/// by the dual-pane example to wire the mobile pane's outgoing native
/// stream into the portal pane.
///
/// Maps [EventStore.ingestBatch] outcomes to [SendResult]:
/// - success ([IngestBatchResult]) → [SendOk] (per-event partial outcomes
///   are the receiver's concern, observable on the receiver's audit panel)
/// - [IngestDecodeFailure] / [IngestIdentityMismatch] / [IngestChainBroken]
///   → [SendPermanent] (won't fix on retry)
/// - any other thrown exception → [SendTransient] (treat unknowns as
///   recoverable so drain retries on the next tick)
class DownstreamBridge {
  const DownstreamBridge(this._target);
  final EventStore _target;

  Future<SendResult> deliver(WirePayload payload) async {
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
    } catch (e) {
      return SendTransient(error: e.toString());
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `(cd apps/common-dart/event_sourcing_datastore/example && flutter test test/downstream_bridge_test.dart)`
Expected: PASS — 4 tests.

- [ ] **Step 5: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/example/lib/downstream_bridge.dart \
        apps/common-dart/event_sourcing_datastore/example/test/downstream_bridge_test.dart
git commit -m "$(cat <<'EOF'
[CUR-1154] example: DownstreamBridge maps ingestBatch results to SendResult

In-memory adapter from a Native destination's WirePayload to a downstream
EventStore.ingestBatch. Decode/identity/chain errors map to SendPermanent;
unknown exceptions to SendTransient; success to SendOk. Foundation for the
two-datastore portal pane demo.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `NativeDemoDestination` accepts an optional bridge

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/native_demo_destination.dart`
- Test: `apps/common-dart/event_sourcing_datastore/example/test/native_demo_destination_test.dart` (new)

When `connection == ok` and a bridge is wired, `send()` delegates to the bridge after the existing latency delay. When `connection != ok` the bridge is NOT called — link-level failure is simulated upstream of the bridge.

- [ ] **Step 1: Write the failing tests**

Create `apps/common-dart/event_sourcing_datastore/example/test/native_demo_destination_test.dart`:

```dart
import 'dart:typed_data';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/demo_destination.dart';
import 'package:event_sourcing_datastore_demo/downstream_bridge.dart';
import 'package:event_sourcing_datastore_demo/native_demo_destination.dart';
import 'package:flutter_test/flutter_test.dart';

WirePayload _payload() => WirePayload(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      contentType: BatchEnvelope.wireFormat,
      transformVersion: null,
    );

class _SpyBridge implements DownstreamBridge {
  _SpyBridge(this._result);
  final SendResult _result;
  int callCount = 0;

  @override
  Future<SendResult> deliver(WirePayload payload) async {
    callCount++;
    return _result;
  }

  @override
  // ignore: unused_element
  EventStore get _target => throw UnimplementedError();
}

void main() {
  group('NativeDemoDestination.send with optional bridge', () {
    test('connection=ok, bridge=null → SendOk (regression)', () async {
      final d = NativeDemoDestination();
      final result = await d.send(_payload());
      expect(result, isA<SendOk>());
    });

    test('connection=ok, bridge returns SendOk → SendOk', () async {
      final spy = _SpyBridge(const SendOk());
      final d = NativeDemoDestination(bridge: spy);
      final result = await d.send(_payload());
      expect(result, isA<SendOk>());
      expect(spy.callCount, 1);
    });

    test('connection=ok, bridge returns SendPermanent → SendPermanent', () async {
      final spy = _SpyBridge(const SendPermanent(error: 'decode bad'));
      final d = NativeDemoDestination(bridge: spy);
      final result = await d.send(_payload());
      expect(result, isA<SendPermanent>());
      expect((result as SendPermanent).error, 'decode bad');
      expect(spy.callCount, 1);
    });

    test('connection=broken, bridge wired → SendTransient, bridge not called', () async {
      final spy = _SpyBridge(const SendOk());
      final d = NativeDemoDestination(
        bridge: spy,
        initialConnection: Connection.broken,
      );
      final result = await d.send(_payload());
      expect(result, isA<SendTransient>());
      expect(spy.callCount, 0);
    });

    test('connection=rejecting, bridge wired → SendPermanent, bridge not called', () async {
      final spy = _SpyBridge(const SendOk());
      final d = NativeDemoDestination(
        bridge: spy,
        initialConnection: Connection.rejecting,
      );
      final result = await d.send(_payload());
      expect(result, isA<SendPermanent>());
      expect(spy.callCount, 0);
    });

    test('sendLatency is awaited before bridge is called', () async {
      final spy = _SpyBridge(const SendOk());
      final d = NativeDemoDestination(
        bridge: spy,
        initialSendLatency: const Duration(milliseconds: 40),
      );
      final stopwatch = Stopwatch()..start();
      await d.send(_payload());
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(30));
      expect(spy.callCount, 1);
    });
  });
}
```

The `_SpyBridge` declares `_target` to satisfy the implements contract; the field is never read because `deliver` is overridden. The `// ignore` suppresses the unused-element lint.

- [ ] **Step 2: Run tests to verify they fail**

Run: `(cd apps/common-dart/event_sourcing_datastore/example && flutter test test/native_demo_destination_test.dart)`
Expected: FAIL — `bridge` is not a known parameter on `NativeDemoDestination`.

- [ ] **Step 3: Modify `NativeDemoDestination`**

Edit `apps/common-dart/event_sourcing_datastore/example/lib/native_demo_destination.dart`:

Add a new import at the top (after existing imports):

```dart
import 'package:event_sourcing_datastore_demo/downstream_bridge.dart';
```

Modify the constructor to accept the optional bridge:

```dart
NativeDemoDestination({
  this.id = 'Native',
  this.filter = const SubscriptionFilter(),
  this.allowHardDelete = false,
  Duration initialSendLatency = Duration.zero,
  int initialBatchSize = 10,
  Duration initialAccumulate = Duration.zero,
  Connection initialConnection = Connection.ok,
  DownstreamBridge? bridge,
})  : connection = ValueNotifier<Connection>(initialConnection),
      sendLatency = ValueNotifier<Duration>(initialSendLatency),
      batchSize = ValueNotifier<int>(initialBatchSize),
      maxAccumulateTimeN = ValueNotifier<Duration>(initialAccumulate),
      _bridge = bridge;

final DownstreamBridge? _bridge;
```

Replace the existing `send` method body:

```dart
@override
Future<SendResult> send(WirePayload payload) async {
  switch (connection.value) {
    case Connection.ok:
      await Future<void>.delayed(sendLatency.value);
      final bridge = _bridge;
      if (bridge != null) {
        return bridge.deliver(payload);
      }
      return const SendOk();
    case Connection.broken:
      return const SendTransient(error: 'simulated disconnect');
    case Connection.rejecting:
      return const SendPermanent(error: 'simulated rejection');
  }
}
```

Update the dartdoc on the class (just above `class NativeDemoDestination`) — add a sentence describing the bridge. Replace the existing top doc-comment block with:

```dart
/// Native demo destination — declares it speaks `esd/batch@1` so the
/// library handles serialization itself (Phase 4.14 REQ-d00152). FIFO
/// rows for this destination store envelope metadata + null wire_payload
/// (REQ-d00119-K). Used in the example to demonstrate the storage-shape
/// difference vs `DemoDestination` (lossy 3rd-party).
///
/// Implements [DemoKnobs] so the FIFO panel exposes the same live-tunable
/// connection / latency / batch-size / accumulate sliders as the lossy
/// `DemoDestination`. Default knob values preserve the previously-fixed
/// behavior: `batchSize=10` (highlights native multi-event batches),
/// `sendLatency=0` (instant succeed), `connection=ok`,
/// `maxAccumulateTime=0` (no hold).
///
/// Optional [DownstreamBridge] hook: when supplied via the `bridge:`
/// constructor parameter and `connection.value == Connection.ok`,
/// `send()` delegates to the bridge after the latency delay. The bridge
/// forwards the wire bytes to a downstream `EventStore.ingestBatch` and
/// maps the outcome back to a [SendResult]. When `connection != ok`,
/// the bridge is NOT invoked — link failures are simulated upstream of
/// the bridge so the existing `broken`/`rejecting` UX is unchanged.
```

- [ ] **Step 4: Run tests to verify they pass**

Run both the new test file and the existing example test suite to catch regressions:

```bash
(cd apps/common-dart/event_sourcing_datastore/example && flutter test test/native_demo_destination_test.dart test/demo_destination_test.dart)
```

Expected: PASS — 6 new + existing tests.

- [ ] **Step 5: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/example/lib/native_demo_destination.dart \
        apps/common-dart/event_sourcing_datastore/example/test/native_demo_destination_test.dart
git commit -m "$(cat <<'EOF'
[CUR-1154] example: NativeDemoDestination accepts optional DownstreamBridge

Wires bridge.deliver() into send() when connection=ok; broken/rejecting
branches still short-circuit before the bridge so link failures simulate
without touching the downstream. Default behavior (no bridge) unchanged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Extract `DemoPane` from `DemoApp`

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/app.dart`

`DemoPane` becomes the Scaffold/Column body; the `MaterialApp` wrapper moves out (it will live in `DualDemoApp`, Task 4). `DemoPane` adds a `paneLabel` constructor parameter and renders a small header strip showing the label + db path so the user can tell halves apart.

- [ ] **Step 1: Replace `DemoApp` with `DemoPane` + `DemoAppRoot`**

Read the current file before editing:

```bash
cat apps/common-dart/event_sourcing_datastore/example/lib/app.dart
```

Replace the file contents with:

```dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/app_state.dart';
import 'package:event_sourcing_datastore_demo/demo_sync_policy.dart';
import 'package:event_sourcing_datastore_demo/widgets/audit_panel.dart';
import 'package:event_sourcing_datastore_demo/widgets/detail_panel.dart';
import 'package:event_sourcing_datastore_demo/widgets/event_stream_panel.dart';
import 'package:event_sourcing_datastore_demo/widgets/fifo_panel.dart';
import 'package:event_sourcing_datastore_demo/widgets/materialized_panel.dart';
import 'package:event_sourcing_datastore_demo/widgets/styles.dart';
import 'package:event_sourcing_datastore_demo/widgets/sync_policy_bar.dart';
import 'package:event_sourcing_datastore_demo/widgets/top_action_bar.dart';
import 'package:flutter/material.dart';

const double _kMinColumnWidth = 80;
const double _kDividerWidth = 5;

const Map<String, double> _kDefaultColumnWidths = <String, double>{
  'materialized': 200,
  'events': 280,
  'audit': 320,
};
const double _kDefaultFifoColumnWidth = 260;

/// Single-pane root: wraps a [DemoPane] in a [MaterialApp]. Used when the
/// example is launched in single-datastore mode. The dual-pane root is
/// `DualDemoApp` (see `dual_demo_app.dart`) — it owns a single
/// `MaterialApp` that hosts two [DemoPane]s.
class DemoAppRoot extends StatelessWidget {
  const DemoAppRoot({
    required this.datastore,
    required this.backend,
    required this.appState,
    required this.entryTypeLookup,
    required this.dbPath,
    required this.tickController,
    super.key,
  });

  final AppendOnlyDatastore datastore;
  final SembastBackend backend;
  final AppState appState;
  final EntryTypeDefinitionLookup entryTypeLookup;
  final String dbPath;
  final Timer tickController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Append-Only Datastore Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: DemoColors.bg,
        colorScheme: const ColorScheme.dark(
          surface: DemoColors.bg,
          onSurface: DemoColors.fg,
          primary: DemoColors.accent,
        ),
      ),
      home: Scaffold(
        backgroundColor: DemoColors.bg,
        body: SafeArea(
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.bold),
            child: DemoPane(
              datastore: datastore,
              backend: backend,
              appState: appState,
              entryTypeLookup: entryTypeLookup,
              dbPath: dbPath,
              tickController: tickController,
              paneLabel: 'Demo',
            ),
          ),
        ),
      ),
    );
  }
}

/// One full datastore UI: optional header strip with the pane label, the
/// `TopActionBar`, the `SyncPolicyBar`, and the resizable column row. No
/// `MaterialApp` wrapper — callers compose `DemoPane`s under a single
/// root `MaterialApp`.
class DemoPane extends StatefulWidget {
  const DemoPane({
    required this.datastore,
    required this.backend,
    required this.appState,
    required this.entryTypeLookup,
    required this.dbPath,
    required this.tickController,
    required this.paneLabel,
    super.key,
  });

  final AppendOnlyDatastore datastore;
  final SembastBackend backend;
  final AppState appState;
  final EntryTypeDefinitionLookup entryTypeLookup;
  final String dbPath;
  final Timer tickController;

  /// Short identifier shown in the header strip (e.g. "MOBILE", "PORTAL").
  /// Drives only the visual differentiation between panes; no behavior
  /// depends on it.
  final String paneLabel;

  @override
  State<DemoPane> createState() => _DemoPaneState();
}

class _DemoPaneState extends State<DemoPane> {
  final Map<String, double> _widths = <String, double>{};

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onAppState);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppState);
    super.dispose();
  }

  void _onAppState() {
    if (!mounted) return;
    setState(() {});
  }

  double _widthOf(String id, {required double fallback}) =>
      _widths[id] ?? _kDefaultColumnWidths[id] ?? fallback;

  void _resize(String id, double deltaX, double fallback) {
    setState(() {
      final current = _widthOf(id, fallback: fallback);
      _widths[id] = math.max(_kMinColumnWidth, current + deltaX);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _paneHeader(),
        TopActionBar(
          datastore: widget.datastore,
          backend: widget.backend,
          entryTypesLookup: widget.entryTypeLookup,
          appState: widget.appState,
          onResetAll: resetAll,
        ),
        SyncPolicyBar(notifier: demoPolicyNotifier),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _buildColumns(),
          ),
        ),
      ],
    );
  }

  Widget _paneHeader() {
    return Container(
      decoration: BoxDecoration(color: DemoColors.bg, border: demoBorder),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: <Widget>[
          Text(
            widget.paneLabel,
            style: const TextStyle(
              color: DemoColors.accent,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.dbPath,
              style: const TextStyle(
                color: DemoColors.pending,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildColumns() {
    return <Widget>[
      SizedBox(
        width: _widthOf('materialized', fallback: 200),
        child: MaterializedPanel(
          backend: widget.backend,
          appState: widget.appState,
        ),
      ),
      _divider('materialized', fallback: 200),
      SizedBox(
        width: _widthOf('events', fallback: 280),
        child: EventStreamPanel(
          backend: widget.backend,
          appState: widget.appState,
        ),
      ),
      _divider('events', fallback: 280),
      SizedBox(
        width: _widthOf('audit', fallback: 320),
        child: AuditPanel(backend: widget.backend),
      ),
      _divider('audit', fallback: 320),
      for (final dest in widget.appState.destinations) ...<Widget>[
        SizedBox(
          width: _widthOf(
            'fifo_${dest.id}',
            fallback: _kDefaultFifoColumnWidth,
          ),
          child: FifoPanel(
            destination: dest,
            backend: widget.backend,
            appState: widget.appState,
            key: ValueKey<String>(dest.id),
          ),
        ),
        _divider('fifo_${dest.id}', fallback: _kDefaultFifoColumnWidth),
      ],
      Expanded(
        child: DetailPanel(
          backend: widget.backend,
          appState: widget.appState,
          policyNotifier: demoPolicyNotifier,
        ),
      ),
    ];
  }

  Widget _divider(String leftId, {required double fallback}) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => _resize(leftId, d.delta.dx, fallback),
        child: Container(width: _kDividerWidth, color: DemoColors.border),
      ),
    );
  }

  Future<void> resetAll() async {
    widget.tickController.cancel();
    await widget.backend.close();
    final file = File(widget.dbPath);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
```

Key changes vs the previous file:
- `DemoApp` is replaced by two classes: `DemoAppRoot` (single-pane wrapper, kept so a single-datastore launch is still possible) and `DemoPane` (the body, no `MaterialApp`).
- `DemoPane` adds a `paneLabel` parameter and a header strip showing label + db path.
- The `DefaultTextStyle.merge` and `MaterialApp`/`Scaffold`/`SafeArea` wrapping moves to `DemoAppRoot`. When `DualDemoApp` (Task 4) hosts two panes, it provides its own equivalent wrapping once.
- Constructor surface for `DemoPane` is identical to the old `DemoApp` (same six fields) plus `paneLabel`. Field types and names are preserved so nothing else has to change.

- [ ] **Step 2: Verify the example still analyzes cleanly**

Run: `(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze)`
Expected: no new warnings or errors. (`main.dart` will still reference `DemoApp` and break — that's resolved in Task 5; this step's intent is to confirm `app.dart` itself analyzes.)

If `flutter analyze` fails on `main.dart`'s `DemoApp` reference, that is expected and OK to commit at this point — Task 5 fixes the entry point. The blocker would be any error inside `app.dart` itself.

- [ ] **Step 3: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/example/lib/app.dart
git commit -m "$(cat <<'EOF'
[CUR-1154] example: extract DemoPane from DemoApp; add DemoAppRoot wrapper

DemoPane is the body widget (no MaterialApp). DemoAppRoot keeps the
single-pane wrapper. Adds a per-pane header strip showing pane label and
db path. Prep for the dual-pane root introduced next.

Note: main.dart still references the removed DemoApp class — fixed in
the main() rewrite task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: New `DualDemoApp` widget

**Files:**
- Create: `apps/common-dart/event_sourcing_datastore/example/lib/dual_demo_app.dart`

`DualDemoApp` is the new top-level widget for two-datastore mode. One `MaterialApp`, one `Scaffold`, one `Column` containing the top pane, a draggable horizontal divider, and the bottom pane. Each pane is a `DemoPane` instance from Task 3.

- [ ] **Step 1: Write the file**

Create `apps/common-dart/event_sourcing_datastore/example/lib/dual_demo_app.dart`:

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/app.dart';
import 'package:event_sourcing_datastore_demo/app_state.dart';
import 'package:event_sourcing_datastore_demo/widgets/styles.dart';
import 'package:flutter/material.dart';

const double _kPaneDividerHeight = 5;
const double _kMinPaneHeight = 120;

/// Configuration for one [DemoPane] inside a [DualDemoApp]. Mirrors the
/// six constructor fields of `DemoPane` plus the per-pane label so the
/// dual root can pass them through verbatim.
class DemoPaneConfig {
  const DemoPaneConfig({
    required this.datastore,
    required this.backend,
    required this.appState,
    required this.entryTypeLookup,
    required this.dbPath,
    required this.tickController,
    required this.paneLabel,
  });

  final AppendOnlyDatastore datastore;
  final SembastBackend backend;
  final AppState appState;
  final EntryTypeDefinitionLookup entryTypeLookup;
  final String dbPath;
  final Timer tickController;
  final String paneLabel;
}

/// Two-datastore root: one MaterialApp hosting two [DemoPane]s stacked
/// vertically, separated by a draggable horizontal divider. State is
/// limited to the top-pane height.
class DualDemoApp extends StatefulWidget {
  const DualDemoApp({
    required this.top,
    required this.bottom,
    super.key,
  });

  final DemoPaneConfig top;
  final DemoPaneConfig bottom;

  @override
  State<DualDemoApp> createState() => _DualDemoAppState();
}

class _DualDemoAppState extends State<DualDemoApp> {
  /// Top pane height in pixels. `null` until the first layout supplies a
  /// total height; once the user drags the divider it is locked to a
  /// concrete value.
  double? _topHeight;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Append-Only Datastore Demo (Dual)',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: DemoColors.bg,
        colorScheme: const ColorScheme.dark(
          surface: DemoColors.bg,
          onSurface: DemoColors.fg,
          primary: DemoColors.accent,
        ),
      ),
      home: Scaffold(
        backgroundColor: DemoColors.bg,
        body: SafeArea(
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.bold),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final total = constraints.maxHeight;
                final topHeight = _resolveTopHeight(total);
                final bottomHeight = math.max(
                  _kMinPaneHeight,
                  total - topHeight - _kPaneDividerHeight,
                );
                return Column(
                  children: <Widget>[
                    SizedBox(
                      height: topHeight,
                      child: _paneFor(widget.top),
                    ),
                    _divider(total),
                    SizedBox(
                      height: bottomHeight,
                      child: _paneFor(widget.bottom),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  double _resolveTopHeight(double total) {
    final raw = _topHeight ?? total / 2;
    final maxTop = total - _kMinPaneHeight - _kPaneDividerHeight;
    return raw.clamp(_kMinPaneHeight, math.max(_kMinPaneHeight, maxTop));
  }

  Widget _paneFor(DemoPaneConfig cfg) {
    return DemoPane(
      datastore: cfg.datastore,
      backend: cfg.backend,
      appState: cfg.appState,
      entryTypeLookup: cfg.entryTypeLookup,
      dbPath: cfg.dbPath,
      tickController: cfg.tickController,
      paneLabel: cfg.paneLabel,
    );
  }

  Widget _divider(double total) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (DragUpdateDetails details) {
          setState(() {
            final current = _topHeight ?? total / 2;
            _topHeight = current + details.delta.dy;
          });
        },
        child: Container(
          height: _kPaneDividerHeight,
          color: DemoColors.border,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify the file analyzes**

Run: `(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze lib/dual_demo_app.dart)`
Expected: no errors, no warnings.

- [ ] **Step 3: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/example/lib/dual_demo_app.dart
git commit -m "$(cat <<'EOF'
[CUR-1154] example: DualDemoApp hosts two DemoPanes with draggable divider

One MaterialApp, two DemoPaneConfigs (top, bottom), a draggable horizontal
divider with min-height clamp. Prep for two-datastore main() wiring.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Rewrite `main()` to bootstrap two datastores + bridge

**Files:**
- Modify: `apps/common-dart/event_sourcing_datastore/example/lib/main.dart`

Two sembast DBs, two datastores with distinct `Source` identities, a `DownstreamBridge` from mobile's `Native` into portal's `EventStore`, two tick timers, and a `DualDemoApp` as the root widget.

- [ ] **Step 1: Replace `main.dart` contents**

Read the current file before editing:

```bash
cat apps/common-dart/event_sourcing_datastore/example/lib/main.dart
```

Replace with:

```dart
import 'dart:async';
import 'dart:io';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/app_state.dart';
import 'package:event_sourcing_datastore_demo/demo_destination.dart';
import 'package:event_sourcing_datastore_demo/demo_sync_policy.dart';
import 'package:event_sourcing_datastore_demo/demo_types.dart';
import 'package:event_sourcing_datastore_demo/downstream_bridge.dart';
import 'package:event_sourcing_datastore_demo/dual_demo_app.dart';
import 'package:event_sourcing_datastore_demo/native_demo_destination.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

class _PaneRuntime {
  _PaneRuntime({
    required this.datastore,
    required this.backend,
    required this.appState,
    required this.dbPath,
    required this.tick,
  });

  final AppendOnlyDatastore datastore;
  final SembastBackend backend;
  final AppState appState;
  final String dbPath;
  final Timer tick;
}

/// Bootstraps one datastore with its own destinations and starts a
/// 1-second sync tick. The optional [bridge] is wired into the Native
/// destination's `send()` so mobile's outgoing wire stream lands in
/// portal's `EventStore.ingestBatch`. The portal pane passes
/// `bridge: null` so its Native destination's `send()` is a no-op
/// simulator (existing behavior).
// Implements: REQ-d00134 — single init point: registers entry types,
// destinations, materializer. Implements: REQ-d00125 — 1-second tick
// drives fillBatch + drain per destination with live policy from
// demoPolicyNotifier.
Future<_PaneRuntime> _bootstrapPane({
  required String dbPath,
  required Source source,
  DownstreamBridge? bridge,
}) async {
  final db = await databaseFactoryIo.openDatabase(dbPath);
  final backend = SembastBackend(database: db);

  final primary = DemoDestination(
    id: 'Primary',
    filter: const SubscriptionFilter(
      entryTypes: <String>[
        'demo_note',
        'red_button_pressed',
        'green_button_pressed',
      ],
    ),
  );
  final secondary = DemoDestination(
    id: 'Secondary',
    allowHardDelete: true,
    filter: const SubscriptionFilter(
      entryTypes: <String>['green_button_pressed', 'blue_button_pressed'],
    ),
  );
  final native = NativeDemoDestination(id: 'Native', bridge: bridge);

  final datastore = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: source,
    entryTypes: allDemoEntryTypes,
    destinations: <Destination>[primary, secondary, native],
    materializers: const <Materializer>[DiaryEntriesMaterializer()],
  );

  final now = DateTime.now().toUtc();
  for (final id in <String>['Primary', 'Secondary', 'Native']) {
    final schedule = await datastore.destinations.scheduleOf(id);
    if (schedule.startDate == null) {
      await datastore.destinations.setStartDate(id, now);
    }
  }

  final appState = AppState(
    registry: datastore.destinations,
    policyNotifier: demoPolicyNotifier,
  );

  // Reentrancy guard mirrors SyncCycle.call's REQ-d00125-C: when a tick
  // takes longer than the 1-second interval (e.g. sendLatency=10s), the
  // next periodic fire would otherwise overlap drain on the same
  // destination, double-calling markFinal which is one-way.
  var syncInFlight = false;
  final tick = Timer.periodic(const Duration(seconds: 1), (_) async {
    if (syncInFlight) return;
    syncInFlight = true;
    try {
      final destinations = datastore.destinations.all();
      await Future.wait(
        destinations.map((dest) async {
          final schedule = await datastore.destinations.scheduleOf(dest.id);
          await fillBatch(
            dest,
            backend: backend,
            schedule: schedule,
            source: source,
          );
        }),
      );
      await Future.wait(
        destinations.map(
          (dest) =>
              drain(dest, backend: backend, policy: demoPolicyNotifier.value),
        ),
      );
    } catch (e, s) {
      stderr.writeln('[demo:${source.hopId}] sync tick error: $e\n$s');
    } finally {
      syncInFlight = false;
    }
  });

  return _PaneRuntime(
    datastore: datastore,
    backend: backend,
    appState: appState,
    dbPath: dbPath,
    tick: tick,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appSupportDir = await getApplicationSupportDirectory();
  final demoDir = Directory(
    p.join(appSupportDir.path, 'event_sourcing_datastore_demo'),
  );
  await demoDir.create(recursive: true);

  final mobileDbPath = p.join(demoDir.path, 'demo.db');
  final portalDbPath = p.join(demoDir.path, 'demo_portal.db');
  stdout
    ..writeln('[demo] mobile storage: $mobileDbPath')
    ..writeln('[demo] portal storage: $portalDbPath');

  // Portal must be bootstrapped first so the bridge can capture its
  // EventStore before mobile's NativeDemoDestination is constructed.
  final portal = await _bootstrapPane(
    dbPath: portalDbPath,
    source: const Source(
      hopId: 'portal',
      identifier: 'demo-portal',
      softwareVersion: 'event_sourcing_datastore_demo@0.1.0+1',
    ),
  );

  final bridge = DownstreamBridge(portal.datastore.eventStore);

  final mobile = await _bootstrapPane(
    dbPath: mobileDbPath,
    source: const Source(
      hopId: 'mobile-device',
      identifier: 'demo-device',
      softwareVersion: 'event_sourcing_datastore_demo@0.1.0+1',
    ),
    bridge: bridge,
  );

  final entryTypeLookup = _RegistryLookup(mobile.datastore.entryTypes);

  runApp(
    DualDemoApp(
      top: DemoPaneConfig(
        datastore: mobile.datastore,
        backend: mobile.backend,
        appState: mobile.appState,
        entryTypeLookup: entryTypeLookup,
        dbPath: mobile.dbPath,
        tickController: mobile.tick,
        paneLabel: 'MOBILE',
      ),
      bottom: DemoPaneConfig(
        datastore: portal.datastore,
        backend: portal.backend,
        appState: portal.appState,
        entryTypeLookup: entryTypeLookup,
        dbPath: portal.dbPath,
        tickController: portal.tick,
        paneLabel: 'PORTAL',
      ),
    ),
  );
}

class _RegistryLookup implements EntryTypeDefinitionLookup {
  const _RegistryLookup(this.registry);
  final EntryTypeRegistry registry;
  @override
  EntryTypeDefinition? lookup(String entryTypeId) =>
      registry.byId(entryTypeId);
}
```

Note on `_RegistryLookup`: both panes share one lookup adapter. The shared lookup is fine because both datastores are bootstrapped with the same `allDemoEntryTypes` list — every entry type id resolves identically on both sides.

Note on bootstrap order: portal must be bootstrapped before mobile because mobile's `DownstreamBridge` needs portal's `EventStore` reference. If you swap the order, the bridge has no target.

- [ ] **Step 2: Run the example test suite + analyze**

```bash
(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze && flutter test)
```

Expected: analyze clean, all tests pass (the new tests from Tasks 1 and 2, plus the existing ones).

- [ ] **Step 3: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/example/lib/main.dart
git commit -m "$(cat <<'EOF'
[CUR-1154] example: bootstrap two datastores; mobile→portal bridge wiring

main() opens demo.db (mobile) and demo_portal.db (portal), bootstraps a
full datastore for each (own Source identity, own destinations, own tick
loop), constructs a DownstreamBridge into portal's EventStore, and wires
it into mobile's NativeDemoDestination. Root widget is DualDemoApp.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: End-to-end mobile→portal sync test

**Files:**
- Test: `apps/common-dart/event_sourcing_datastore/example/test/portal_sync_test.dart` (new)

The spec mentioned `integration_test/`; we deliberately put this in `test/` instead because the test exercises the bridge plus the existing `fillBatch`+`drain` machinery directly without any Flutter framework involvement, matching the existing in-memory-sembast test pattern (see `app_state_test.dart`). Adding the `integration_test` dev-dep just for this test is unnecessary surface.

The test bootstraps two datastores in-memory, wires the bridge between them, exercises a few sync ticks, and asserts end-to-end behavior.

- [ ] **Step 1: Write the failing test**

Create `apps/common-dart/event_sourcing_datastore/example/test/portal_sync_test.dart`:

```dart
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/demo_destination.dart';
import 'package:event_sourcing_datastore_demo/demo_sync_policy.dart';
import 'package:event_sourcing_datastore_demo/demo_types.dart';
import 'package:event_sourcing_datastore_demo/downstream_bridge.dart';
import 'package:event_sourcing_datastore_demo/native_demo_destination.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

class _Pane {
  _Pane({
    required this.datastore,
    required this.backend,
    required this.source,
  });

  final AppendOnlyDatastore datastore;
  final SembastBackend backend;
  final Source source;

  Future<void> tick() async {
    final destinations = datastore.destinations.all();
    for (final dest in destinations) {
      final schedule = await datastore.destinations.scheduleOf(dest.id);
      await fillBatch(
        dest,
        backend: backend,
        schedule: schedule,
        source: source,
      );
    }
    for (final dest in destinations) {
      await drain(
        dest,
        backend: backend,
        policy: demoPolicyNotifier.value,
      );
    }
  }
}

Future<_Pane> _mkPane({
  required String dbName,
  required Source source,
  DownstreamBridge? bridge,
}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(dbName);
  final backend = SembastBackend(database: db);

  final primary = DemoDestination(
    id: 'Primary',
    filter: const SubscriptionFilter(
      entryTypes: <String>[
        'demo_note',
        'red_button_pressed',
        'green_button_pressed',
      ],
    ),
  );
  final secondary = DemoDestination(
    id: 'Secondary',
    allowHardDelete: true,
    filter: const SubscriptionFilter(
      entryTypes: <String>['green_button_pressed', 'blue_button_pressed'],
    ),
  );
  final native = NativeDemoDestination(id: 'Native', bridge: bridge);

  final datastore = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: source,
    entryTypes: allDemoEntryTypes,
    destinations: <Destination>[primary, secondary, native],
    materializers: const <Materializer>[DiaryEntriesMaterializer()],
  );

  final now = DateTime.now().toUtc();
  for (final id in <String>['Primary', 'Secondary', 'Native']) {
    final schedule = await datastore.destinations.scheduleOf(id);
    if (schedule.startDate == null) {
      await datastore.destinations.setStartDate(id, now);
    }
  }

  return _Pane(datastore: datastore, backend: backend, source: source);
}

Future<void> _appendDemoNote(_Pane pane, String aggregateId) async {
  await pane.datastore.eventStore.append(
    entryType: 'demo_note',
    aggregateId: aggregateId,
    aggregateType: 'DiaryEntry',
    eventType: 'finalized',
    data: const <String, Object?>{
      'answers': <String, Object?>{'title': 't', 'body': 'b'},
    },
    initiator: const UserInitiator('demo-user-1'),
  );
}

void main() {
  group('mobile → portal one-way sync', () {
    test(
      'three demo_notes appended on mobile arrive in portal with portal-stamped provenance',
      () async {
        final portal = await _mkPane(
          dbName: 'portal-e2e.db',
          source: const Source(
            hopId: 'portal',
            identifier: 'demo-portal',
            softwareVersion: 'test',
          ),
        );
        final bridge = DownstreamBridge(portal.datastore.eventStore);
        final mobile = await _mkPane(
          dbName: 'mobile-e2e.db',
          source: const Source(
            hopId: 'mobile-device',
            identifier: 'demo-device',
            softwareVersion: 'test',
          ),
          bridge: bridge,
        );

        await _appendDemoNote(mobile, 'agg-a');
        await _appendDemoNote(mobile, 'agg-b');
        await _appendDemoNote(mobile, 'agg-c');

        // Two ticks: tick 1 fills the FIFO + drains; the bridge ingests
        // into portal during drain. Tick 2 lets portal's own destinations
        // process the freshly-ingested events.
        await mobile.tick();
        await portal.tick();

        final portalEvents = await portal.backend.findAllEvents();
        expect(portalEvents.length, 3);
        for (final ev in portalEvents) {
          final hops = ev.metadata.provenance.map((p) => p.hop).toList();
          expect(
            hops,
            containsAllInOrder(<String>['mobile-device', 'portal']),
            reason: 'event ${ev.eventId} provenance hops: $hops',
          );
        }
      },
    );

    test('events appended locally on portal do not flow back to mobile',
        () async {
      final portal = await _mkPane(
        dbName: 'portal-oneway.db',
        source: const Source(
          hopId: 'portal',
          identifier: 'demo-portal',
          softwareVersion: 'test',
        ),
      );
      final bridge = DownstreamBridge(portal.datastore.eventStore);
      final mobile = await _mkPane(
        dbName: 'mobile-oneway.db',
        source: const Source(
          hopId: 'mobile-device',
          identifier: 'demo-device',
          softwareVersion: 'test',
        ),
        bridge: bridge,
      );

      await _appendDemoNote(portal, 'agg-portal-only');
      await portal.tick();
      await mobile.tick();

      final mobileEvents = await mobile.backend.findAllEvents();
      expect(mobileEvents, isEmpty,
          reason: 'mobile must not receive events from portal (one-way sync)');
    });

    test(
      'mobile.Native connection=broken keeps mobile FIFO pending and portal empty',
      () async {
        final portal = await _mkPane(
          dbName: 'portal-broken.db',
          source: const Source(
            hopId: 'portal',
            identifier: 'demo-portal',
            softwareVersion: 'test',
          ),
        );
        final bridge = DownstreamBridge(portal.datastore.eventStore);
        final mobile = await _mkPane(
          dbName: 'mobile-broken.db',
          source: const Source(
            hopId: 'mobile-device',
            identifier: 'demo-device',
            softwareVersion: 'test',
          ),
          bridge: bridge,
        );

        // Flip mobile's Native to broken before the first tick.
        final native = mobile.datastore.destinations
            .all()
            .whereType<NativeDemoDestination>()
            .single;
        native.connection.value = Connection.broken;

        await _appendDemoNote(mobile, 'agg-stuck');
        await mobile.tick();
        await portal.tick();

        final portalEvents = await portal.backend.findAllEvents();
        expect(portalEvents, isEmpty,
            reason: 'broken link must not deliver to portal');
      },
    );
  });
}
```

One note on the test code: `whereType<NativeDemoDestination>().single` assumes the test fixture only registers one `Native` destination per pane (it does — see `_mkPane`).

- [ ] **Step 2: Run the test to verify it passes**

Run: `(cd apps/common-dart/event_sourcing_datastore/example && flutter test test/portal_sync_test.dart)`
Expected: PASS — 3 tests.

- [ ] **Step 3: Run the full example suite to catch regressions**

Run: `(cd apps/common-dart/event_sourcing_datastore/example && flutter analyze && flutter test)`
Expected: analyze clean, all tests pass.

- [ ] **Step 4: Commit**

```bash
git add apps/common-dart/event_sourcing_datastore/example/test/portal_sync_test.dart
git commit -m "$(cat <<'EOF'
[CUR-1154] example: end-to-end test for mobile → portal one-way sync

Bootstraps two in-memory datastores wired via DownstreamBridge. Asserts
three demo_notes appended on mobile arrive in portal with provenance
['mobile-device', 'portal']; asserts portal-only appends don't flow back;
asserts a broken Native connection blocks delivery.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Manual verification

**No file changes.** This is an explicit acceptance step before declaring the work done.

- [ ] **Step 1: Run the example on Linux desktop**

```bash
(cd apps/common-dart/event_sourcing_datastore/example && flutter run -d linux)
```

- [ ] **Step 2: Verify the dual-pane layout**

Confirm:
- Top pane labeled `MOBILE`, bottom pane labeled `PORTAL`. Each header shows its db path.
- Both panes render `TopActionBar`, `SyncPolicyBar`, materialized/events/audit/FIFO/detail columns.
- The horizontal divider between panes can be dragged with the mouse; both panes resize.

- [ ] **Step 3: Verify one-way sync**

In MOBILE pane:
- Click `[GREEN]` (or any action button). Watch mobile's events panel show the new event.
- Within ~1–2 seconds, watch PORTAL's events panel show the same event.
- Click PORTAL's events row → DETAIL panel shows provenance with two hops: `mobile-device` followed by `portal`.

- [ ] **Step 4: Verify link-failure simulation**

In MOBILE pane, find the `Native` FIFO column knobs. Flip `connection` to `broken`.
- Click `[GREEN]` in MOBILE.
- MOBILE's `Native` FIFO row should stay yellow/pending; PORTAL should NOT receive the event.
- Flip `connection` back to `ok`. Within a tick or two, PORTAL receives the event.

- [ ] **Step 5: Verify reset isolation**

In MOBILE pane, click `[Reset all]` and confirm.
- MOBILE's tick stops; the next mobile-side click does nothing (process-level restart needed for mobile).
- PORTAL keeps ticking and remains usable; previously-ingested events are still visible.

- [ ] **Step 6: Verify portal-local injection**

In PORTAL pane, click `[Add demo_note]` (or any action). The event appears in PORTAL only (mobile's events panel is unchanged).

If any step above fails, do not declare the feature done. File the failure as a follow-up task with reproduction steps.

---

## Self-Review Notes

**Spec coverage check:**
- Architecture (single process, two datastores, vertical split) — Tasks 4, 5.
- `DemoApp` refactor (DemoPane + DemoAppRoot) — Task 3.
- `DualDemoApp` — Task 4.
- `DownstreamBridge` (with full result mapping table) — Task 1.
- `NativeDemoDestination` extension (optional bridge param, connection-gated) — Task 2.
- `main()` rewrite (two DBs, two datastores, two ticks, bridge wiring) — Task 5.
- Data flow (FIFO → drain → bridge → ingestBatch → portal append) — verified by Task 6 e2e tests.
- Error handling (`broken` → SendTransient, `rejecting` → SendPermanent, decode/identity/chain → SendPermanent, unknown → SendTransient, success → SendOk) — Tasks 1, 2 unit tests; Task 6 integration test for `broken`.
- Reset isolation — Task 7 manual verification (no library code path needs adding; existing `resetAll` already only touches one db).
- Testing strategy: unit tests in Tasks 1+2, e2e test in Task 6 (relocated from `integration_test/` to `test/` with rationale documented). No widget tests, per spec.
- Manual verification — Task 7.

**Type-consistency check:**
- `DemoPaneConfig` fields exactly match `DemoPane` constructor params (Task 4 vs Task 3).
- `_PaneRuntime` (Task 5) mirrors `DemoPaneConfig`'s data shape minus `paneLabel`.
- `DownstreamBridge.deliver(WirePayload) → Future<SendResult>` consistent across Tasks 1, 2.
- `NativeDemoDestination.bridge` accepts `DownstreamBridge?` (Task 2) and is supplied by `_bootstrapPane` (Task 5) as `DownstreamBridge?`.

**Placeholder scan:** None — all code blocks contain executable code; all expectations are concrete.

**API verification:** All library surfaces referenced in the plan (`Source`, `bootstrapAppendOnlyDatastore`, `EventStore.ingestBatch`, `WirePayload.{bytes,contentType}`, `BatchEnvelope.wireFormat`, `StorageBackend.findAllEvents`, `IngestDecodeFailure`/`IngestIdentityMismatch`/`IngestChainBroken`, `Connection.{ok,broken,rejecting}`, `SendOk`/`SendTransient`/`SendPermanent`) were grepped in the parent package before plan publication.
