import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/app_state.dart';
import 'package:event_sourcing_datastore_demo/demo_types.dart';
import 'package:event_sourcing_datastore_demo/synthetic_ingest.dart';
import 'package:event_sourcing_datastore_demo/widgets/add_destination_dialog.dart';
import 'package:event_sourcing_datastore_demo/widgets/styles.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Fixed `SecurityDetails` stamped on every `_record` call when the
/// "security context" toggle is on. Realistic-looking but obviously
/// synthetic so an operator inspecting the AUDIT panel can correlate
/// rows back to this code path. Plan 4.15 §4.15.A — orchestrator-
/// approved scope addition: makes the AuditPanel demonstrate non-empty
/// rows (Plan 4.15 Task 4 Risk 3 mitigation).
const SecurityDetails _kDemoSecurityDetails = SecurityDetails(
  ipAddress: '203.0.113.42',
  userAgent: 'event_sourcing_datastore_demo/0.1.0 (Flutter; Linux desktop)',
  sessionId: 'demo-session-001',
  geoCountry: 'US',
  geoRegion: 'CA',
  requestId: 'demo-req-fixed',
);

// Validated by: JNY-01 (lifecycle), JNY-02 (CQRS action events), JNY-06
// (Rebuild view), JNY-07 (Add destination).
class TopActionBar extends StatefulWidget {
  const TopActionBar({
    required this.datastore,
    required this.backend,
    required this.entryTypesLookup,
    required this.appState,
    required this.onResetAll,
    super.key,
  });

  final AppendOnlyDatastore datastore;
  final SembastBackend backend;
  final EntryTypeDefinitionLookup entryTypesLookup;
  final AppState appState;
  final Future<void> Function() onResetAll;

  @override
  State<TopActionBar> createState() => _TopActionBarState();
}

