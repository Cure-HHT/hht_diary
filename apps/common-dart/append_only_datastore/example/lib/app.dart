import 'dart:async';
import 'dart:io';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:append_only_datastore_demo/app_state.dart';
import 'package:append_only_datastore_demo/demo_sync_policy.dart';
import 'package:append_only_datastore_demo/widgets/detail_panel.dart';
import 'package:append_only_datastore_demo/widgets/event_stream_panel.dart';
import 'package:append_only_datastore_demo/widgets/fifo_panel.dart';
import 'package:append_only_datastore_demo/widgets/materialized_panel.dart';
import 'package:append_only_datastore_demo/widgets/styles.dart';
import 'package:append_only_datastore_demo/widgets/sync_policy_bar.dart';
import 'package:append_only_datastore_demo/widgets/top_action_bar.dart';
import 'package:flutter/material.dart';

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
                    Expanded(
                      flex: 2,
                      child: ListenableBuilder(
                        listenable: widget.appState,
                        builder: (context, _) => Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            for (final dest in widget.appState.destinations)
                              Expanded(
                                child: FifoPanel(
                                  destination: dest,
                                  backend: widget.backend,
                                  appState: widget.appState,
                                  key: ValueKey<String>(dest.id),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: DetailPanel(
                        backend: widget.backend,
                        appState: widget.appState,
                        policyNotifier: demoPolicyNotifier,
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
