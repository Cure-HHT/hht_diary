import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/app_state.dart';
import 'package:event_sourcing_datastore_demo/demo_sync_policy.dart';
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

/// Default widths for each column in pixels. DETAIL has no entry here
/// because it's rendered in an Expanded — it takes whatever's left so
/// it auto-grows on wider windows.
const Map<String, double> _kDefaultColumnWidths = <String, double>{
  'materialized': 200,
  'events': 280,
  // FIFO panels use a dynamic key 'fifo_<destination_id>'; fallback
  // default below in _widthOf.
};
const double _kDefaultFifoColumnWidth = 260;

/// Root widget. Constructor-passthrough for all collaborators so the
/// demo stays free of provider/riverpod deps (plan Task 3 rule: keep
/// the dep count minimal).
class DemoApp extends StatefulWidget {
  const DemoApp({
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
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  /// Per-column width overrides. Keyed on column id:
  /// `'materialized'`, `'events'`, or `'fifo_<destination_id>'`.
  /// DETAIL is Expanded (no entry).
  final Map<String, double> _widths = <String, double>{};

  @override
  void initState() {
    super.initState();
    // Rebuild when destinations are added/removed so new FIFO columns
    // and their dividers slot in.
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
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
          ),
        ),
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

  /// Reset the datastore: cancel the tick timer, close sembast, delete
  /// the demo.db file. Does NOT re-bootstrap here; caller is expected to
  /// restart the process (simplest demo reset) or re-invoke
  /// `bootstrapAppendOnlyDatastore` from a wrapper. Wired to the Task
  /// 12 `[Reset all]` button.
  Future<void> resetAll() async {
    widget.tickController.cancel();
    await widget.backend.close();
    final file = File(widget.dbPath);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