class _TopActionBarState extends State<TopActionBar> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final SyntheticBatchBuilder _syntheticBatch = SyntheticBatchBuilder();

  // §4.15.A toggle. When on, every `_record` call passes
  // `_kDemoSecurityDetails` to `EventStore.append`'s `security:` arg, so
  // the security_context sidecar populates and the AUDIT panel renders
  // non-empty rows. Off by default so the empty-audit case stays
  // observable for demo pedagogy.
  bool _stampSecurityContext = false;

  @override
  void initState() {
    super.initState();
    // Subscribe so [Complete] / [Delete] enable when an aggregate is
    // selected (via [Start] or by tapping a MATERIALIZED row) and
    // disable again when selection clears.
    widget.appState.addListener(_onAppState);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppState);
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _onAppState() {
    if (!mounted) return;
    setState(() {});
  }

  Map<String, Object?> _collectAnswers() {
    // Omit empty-string fields so successive events carry only the keys
    // the operator actually filled in. Lets the materialized view exercise
    // its absent-key-preserves-prior merge branch (REQ-d00121-B+C+J).
    return <String, Object?>{
      if (_title.text.isNotEmpty) 'title': _title.text,
      if (_body.text.isNotEmpty) 'body': _body.text,
      'date': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> _record({
    required String entryType,
    required String aggregateId,
    required String eventType,
    required Map<String, Object?> answers,
    String? changeReason,
  }) async {
    final aggregateType = demoAggregateTypeByEntryTypeId[entryType]!;
    await widget.datastore.eventStore.append(
      entryType: entryType,
      entryTypeVersion: 1,
      aggregateId: aggregateId,
      aggregateType: aggregateType,
      eventType: eventType,
      data: <String, Object?>{'answers': answers},
      initiator: const UserInitiator('demo-user-1'),
      changeReason: changeReason,
      security: _stampSecurityContext ? _kDemoSecurityDetails : null,
    );
  }

  /// Build a synthetic `esd/batch@1` envelope (one event from
  /// `remote-mobile-1`) and feed it through `EventStore.ingestBatch`.
  /// Plan 4.15 Task 5 Step 1. Surfaces the receiver-stamped
  /// `origin_sequence_number` for demo of REQ-d00115-K.
  Future<void> _ingestSyntheticBatch() async {
    final envelope = _syntheticBatch.buildSingleEventBatch();
    await widget.datastore.eventStore.ingestBatch(
      envelope.encode(),
      wireFormat: BatchEnvelope.wireFormat,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: DemoColors.bg, border: demoBorder),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _lifecycleRow(),
          const SizedBox(height: 4),
          _actionsSystemRow(),
        ],
      ),
    );
  }

  Widget _lifecycleRow() {
    return Row(
      children: <Widget>[
        const SizedBox(
          width: 100,
          child: Text('demo_note', style: TextStyle(color: DemoColors.accent)),
        ),
        _miniField(_title, 'title'),
        _miniField(_body, 'body'),
        _btn(
          label: 'Start',
          onTap: () async {
            final aggId = _uuid.v7();
            await _record(
              entryType: 'demo_note',
              aggregateId: aggId,
              eventType: 'checkpoint',
              answers: _collectAnswers(),
            );
            widget.appState.selectAggregate(aggId);
          },
        ),
        _btn(
          label: 'Complete',
          onTap: () async {
            final aggId = widget.appState.selectedAggregateId;
            if (aggId == null) return;
            await _record(
              entryType: 'demo_note',
              aggregateId: aggId,
              eventType: 'finalized',
              answers: _collectAnswers(),
              changeReason: 'complete',
            );
          },
          dim: widget.appState.selectedAggregateId == null,
        ),
        _btn(
          label: 'Delete',
          onTap: () async {
            final aggId = widget.appState.selectedAggregateId;
            if (aggId == null) return;
            await _record(
              entryType: 'demo_note',
              aggregateId: aggId,
              eventType: 'tombstone',
              answers: <String, Object?>{},
              changeReason: 'delete',
            );
          },
          dim: widget.appState.selectedAggregateId == null,
        ),
      ],
    );
  }

  Widget _actionsSystemRow() {
    return Row(
      children: <Widget>[
        const SizedBox(
          width: 100,
          child: Text('actions', style: TextStyle(color: DemoColors.accent)),
        ),
        _actionBtn(
          label: 'RED',
          color: DemoColors.red,
          entryType: 'red_button_pressed',
        ),
        _actionBtn(
          label: 'GREEN',
          color: DemoColors.green,
          entryType: 'green_button_pressed',
        ),
        _actionBtn(
          label: 'BLUE',
          color: DemoColors.blue,
          entryType: 'blue_button_pressed',
        ),
        const SizedBox(width: 24),
        const SizedBox(
          width: 80,
          child: Text('system', style: TextStyle(color: DemoColors.accent)),
        ),
        _btn(
          label: 'Ingest batch',
          onTap: () async {
            try {
              await _ingestSyntheticBatch();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ingested 1-event esd/batch@1 envelope'),
                ),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Ingest failed: $e')));
            }
          },
        ),
        _securityToggle(),
        _btn(
          label: 'Add destination',
          onTap: () async {
            await showDialog<void>(
              context: context,
              builder: (_) => AddDestinationDialog(appState: widget.appState),
            );
          },
        ),
        _btn(
          label: 'Rebuild view',
          onTap: () async {
            try {
              final count = await rebuildMaterializedView(
                widget.backend,
                widget.entryTypesLookup,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Rebuilt $count aggregates')),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Rebuild failed: $e')));
            }
          },
        ),
        _btn(
          label: 'Reset all',
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: DemoColors.bg,
                title: const Text(
                  'Reset all?',
                  style: TextStyle(color: DemoColors.fg),
                ),
                content: const Text(
                  'Cancels the sync tick, closes sembast, deletes '
                  'demo.db. The app will need to be restarted.',
                  style: TextStyle(color: DemoColors.fg),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: DemoColors.fg),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      'Reset',
                      style: TextStyle(color: DemoColors.red),
                    ),
                  ),
                ],
              ),
            );
            if (ok ?? false) {
              await widget.onResetAll();
            }
          },
        ),
      ],
    );
  }

  Widget _miniField(
    TextEditingController ctrl,
    String hint, {
    double width = 110,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: DemoColors.fg, fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: DemoColors.pending, fontSize: 11),
          isDense: true,
        ),
      ),
    );
  }

  Widget _btn({
    required String label,
    required Future<void> Function() onTap,
    bool dim = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: dim ? null : () async => onTap(),
        child: Text(
          label,
          style: TextStyle(
            color: dim ? DemoColors.pending : DemoColors.fg,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  /// Plan §4.15.A toggle. ON → subsequent `_record` calls stamp
  /// `SecurityDetails`; OFF → no security context (preserves the
  /// empty-AUDIT case for demo pedagogy).
  Widget _securityToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'sec ctx',
            style: TextStyle(
              color: DemoColors.fg,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          Switch(
            value: _stampSecurityContext,
            activeThumbColor: DemoColors.green,
            inactiveThumbColor: DemoColors.pending,
            inactiveTrackColor: DemoColors.bg,
            onChanged: (v) {
              setState(() => _stampSecurityContext = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required Color color,
    required String entryType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: () async {
          final aggId = _uuid.v7();
          await _record(
            entryType: entryType,
            aggregateId: aggId,
            eventType: 'finalized',
            answers: <String, Object?>{
              'pressed_at': DateTime.now().toUtc().toIso8601String(),
            },
          );
        },
        style: TextButton.styleFrom(backgroundColor: color),
        child: Text(
          label,
          style: const TextStyle(
            color: DemoColors.bg,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
