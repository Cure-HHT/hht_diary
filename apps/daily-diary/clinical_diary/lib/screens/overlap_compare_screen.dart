// lib/screens/overlap_compare_screen.dart
// Implements: DIARY-GUI-entry-overlap-resolution/A+B+C+D — side-by-side resolve
//   view. Reactive: while both entries exist and overlap it renders the compare
//   body; once the pair is resolved it auto-pops. Resolution emits ordinary
//   events (edit_epistaxis_event / delete_entry duplicate). Merge copies the
//   boundary entries' stored timestamps VERBATIM (no reformatting) so the
//   recorded wall-clock + timezone are preserved.
import 'dart:async';

import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_overlap.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:clinical_diary/read/diary_view_builder.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

class OverlapCompareScreen extends StatefulWidget {
  const OverlapCompareScreen({
    required this.leftId,
    required this.rightId,
    super.key,
  });

  /// The pre-existing entry id (rendered on the left).
  final String leftId;

  /// The just-touched entry id (rendered on the right).
  final String rightId;

  @override
  State<OverlapCompareScreen> createState() => _OverlapCompareScreenState();
}

class _OverlapCompareScreenState extends State<OverlapCompareScreen> {
  bool _popped = false;

  /// True once the view has been seen with BOTH entries present and overlapping
  /// at least once. Before that we are in an initial loading window and must
  /// not auto-pop on an empty view.
  bool _everSawBothEntries = false;

  EpistaxisEntryView? _find(DiaryView view, String id) {
    for (final r in view.finalizedRows) {
      if (r.aggregateId == id && r.entryType == 'epistaxis_event') {
        return diaryEntryViewOf(r, isComplete: true) as EpistaxisEntryView;
      }
    }
    return null;
  }

  void _popResolved() {
    if (_popped) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Only pop if WE are the current route. An Edit RecordingScreen may be
      // pushed on top of this one; a resolving emission that arrives while it
      // is up must NOT pop that child out from under the user. Latch only once
      // we actually pop, so the pop is retried on a later build (once the Edit
      // route has been dismissed and this screen is current again).
      if (ModalRoute.of(context)?.isCurrent != true) return;
      _popped = true;
      Navigator.of(context).maybePop();
    });
  }

  Future<void> _submit(String action, Map<String, Object?> input) =>
      ReActionScope.of(context).actionSubmitter.submit(
        ActionSubmission(actionName: action, rawInput: input),
      );

  Future<void> _deleteAsDuplicate(EpistaxisEntryView entry) =>
      _submit('delete_entry', <String, Object?>{
        'aggregateId': entry.aggregateId,
        'entryType': 'epistaxis_event',
        'changeReason': 'duplicate',
      });

  void _showMergeSheet(EpistaxisEntryView left, EpistaxisEntryView right) {
    showModalBottomSheet<void>(
      context: context,
      // onConfirm is called synchronously during the confirm button tap so that
      // both actions are submitted before the sheet's close animation runs —
      // this keeps the submission testable with a single pump() after the tap.
      builder: (_) => _MergeSheet(
        left: left,
        right: right,
        onConfirm: (payload) {
          // Fire-and-forget: the edit lands first (left now spans the union),
          // then the right is tombstoned. If the delete fails the pair simply
          // re-derives as still overlapping and re-surfaces — no data loss. The
          // reactive view + persistent banner are the backstop, so the dispatch
          // results need not be awaited here.
          unawaited(
            _submit('edit_epistaxis_event', <String, Object?>{
              'aggregateId': left.aggregateId,
              ...payload,
            }),
          );
          unawaited(_deleteAsDuplicate(right));
        },
      ),
    );
  }

  Future<void> _edit(EpistaxisEntryView entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute<String?>(
        builder: (_) =>
            RecordingScreen(existing: entry, fromOverlapResolution: true),
      ),
    );
    // On return the DiaryViewBuilder re-derives: still overlapping -> re-render;
    // resolved -> auto-pop. The `fromOverlapResolution` flag keeps the edit's
    // finalize from pushing ANOTHER compare screen on top of this one.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // TODO(i18n): localize.
        title: const Text('Resolve overlap'),
      ),
      body: DiaryViewBuilder(
        builder: (context, DiaryView view) {
          final left = _find(view, widget.leftId);
          final right = _find(view, widget.rightId);
          final live =
              left != null &&
              right != null &&
              epistaxisRangesOverlap(left, right);
          if (!live) {
            // Not a live overlapping pair. Two cases:
            //  - we previously saw the pair -> it is now resolved (a row was
            //    tombstoned by pick/merge, or an edit removed the overlap) ->
            //    auto-pop back to wherever we came from;
            //  - we have never seen the pair yet -> the view is still
            //    bootstrapping -> show nothing and wait.
            if (_everSawBothEntries) _popResolved();
            return const SizedBox.shrink();
          }
          // Monotonic latch: once true it never resets. Set here in build
          // intentionally — it gates the auto-pop above and never needs to
          // trigger a rebuild of its own (this build already renders the body).
          _everSawBothEntries = true;
          return _CompareBody(
            left: left,
            right: right,
            onPickLeft: () => _deleteAsDuplicate(right),
            onPickRight: () => _deleteAsDuplicate(left),
            onMerge: () => _showMergeSheet(left, right),
            onEditLeft: () => _edit(left),
            onEditRight: () => _edit(right),
          );
        },
      ),
    );
  }
}

