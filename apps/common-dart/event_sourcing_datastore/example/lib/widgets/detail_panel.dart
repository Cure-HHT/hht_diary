import 'dart:async';
import 'dart:convert';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/app_state.dart';
import 'package:event_sourcing_datastore_demo/widgets/styles.dart';
import 'package:flutter/material.dart';

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
  StreamSubscription<StoredEvent>? _eventsSub;
  String? _summary;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onChange);
    widget.policyNotifier.addListener(_onChange);
    _eventsSub = widget.backend.watchEvents().listen((_) {
      if (!mounted) return;
      _refresh();
    });
    _refresh();
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
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
      final anyWedged = await widget.backend.anyFifoWedged();
      final wedged = await widget.backend.wedgedFifos();
      final aggCount = events.map((e) => e.aggregateId).toSet().length;
      final text = <String>[
        'events:     ${events.length}',
        'aggregates: $aggCount',
        'any wedged: $anyWedged',
        if (wedged.isNotEmpty)
          'wedged dst: ${wedged.map((s) => s.destinationId).join(", ")}',
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
      return _EventDetail(backend: widget.backend, eventId: eventId);
    }
    final fifoDestId = widget.appState.selectedFifoDestinationId;
    if (fifoId != null && fifoDestId != null) {
      return _AsyncJson(
        loader: () async {
          // FifoEntry.entryId == eventIds.first (library convention), so
          // rows collide on entry_id across destinations. Look up within
          // the specific destination the user selected.
          final entries = await widget.backend.listFifoEntries(fifoDestId);
          for (final entry in entries) {
            if (entry.entryId == fifoId) {
              return <String, Object?>{
                'destination': fifoDestId,
                ...entry.toJson(),
              };
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

/// Renders the selected event's metadata as JSON plus an explicit
/// per-provenance-entry summary that surfaces `origin_sequence_number`
/// (REQ-d00115-K) when set. Most local events have a single
/// origin-only provenance entry with no `origin_sequence_number` —
/// ingested events show one per receiver hop with the originator's
/// wire-supplied seq, demonstrating the unified-store property.
///
/// Plan 4.15 Task 5 Step 2 + Risk 4 mitigation (only render the line
/// when non-null, keeping local-event details uncluttered).
class _EventDetail extends StatefulWidget {
  const _EventDetail({required this.backend, required this.eventId});

  final SembastBackend backend;
  final String eventId;

  @override
  State<_EventDetail> createState() => _EventDetailState();
}

class _EventDetailState extends State<_EventDetail> {
  StoredEvent? _event;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_EventDetail old) {
    super.didUpdateWidget(old);
    if (old.eventId != widget.eventId) {
      _loaded = false;
      _event = null;
      _load();
    }
  }

  Future<void> _load() async {
    final events = await widget.backend.findAllEvents(limit: 100000);
    StoredEvent? event;
    for (final e in events) {
      if (e.eventId == widget.eventId) {
        event = e;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _event = event;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Text('...', style: DemoText.body);
    final event = _event;
    if (event == null) {
      return const Text('event not found', style: DemoText.body);
    }
    final provenance = _provenanceOf(event);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (provenance.isNotEmpty) ...<Widget>[
          const Text('provenance:', style: DemoText.body),
          for (var i = 0; i < provenance.length; i++)
            _ProvenanceLine(index: i, entry: provenance[i]),
          const SizedBox(height: 8),
        ],
        const Text('event:', style: DemoText.body),
        Text(_jsonOf(event), style: DemoText.body),
      ],
    );
  }

  static List<Map<String, Object?>> _provenanceOf(StoredEvent event) {
    final raw = event.metadata['provenance'];
    if (raw is! List) return const <Map<String, Object?>>[];
    return raw.cast<Map<String, Object?>>();
  }

  static String _jsonOf(StoredEvent event) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(event.toMap());
  }
}

class _ProvenanceLine extends StatelessWidget {
  const _ProvenanceLine({required this.index, required this.entry});

  final int index;
  final Map<String, Object?> entry;

  @override
  Widget build(BuildContext context) {
    final hop = entry['hop'] as String? ?? '?';
    final originSeq = entry['origin_sequence_number'] as int?;
    final ingestSeq = entry['ingest_sequence_number'] as int?;
    final summary = StringBuffer('  [$index] hop=$hop');
    if (ingestSeq != null) summary.write(' ingest_seq=$ingestSeq');
    if (originSeq != null) summary.write(' origin_seq=$originSeq');
    return Text(summary.toString(), style: DemoText.body);
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
