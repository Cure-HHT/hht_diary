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
/// constructor fields of `DemoPane` plus the per-pane label so the
/// dual root can pass them through verbatim.
class DemoPaneConfig {
  const DemoPaneConfig({
    required this.datastore,
    required this.backend,
    required this.appState,
    required this.entryTypeLookup,
    required this.dbPath,
    required this.tickController,
    required this.policyNotifier,
    required this.paneLabel,
  });

  final AppendOnlyDatastore datastore;
  final SembastBackend backend;
  final AppState appState;
  final EntryTypeDefinitionLookup entryTypeLookup;
  final String dbPath;
  final Timer tickController;
  final ValueNotifier<SyncPolicy> policyNotifier;
  final String paneLabel;
}

/// Two-datastore root: one MaterialApp hosting two [DemoPane]s stacked
/// vertically, separated by a draggable horizontal divider. State is
/// limited to the top-pane height.
class DualDemoApp extends StatefulWidget {
  const DualDemoApp({required this.top, required this.bottom, super.key});

  final DemoPaneConfig top;
  final DemoPaneConfig bottom;

  @override
  State<DualDemoApp> createState() => _DualDemoAppState();
}

class _DualDemoAppState extends State<DualDemoApp> {
  /// Top pane height in pixels. `null` until the user first drags the
  /// divider; display uses `total / 2` when null (see `_resolveTopHeight`).
  double? _topHeight;

  /// Most recent total layout height, captured by [LayoutBuilder]. Used to
  /// seed `_topHeight` on the first drag so the divider starts from its
  /// visually-rendered position rather than from zero.
  double _lastTotal = 0;

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
                // Capture for use by the drag handler (seed on first drag).
                _lastTotal = total;
                final topHeight = _resolveTopHeight(total);
                final bottomHeight = math.max(
                  _kMinPaneHeight,
                  total - topHeight - _kPaneDividerHeight,
                );
                return Column(
                  children: <Widget>[
                    SizedBox(height: topHeight, child: _paneFor(widget.top)),
                    _divider(),
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
      policyNotifier: cfg.policyNotifier,
      paneLabel: cfg.paneLabel,
    );
  }

  Widget _divider() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (DragUpdateDetails details) {
          setState(() {
            // Seed from the rendered 50/50 position on the first drag so
            // the divider starts from its displayed location, not from zero.
            _topHeight = (_topHeight ?? _lastTotal / 2) + details.delta.dy;
          });
        },
        child: Container(height: _kPaneDividerHeight, color: DemoColors.border),
      ),
    );
  }
}