class _CompareBody extends StatelessWidget {
  const _CompareBody({
    required this.left,
    required this.right,
    required this.onPickLeft,
    required this.onPickRight,
    required this.onMerge,
    required this.onEditLeft,
    required this.onEditRight,
  });

  final EpistaxisEntryView left;
  final EpistaxisEntryView right;
  final VoidCallback onPickLeft;
  final VoidCallback onPickRight;
  final VoidCallback onMerge;
  final VoidCallback onEditLeft;
  final VoidCallback onEditRight;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TODO(i18n): localize labels.
          const Text(
            'Two records overlap. Resolve them into the one nosebleed.',
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _EntryCard(
                  title: 'Already recorded',
                  entry: left,
                  onEdit: onEditLeft,
                  editKey: const Key('overlap-edit-left'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _EntryCard(
                  title: 'Just entered',
                  entry: right,
                  onEdit: onEditRight,
                  editKey: const Key('overlap-edit-right'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('overlap-merge'),
            onPressed: onMerge,
            child: const Text('Merge into one'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('overlap-pick-left'),
            onPressed: onPickLeft,
            child: const Text('Keep already recorded'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('overlap-pick-right'),
            onPressed: onPickRight,
            child: const Text('Keep just entered'),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.title,
    required this.entry,
    required this.onEdit,
    required this.editKey,
  });

  final String title;
  final EpistaxisEntryView entry;
  final VoidCallback onEdit;
  final Key editKey;

  String _fmt(DateTime? t) =>
      t == null ? '--:--' : DateFormat.jm().format(t.toLocal());

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text('${_fmt(entry.startTime)} - ${_fmt(entry.endTime)}'),
            if (entry.intensity != null) Text(entry.intensity!.name),
            const SizedBox(height: 8),
            TextButton(
              key: editKey,
              onPressed: onEdit,
              child: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Merge configuration sheet: shows the union span and requires a severity
/// choice. START fields are copied verbatim from the entry with the earlier
/// start; END fields from the entry with the later end. Verbatim copy preserves
/// the exact recorded wall-clock + timezone/offset. An open-ended boundary entry
/// (no endTime) leaves the merged entry open-ended too. To adjust a time, use
/// Edit on either entry before merging.
///
/// [onConfirm] is called synchronously when the confirm button is tapped, with
/// the computed merge payload. The caller is responsible for dispatching the
/// edit+delete actions and closing the sheet.
class _MergeSheet extends StatefulWidget {
  const _MergeSheet({
    required this.left,
    required this.right,
    required this.onConfirm,
  });
  final EpistaxisEntryView left;
  final EpistaxisEntryView right;
  final void Function(Map<String, Object?> payload) onConfirm;

  @override
  State<_MergeSheet> createState() => _MergeSheetState();
}

class _MergeSheetState extends State<_MergeSheet> {
  late final EpistaxisEntryView _startBoundary;
  late final EpistaxisEntryView _endBoundary;
  late final bool _hasEnd;
  NosebleedIntensity? _intensity;

  @override
  void initState() {
    super.initState();
    final l = widget.left;
    final r = widget.right;
    _startBoundary = l.startTime.isBefore(r.startTime) ? l : r;
    final lEnd = l.endTime ?? l.startTime;
    final rEnd = r.endTime ?? r.startTime;
    _endBoundary = lEnd.isAfter(rEnd) ? l : r;
    _hasEnd = _endBoundary.endTime != null;
    final candidates = <NosebleedIntensity>[
      if (l.intensity != null) l.intensity!,
      if (r.intensity != null) r.intensity!,
    ];
    _intensity = candidates.isEmpty
        ? null
        : candidates.reduce((a, b) => a.index >= b.index ? a : b);
  }

  Map<String, Object?> _payload() {
    final sp = EpistaxisEventPayload.fromJson(_startBoundary.row.data);
    final payload = <String, Object?>{
      'startTime': sp.startTime,
      'startTimeZone': sp.startTimeZone,
      'startTimeUtcOffset': sp.startTimeUtcOffset,
    };
    if (_hasEnd) {
      final ep = EpistaxisEventPayload.fromJson(_endBoundary.row.data);
      payload['endTime'] = ep.endTime;
      payload['endTimeZone'] = ep.endTimeZone;
      payload['endTimeUtcOffset'] = ep.endTimeUtcOffset;
    }
    if (_intensity != null) payload['intensity'] = _intensity!.name;
    return payload;
  }

  String _fmt(DateTime? t) =>
      t == null ? '--:--' : DateFormat.jm().format(t.toLocal());

  @override
  Widget build(BuildContext context) {
    final severities = <NosebleedIntensity>{
      if (widget.left.intensity != null) widget.left.intensity!,
      if (widget.right.intensity != null) widget.right.intensity!,
    }.toList();
    final unionEnd = _hasEnd ? _endBoundary.endTime : null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TODO(i18n): localize.
          const Text('Merge into one nosebleed'),
          const SizedBox(height: 8),
          Text('${_fmt(_startBoundary.startTime)} - ${_fmt(unionEnd)}'),
          if (severities.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Severity'),
            Wrap(
              spacing: 8,
              children: severities
                  .map(
                    (s) => ChoiceChip(
                      label: Text(s.name),
                      selected: _intensity == s,
                      onSelected: (_) => setState(() => _intensity = s),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('overlap-merge-confirm'),
            onPressed: () {
              // Submit actions synchronously before closing so they are
              // observable immediately after a single pump() in tests.
              widget.onConfirm(_payload());
              Navigator.of(context).pop();
            },
            child: const Text('Confirm merge'),
          ),
        ],
      ),
    );
  }
}
