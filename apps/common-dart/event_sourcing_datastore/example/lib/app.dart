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
class DemoAppRoot extends StatefulWidget {
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
  State<DemoAppRoot> createState() => _DemoAppRootState();
}

class _DemoAppRootState extends State<DemoAppRoot> {
  late final ValueNotifier<SyncPolicy> _policyNotifier =
      ValueNotifier<SyncPolicy>(demoDefaultSyncPolicy);

  @override
  void dispose() {
    _policyNotifier.dispose();
    super.dispose();
  }

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
              datastore: widget.datastore,
              backend: widget.backend,
              appState: widget.appState,
              entryTypeLookup: widget.entryTypeLookup,
              dbPath: widget.dbPath,
              tickController: widget.tickController,
              policyNotifier: _policyNotifier,
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
    required this.policyNotifier,
    required this.paneLabel,
    super.key,
  });

  final AppendOnlyDatastore datastore;
  final SembastBackend backend;
  final AppState appState;
  final EntryTypeDefinitionLookup entryTypeLookup;
  final String dbPath;
  final Timer tickController;
  final ValueNotifier<SyncPolicy> policyNotifier;

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
        SyncPolicyBar(notifier: widget.policyNotifier),
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
          policyNotifier: widget.policyNotifier,
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
