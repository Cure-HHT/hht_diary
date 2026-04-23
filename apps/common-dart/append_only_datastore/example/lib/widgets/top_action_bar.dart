import 'dart:math';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:append_only_datastore_demo/app_state.dart';
import 'package:append_only_datastore_demo/demo_types.dart';
import 'package:append_only_datastore_demo/widgets/add_destination_dialog.dart';
import 'package:append_only_datastore_demo/widgets/styles.dart';
import 'package:flutter/material.dart';

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
  final TextEditingController _mood = TextEditingController();

  final Random _rng = Random();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _mood.dispose();
    super.dispose();
  }

  String _uuidish() {
    final a = _rng.nextInt(1 << 30).toRadixString(16).padLeft(8, '0');
    final b = _rng.nextInt(1 << 30).toRadixString(16).padLeft(8, '0');
    return '$a-$b';
  }

  Map<String, Object?> _collectAnswers() {
    final m = <String, Object?>{
      'title': _title.text,
      'body': _body.text,
      'date': DateTime.now().toUtc().toIso8601String(),
    };
    final mood = int.tryParse(_mood.text);
    if (mood != null) m['mood'] = mood;
    return m;
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
      aggregateId: aggregateId,
      aggregateType: aggregateType,
      eventType: eventType,
      data: <String, Object?>{'answers': answers},
      initiator: const UserInitiator('demo-user-1'),
      changeReason: changeReason,
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
        _miniField(_mood, 'mood', width: 60),
        _btn(
          label: 'Start',
          onTap: () async {
            final aggId = _uuidish();
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Rebuilt $count rows')));
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

  Widget _actionBtn({
    required String label,
    required Color color,
    required String entryType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: () async {
          final aggId = _uuidish();
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
