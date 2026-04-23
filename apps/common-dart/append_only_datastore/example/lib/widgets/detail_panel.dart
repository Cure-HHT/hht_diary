import 'dart:async';
import 'dart:convert';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:append_only_datastore_demo/app_state.dart';
import 'package:append_only_datastore_demo/widgets/styles.dart';
import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';

// Validated by: JNY-01 (entry detail), JNY-03 (FIFO exhaustion), JNY-04
// (retry attempts[]), JNY-05 (policy snapshot), JNY-09 (unjam / rehab).
class DetailPanel extends StatefulWidget {
  const DetailPanel({
    required this.backend,
    required this.appState,
    required this.policyNotifier,
    super.key,
  });

  final SembastBackend backend;
  final AppState appState;
  final ValueNotifier<SyncPolicy> policyNotifier;

  @override
  State<DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends State<DetailPanel> {
  Timer? _poll;
  String? _summary;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onChange);
    widget.policyNotifier.addListener(_onChange);
    _poll = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _refresh(),
    );
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    widget.appState.removeListener(_onChange);
    widget.policyNotifier.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refresh() async {
    try {
      final events = await widget.backend.findAllEvents(limit: 100000);
      final anyExhausted = await widget.backend.anyFifoExhausted();
      final exhausted = await widget.backend.wedgedFifos();
      final aggCount = events.map((e) => e.aggregateId).toSet().length;
      final text = <String>[
        'events:        ${events.length}',
        'aggregates:    $aggCount',
        'any exhausted: $anyExhausted',
        if (exhausted.isNotEmpty)
          'exhausted dst: ${exhausted.map((s) => s.destinationId).join(", ")}',
      ].join('\n');
      if (!mounted) return;
      setState(() => _summary = text);
    } catch (_) {
      // Non-fatal.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: DemoColors.bg, border: demoBorder),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('DETAIL', style: DemoText.header),
          const SizedBox(height: 8),
          Expanded(child: SingleChildScrollView(child: _body())),
        ],
      ),
    );
  }

  Widget _body() {
    final aggId = widget.appState.selectedAggregateId;
    final eventId = widget.appState.selectedEventId;
    final fifoId = widget.appState.selectedFifoRowId;
    if (aggId != null) {
      return _AsyncJson(
        loader: () async {
          final rows = await widget.backend.findEntries();
          DiaryEntry? row;
          for (final r in rows) {
            if (r.entryId == aggId) {
              row = r;
              break;
            }
          }
          if (row == null) return <String, Object?>{'error': 'not found'};
          return <String, Object?>{
            'entry_id': row.entryId,
            'entry_type': row.entryType,
            'is_complete': row.isComplete,
            'is_deleted': row.isDeleted,
            'updated_at': row.updatedAt.toIso8601String(),
            'current_answers': row.currentAnswers,
            'latest_event_id': row.latestEventId,
          };
        },
      );
    }
    if (eventId != null) {
      return _AsyncJson(
        loader: () async {
          final events = await widget.backend.findAllEvents(limit: 100000);
          StoredEvent? event;
          for (final e in events) {
            if (e.eventId == eventId) {
              event = e;
              break;
            }
          }
          if (event == null) return <String, Object?>{'error': 'not found'};
          return event.toMap();
        },
      );
    }
    final fifoDestId = widget.appState.selectedFifoDestinationId;
    if (fifoId != null && fifoDestId != null) {
      return _AsyncJson(
        loader: () async {
          // FifoEntry.entryId == eventIds.first (library convention), so
          // rows collide on entry_id across destinations. Look up within
          // the specific destination the user selected.
          final store = intMapStoreFactory.store('fifo_$fifoDestId');
          final records = await store.find(widget.backend.debugDatabase());
          for (final r in records) {
            final m = Map<String, Object?>.from(r.value);
            if (m['entry_id'] == fifoId) {
              return <String, Object?>{'destination': fifoDestId, ...m};
            }
          }
          return <String, Object?>{
            'error': 'not found',
            'destination': fifoDestId,
            'entry_id': fifoId,
          };
        },
      );
    }
    // No selection — summary.
    final policy = widget.policyNotifier.value;
    return Text(
      '${_summary ?? 'loading...'}\n\n'
      'policy:\n'
      '  initialBackoff:    ${policy.initialBackoff.inMilliseconds}ms\n'
      '  backoffMultiplier: ${policy.backoffMultiplier}\n'
      '  maxBackoff:        ${policy.maxBackoff.inSeconds}s\n'
      '  jitterFraction:    ${policy.jitterFraction}\n'
      '  maxAttempts:       ${policy.maxAttempts}\n'
      '  periodicInterval:  ${policy.periodicInterval.inSeconds}s',
      style: DemoText.body,
    );
  }
}

class _AsyncJson extends StatefulWidget {
  const _AsyncJson({required this.loader});

  final Future<Map<String, Object?>> Function() loader;

  @override
  State<_AsyncJson> createState() => _AsyncJsonState();
}

class _AsyncJsonState extends State<_AsyncJson> {
  Map<String, Object?>? _value;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_AsyncJson old) {
    super.didUpdateWidget(old);
    _load();
  }

  Future<void> _load() async {
    final v = await widget.loader();
    if (!mounted) return;
    setState(() => _value = v);
  }

  @override
  Widget build(BuildContext context) {
    final v = _value;
    if (v == null) return const Text('...', style: DemoText.body);
    const encoder = JsonEncoder.withIndent('  ');
    return Text(encoder.convert(v), style: DemoText.body);
  }
}
