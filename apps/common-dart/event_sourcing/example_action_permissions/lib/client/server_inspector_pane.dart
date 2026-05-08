// lib/client/server_inspector_pane.dart
//
// Right-pane inspector: polls GET /_demo/inspect on a 1Hz timer and
// renders five sections (events, matrix, directory, idempotency, last
// dispatch trace). The polling cadence is intentionally simple — Phase
// 4.12's reactive layer is the future swap target.

import 'dart:async';

import 'package:action_permissions_demo/client/http_client.dart';
import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:flutter/material.dart';

class ServerInspectorPane extends StatefulWidget {
  const ServerInspectorPane({
    super.key,
    this.httpClient,
    this.pollInterval = const Duration(seconds: 1),
  });

  /// Injected for tests. When omitted, the pane creates its own
  /// `DemoHttpClient` bound to localhost:8080.
  final DemoHttpClient? httpClient;
  final Duration pollInterval;

  @override
  State<ServerInspectorPane> createState() => _ServerInspectorPaneState();
}

class _ServerInspectorPaneState extends State<ServerInspectorPane> {
  late final DemoHttpClient _http;
  late final bool _ownsHttp;
  Timer? _timer;
  InspectSnapshot? _snapshot;
  Object? _lastError;

  @override
  void initState() {
    super.initState();
    if (widget.httpClient != null) {
      _http = widget.httpClient!;
      _ownsHttp = false;
    } else {
      _http = DemoHttpClient();
      _ownsHttp = true;
    }
    _refresh();
    _timer = Timer.periodic(widget.pollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_ownsHttp) {
      _http.close();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final snap = await _http.inspect();
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
        _lastError = null;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _lastError = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snapshot;
    if (snap == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(_lastError != null ? 'error: $_lastError' : 'connecting…'),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_lastError != null)
            Text(
              'last poll error: $_lastError',
              style: const TextStyle(color: Colors.red),
            ),
          _Section(
            title: 'Event Log (${snap.events.length})',
            child: _EventList(events: snap.events),
          ),
          _Section(
            title: 'Matrix Grants (${snap.matrixGrants.length})',
            child: _MatrixTable(grants: snap.matrixGrants),
          ),
          _Section(
            title: 'User Directory (${snap.directory.length})',
            child: _DirectoryTable(directory: snap.directory),
          ),
          _Section(
            title: 'Idempotency Cache (${snap.idempotency.length})',
            child: _IdempotencyTable(entries: snap.idempotency),
          ),
          _Section(
            title: 'Last Dispatch Trace',
            child: _TraceView(trace: snap.lastDispatchTrace),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events});
  final List<StoredEventSummary> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Text(
        '(no events)',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Text(
              '${e.eventType} · ${e.aggregateType}/${_short(e.aggregateId)} '
              '· ${e.initiatorRole}'
              '${e.initiatorUserId != null ? ' (${e.initiatorUserId})' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  String _short(String s) => s.length > 8 ? '${s.substring(0, 8)}…' : s;
}

class _MatrixTable extends StatelessWidget {
  const _MatrixTable({required this.grants});
  final List<MatrixGrant> grants;

  @override
  Widget build(BuildContext context) {
    if (grants.isEmpty) {
      return const Text(
        '(no grants)',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final g in grants)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Text(
              '${g.role}  →  ${g.permission}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _DirectoryTable extends StatelessWidget {
  const _DirectoryTable({required this.directory});
  final List<UserDirectoryEntry> directory;

  @override
  Widget build(BuildContext context) {
    if (directory.isEmpty) {
      return const Text(
        '(empty)',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final d in directory)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Text(
              '${d.userId}  ·  ${d.role}'
              '${d.activeSite != null ? '  ·  ${d.activeSite}' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _IdempotencyTable extends StatelessWidget {
  const _IdempotencyTable({required this.entries});
  final List<IdempotencyEntrySummary> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text(
        '(empty)',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Text(
              '${e.actionName}  ·  ${e.principalUserId ?? "(anon)"}  ·  '
              '${e.idempotencyKey}  (expires ${e.expiresAt.toIso8601String()})',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _TraceView extends StatelessWidget {
  const _TraceView({required this.trace});
  final DispatchTrace? trace;

  @override
  Widget build(BuildContext context) {
    final t = trace;
    if (t == null) {
      return const Text(
        '(no dispatches yet)',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(t.actionName),
          for (final stage in t.stages) Text('  • $stage'),
        ],
      ),
    );
  }
}
