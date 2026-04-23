import 'dart:async';
import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:append_only_datastore_demo/app_state.dart';
import 'package:append_only_datastore_demo/widgets/event_stream_panel.dart';
import 'package:append_only_datastore_demo/widgets/materialized_panel.dart';
import 'package:append_only_datastore_demo/widgets/styles.dart';
import 'package:flutter/material.dart';

/// Root widget. Constructor-passthrough for all collaborators so the
/// demo stays free of provider/riverpod deps (plan Task 3 rule: keep
/// the dep count minimal).
class DemoApp extends StatefulWidget {
  const DemoApp({
    required this.datastore,
    required this.backend,
    required this.appState,
    required this.dbPath,
    required this.tickController,
    super.key,
  });

  final AppendOnlyDatastore datastore;
  final SembastBackend backend;
  final AppState appState;
  final String dbPath;
  final Timer tickController;

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
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
              const _PlaceholderBanner(label: 'TOP ACTION BAR (Task 12)'),
              const _PlaceholderBanner(label: 'SYNC POLICY BAR (Task 12)'),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: MaterializedPanel(
                        backend: widget.backend,
                        appState: widget.appState,
                      ),
                    ),
                    Expanded(
                      child: EventStreamPanel(
                        backend: widget.backend,
                        appState: widget.appState,
                      ),
                    ),
                    const Expanded(
                      child: _PlaceholderBanner(
                        label: 'FIFO PANEL x N (Task 11)',
                      ),
                    ),
                    const SizedBox(
                      width: 320,
                      child: _PlaceholderBanner(
                        label: 'DETAIL PANEL (Task 13)',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

/// Thin banner widget used by Task 9 scaffolding to mark layout slots
/// that will be filled by Tasks 10-13.
class _PlaceholderBanner extends StatelessWidget {
  const _PlaceholderBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: DemoColors.bg, border: demoBorder),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(label, style: DemoText.header),
    );
  }
}
