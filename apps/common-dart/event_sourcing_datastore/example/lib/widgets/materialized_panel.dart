import 'dart:async';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:event_sourcing_datastore_demo/app_state.dart';
import 'package:event_sourcing_datastore_demo/widgets/styles.dart';
import 'package:flutter/material.dart';

// Validated by: JNY-01 materialized lifecycle; JNY-06 rebuild idempotence.
class MaterializedPanel extends StatefulWidget {
  const MaterializedPanel({
    required this.backend,
    required this.appState,
    super.key,
  });

  final StorageBackend backend;
  final AppState appState;

  @override
  State<MaterializedPanel> createState() => _MaterializedPanelState();
}

class _MaterializedPanelState extends State<MaterializedPanel> {
  List<DiaryEntry> _rows = const <DiaryEntry>[];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onAppState);
    _poll = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _refresh(),
    );
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    widget.appState.removeListener(_onAppState);
    super.dispose();
  }

  void _onAppState() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refresh() async {
    try {
      final rows = await widget.backend.findEntries(entryType: 'demo_note');
      if (!mounted) return;
      setState(() {
        _rows = rows;
      });
    } catch (_) {
      // Transient read failure — next poll retries. Non-fatal for demo.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Most-recent first: sort descending by updatedAt.
    final sorted = <DiaryEntry>[..._rows]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Container(
      decoration: BoxDecoration(color: DemoColors.bg, border: demoBorder),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('MATERIALIZED', style: DemoText.header),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: sorted.length,
              itemBuilder: (context, i) => _MaterializedRow(
                row: sorted[i],
                selected:
                    widget.appState.selectedAggregateId == sorted[i].entryId,
                onTap: () => widget.appState.selectAggregate(sorted[i].entryId),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterializedRow extends StatelessWidget {
  const _MaterializedRow({
    required this.row,
    required this.selected,
    required this.onTap,
  });

  final DiaryEntry row;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final short = row.entryId.length >= 8
        ? row.entryId.substring(0, 8)
        : row.entryId;
    final status = row.isDeleted
        ? 'del'
        : row.isComplete
        ? 'ok '
        : 'ptl';
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? DemoColors.selected : DemoColors.bg,
          border: selected ? demoSelectedBorder : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text('agg-$short [$status]', style: DemoText.body),
      ),
    );
  }
}
