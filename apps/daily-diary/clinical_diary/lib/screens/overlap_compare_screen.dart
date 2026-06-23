// lib/screens/overlap_compare_screen.dart
// Implements: DIARY-GUI-entry-overlap-resolution/A+B+C+D — side-by-side resolve
//   view. Reactive: while both entries exist and overlap it renders the compare
//   body; once the pair is resolved it auto-pops. Resolution emits ordinary
//   events (edit_epistaxis_event / delete_entry duplicate). Merge copies the
//   boundary entries' stored timestamps VERBATIM (no reformatting) so the
//   recorded wall-clock + timezone are preserved — unless a field is edited
//   on the merge review screen, in which case only that field is reformatted
//   through the same path the recording screen's save uses.
import 'dart:async';

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_overlap.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:clinical_diary/read/diary_view_builder.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/utils/date_time_formatter.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/back_to_home_row.dart';
import 'package:clinical_diary/widgets/intensity_picker.dart';
import 'package:clinical_diary/widgets/nosebleed_intensity.dart' as ui;
import 'package:clinical_diary/widgets/time_picker_dial.dart';
import 'package:diary_design_system/diary_design_system.dart';
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

  /// Auto-pops back to the caller once the pair is resolved, returning the
  /// SURVIVING entry so the caller (the recording screen's Confirm Record step)
  /// can re-point itself at live data. Keep New leaves the new entry (`right`);
  /// Keep Existing / Merge tombstone the new entry and leave the pre-existing
  /// one (`left`, merged into the union on a Merge). Returning the survivor lets
  /// the Confirm step edit a LIVE aggregate instead of the just-tombstoned new
  /// entry — editing the tombstoned id would resurrect it and re-open the
  /// overlap, looping the participant back here (CUR-1548).
  void _popResolved(EpistaxisEntryView? survivor) {
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
      Navigator.of(context).maybePop(survivor);
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
    // Figma 675:655: the merge review is a full screen (not a dialog/sheet).
    // onConfirm is called synchronously during the confirm button tap so that
    // both actions are submitted before the route's close animation runs —
    // this keeps the submission testable with a single pump() after the tap.
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _MergeReviewScreen(
            left: left,
            right: right,
            onConfirm: (payload) {
              // Fire-and-forget: the edit lands first (left now spans the
              // union), then the right is tombstoned. If the delete fails the
              // pair simply re-derives as still overlapping and re-surfaces —
              // no data loss. The reactive view + persistent banner are the
              // backstop, so the dispatch results need not be awaited here.
              unawaited(
                _submit('edit_epistaxis_event', <String, Object?>{
                  'aggregateId': left.aggregateId,
                  ...payload,
                }),
              );
              unawaited(_deleteAsDuplicate(right));
            },
          ),
        ),
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
      // Figma 675:479: the resolve view sits on the "Primary Bg" wash.
      backgroundColor: const Color(0xFFF7FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "< Back" header row (Figma 675:481).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: BackToHomeRow(
                // TODO(i18n): localize "Back".
                label: 'Back',
                semanticLabel: 'Back',
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: DiaryViewBuilder(
                builder: (context, DiaryView view) {
                  final left = _find(view, widget.leftId);
                  final right = _find(view, widget.rightId);
                  final live =
                      left != null &&
                      right != null &&
                      epistaxisRangesOverlap(left, right);
                  if (!live) {
                    // Not a live overlapping pair. Two cases:
                    //  - we previously saw the pair -> it is now resolved (a
                    //    row was tombstoned by pick/merge, or an edit removed
                    //    the overlap) -> auto-pop back to wherever we came
                    //    from, handing back the survivor;
                    //  - we have never seen the pair yet -> the view is still
                    //    bootstrapping -> show nothing and wait.
                    // Prefer the new entry (`right`) when it survives (Keep New,
                    // or an Edit that removed the overlap with both intact); the
                    // pre-existing one (`left`, merged on a Merge) otherwise.
                    if (_everSawBothEntries) _popResolved(right ?? left);
                    return const SizedBox.shrink();
                  }
                  // Monotonic latch: once true it never resets. Set here in
                  // build intentionally — it gates the auto-pop above and
                  // never needs to trigger a rebuild of its own (this build
                  // already renders the body).
                  _everSawBothEntries = true;
                  return _CompareBody(
                    left: left,
                    right: right,
                    onPickLeft: () => _deleteAsDuplicate(right),
                    onPickRight: () => _deleteAsDuplicate(left),
                    onMerge: () => _showMergeSheet(left, right),
                    onEditLeft: () => _edit(left),
                    onEditRight: () => _edit(right),
                    onCancel: () => Navigator.of(context).maybePop(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Humanizes a camelCase intensity name ('drippingQuickly' ->
/// 'Dripping quickly') as the fallback when no [AppLocalizations] scope is
/// available (e.g. bare-MaterialApp test harnesses).
String _humanizeIntensity(String name) {
  final spaced = name.replaceAllMapped(
    RegExp('([A-Z])'),
    (m) => ' ${m[1]!.toLowerCase()}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
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
    required this.onCancel,
  });

  final EpistaxisEntryView left;
  final EpistaxisEntryView right;
  final VoidCallback onPickLeft;
  final VoidCallback onPickRight;
  final VoidCallback onMerge;
  final VoidCallback onEditLeft;
  final VoidCallback onEditRight;
  final VoidCallback onCancel;

  // Figma palette (matches ColorTokens; raw tokens are not exported).
  static const Color _critical = Color(0xFFCB333B);
  static const Color _criticalBg = Color(0xFFFDEBEC);
  static const Color _primary = Color(0xFF165C7D);
  static const Color _primaryBg = Color(0xFFE8F3F7);

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date + conflict heading (Figma 675:497).
          Text(
            DateFormat('EEEE, MMM d', locale).format(right.startTime),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w500,
              height: 1.4,
              letterSpacing: -0.33,
              color: Color(0xFF54636A),
            ),
          ),
          const SizedBox(height: 8),
          // TODO(i18n): localize labels on this screen.
          const Text(
            'Please Resolve the Conflict:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              height: 1.3,
              letterSpacing: -0.33,
              color: Color(0xFF04161E),
            ),
          ),
          const SizedBox(height: 24),
          // Figma 675:581: the just-touched ("New") record on the left, the
          // pre-existing record on the right. Tapping a card opens the edit
          // flow (the dedicated Edit buttons folded into the cards).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _EntryCard(
                  title: 'New Record',
                  accent: _critical,
                  accentBg: _criticalBg,
                  entry: right,
                  onEdit: onEditRight,
                  editKey: const Key('overlap-edit-right'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _EntryCard(
                  title: 'Existing Record',
                  accent: _primary,
                  accentBg: _primaryBg,
                  entry: left,
                  onEdit: onEditLeft,
                  editKey: const Key('overlap-edit-left'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _KeepButton(
                  key: const Key('overlap-pick-right'),
                  label: 'Keep New',
                  borderColor: _critical,
                  onPressed: onPickRight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KeepButton(
                  key: const Key('overlap-pick-left'),
                  label: 'Keep Existing',
                  borderColor: _primary,
                  onPressed: onPickLeft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          const Text(
            'Or combine both into one event with the longest duration:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 17 / 14,
              letterSpacing: -0.06,
              color: Color(0xFF717182),
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            key: const Key('overlap-merge'),
            size: AppButtonSize.large,
            fullWidth: true,
            label: 'Merge Records',
            onPressed: onMerge,
          ),
          const SizedBox(height: 16),
          AppButton(
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.large,
            fullWidth: true,
            label: 'Cancel',
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// Outlined pick button under each card (Figma 675:606/633): white fill,
/// accent-colored border, Dark Grey Medium label.
class _KeepButton extends StatelessWidget {
  const _KeepButton({
    required this.label,
    required this.borderColor,
    required this.onPressed,
    super.key,
  });

  final String label;
  final Color borderColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF54636A),
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.45,
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.title,
    required this.accent,
    required this.accentBg,
    required this.entry,
    required this.onEdit,
    required this.editKey,
  });

  final String title;
  final Color accent;
  final Color accentBg;
  final EpistaxisEntryView entry;
  final VoidCallback onEdit;
  final Key editKey;

  String _fmt(DateTime? t) =>
      t == null ? '--:--' : DateFormat.jm().format(t.toLocal());

  /// "18m" / "1h 5m" duration, or "--" while the entry is open-ended.
  String get _duration {
    final end = entry.endTime;
    if (end == null) return '--';
    final mins = end.difference(entry.startTime).inMinutes;
    if (mins >= 60) return '${mins ~/ 60}h ${mins % 60}m';
    return '${mins}m';
  }

  /// Figma severity illustrations (same exports the intensity picker uses).
  static String? _severityAsset(String name) => switch (name) {
    'spotting' => 'assets/icons/figma/intensity_spotting.png',
    'dripping' => 'assets/icons/figma/intensity_dripping.png',
    'drippingQuickly' => 'assets/icons/figma/intensity_dripping_quickly.png',
    'steadyStream' => 'assets/icons/figma/intensity_steady_stream.png',
    'pouring' => 'assets/icons/figma/intensity_pouring.png',
    'gushing' => 'assets/icons/figma/intensity_gushing.png',
    _ => null,
  };

  static const _labelStyle = TextStyle(
    fontSize: 13,
    height: 17 / 13,
    letterSpacing: -0.06,
    color: Color(0xFF54636A),
  );

  static const _valueStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 21.25 / 15,
    letterSpacing: -0.22,
    color: Color(0xFF04161E),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final intensityName = entry.intensity?.name;
    final asset = intensityName == null ? null : _severityAsset(intensityName);

    // Figma 675:583/610: white card, 3px accent top bar, tinted header strip,
    // Light Gray hairline body border.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFECEEF0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: editKey,
          onTap: onEdit,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 3, color: accent),
              Container(
                color: accentBg,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 21.25 / 15,
                    letterSpacing: -0.22,
                    color: accent,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Time', style: _labelStyle),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_fmt(entry.startTime)} - ${_fmt(entry.endTime)}',
                        style: _valueStyle,
                      ),
                    ),
                    const SizedBox(height: 13),
                    const Text('Duration', style: _labelStyle),
                    const SizedBox(height: 4),
                    Text(_duration, style: _valueStyle),
                    const SizedBox(height: 13),
                    const Text('Severity', style: _labelStyle),
                    const SizedBox(height: 4),
                    if (intensityName != null)
                      Row(
                        children: [
                          if (asset != null) ...[
                            Image.asset(
                              asset,
                              width: 34,
                              height: 34,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              l10n?.intensityName(intensityName) ??
                                  _humanizeIntensity(intensityName),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _valueStyle,
                            ),
                          ),
                        ],
                      )
                    else
                      const Text('--', style: _valueStyle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Merge review screen (Figma 675:655): shows the union span and the chosen
/// severity in the recording-flow summary-bar style, with Save Changes /
/// Cancel actions. START fields are copied verbatim from the entry with the
/// earlier start; END fields from the entry with the later end. Verbatim copy
/// preserves the exact recorded wall-clock + timezone/offset. An open-ended
/// boundary entry (no endTime) leaves the merged entry open-ended too. To
/// adjust a time, use Edit on either entry before merging. Tapping the
/// Max Intensity field cycles through the two records' severities.
///
/// [onConfirm] is called synchronously when the Save Changes button is
/// tapped, with the computed merge payload. The caller is responsible for
/// dispatching the edit+delete actions; this screen pops itself.
class _MergeReviewScreen extends StatefulWidget {
  const _MergeReviewScreen({
    required this.left,
    required this.right,
    required this.onConfirm,
  });
  final EpistaxisEntryView left;
  final EpistaxisEntryView right;
  final void Function(Map<String, Object?> payload) onConfirm;

  @override
  State<_MergeReviewScreen> createState() => _MergeReviewScreenState();
}

/// Editing step within the merge review screen — mirrors the recording
/// flow's step model so any merged field can be edited before saving.
enum _MergeStep { review, startTime, intensity, endTime }

class _MergeReviewScreenState extends State<_MergeReviewScreen> {
  late final EpistaxisEntryView _startBoundary;
  late final EpistaxisEntryView _endBoundary;
  late final bool _hasEnd;

  // Verbatim boundary payloads — the source of the preserved timestamp
  // strings when a field is NOT edited on this screen.
  late final EpistaxisEventPayload _startPayload;
  EpistaxisEventPayload? _endPayload;

  // Live (editable) merged values, seeded from the boundary entries.
  late DateTime _startDateTime;
  DateTime? _endDateTime;
  String? _startTimeZone;
  String? _endTimeZone;
  NosebleedIntensity? _intensity;

  _MergeStep _step = _MergeStep.review;

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
    _startPayload = EpistaxisEventPayload.fromJson(_startBoundary.row.data);
    _endPayload = _hasEnd
        ? EpistaxisEventPayload.fromJson(_endBoundary.row.data)
        : null;
    _startDateTime = _startBoundary.startTime;
    _endDateTime = _hasEnd ? _endBoundary.endTime : null;
    _startTimeZone = _startPayload.startTimeZone;
    _endTimeZone = _endPayload?.endTimeZone;
    final candidates = <NosebleedIntensity>[
      if (l.intensity != null) l.intensity!,
      if (r.intensity != null) r.intensity!,
    ];
    _intensity = candidates.isEmpty
        ? null
        : candidates.reduce((a, b) => a.index >= b.index ? a : b);
  }

  /// Whether the start field diverged from the boundary entry. While false
  /// the payload carries the boundary's stored strings VERBATIM.
  bool get _startEdited =>
      _startDateTime != _startBoundary.startTime ||
      _startTimeZone != _startPayload.startTimeZone;

  bool get _endEdited =>
      _endDateTime != (_hasEnd ? _endBoundary.endTime : null) ||
      _endTimeZone != _endPayload?.endTimeZone;

  /// Derives the ISO UTC offset for a formatted timestamp — same rules as the
  /// recording screen's save path.
  static String _utcOffsetOf(String iso, String? timezone) {
    final embedded = DateTimeFormatter.extractTimezoneOffset(iso);
    if (embedded != null && embedded != 'Z') return embedded;
    if (embedded == 'Z') return '+00:00';
    final mins = TimezoneConverter.getTimezoneOffsetMinutes(timezone);
    if (mins == null) return '+00:00';
    final sign = mins.isNegative ? '-' : '+';
    final h = (mins.abs() ~/ 60).toString().padLeft(2, '0');
    final m = (mins.abs() % 60).toString().padLeft(2, '0');
    return '$sign$h:$m';
  }

  Map<String, Object?> _payload() {
    final payload = <String, Object?>{
      // Preserve the merged entry's participant attribution (the boundary
      // rows are the same participant's entries).
      'participantId': _startPayload.participantId,
    };
    if (_startEdited) {
      final iso = DateTimeFormatter.format(_startDateTime);
      payload['startTime'] = iso;
      payload['startTimeZone'] = _startTimeZone ?? _startPayload.startTimeZone;
      payload['startTimeUtcOffset'] = _utcOffsetOf(iso, _startTimeZone);
    } else {
      payload['startTime'] = _startPayload.startTime;
      payload['startTimeZone'] = _startPayload.startTimeZone;
      payload['startTimeUtcOffset'] = _startPayload.startTimeUtcOffset;
    }
    final end = _endDateTime;
    if (end != null) {
      final endPayload = _endPayload;
      if (!_endEdited && endPayload != null) {
        payload['endTime'] = endPayload.endTime;
        payload['endTimeZone'] = endPayload.endTimeZone;
        payload['endTimeUtcOffset'] = endPayload.endTimeUtcOffset;
      } else {
        final iso = DateTimeFormatter.format(end);
        final zone = _endTimeZone ?? _startTimeZone;
        payload['endTime'] = iso;
        payload['endTimeZone'] = zone;
        payload['endTimeUtcOffset'] = _utcOffsetOf(iso, zone);
      }
    }
    if (_intensity != null) payload['intensity'] = _intensity!.name;
    return payload;
  }

  String _fmtDisplay(DateTime? t, String? zone, String locale) => t == null
      ? '--:--'
      : DateFormat.jm(
          locale,
        ).format(TimezoneConverter.toDisplayedDateTime(t, zone));

  void _handleStartConfirm(DateTime displayed) {
    final stored = TimezoneConverter.toStoredDateTime(
      displayed,
      _startTimeZone,
    );
    setState(() {
      _startDateTime = stored;
      _step = _MergeStep.review;
    });
  }

  void _handleEndConfirm(DateTime displayed) {
    final stored = TimezoneConverter.toStoredDateTime(displayed, _endTimeZone);
    if (!stored.isAfter(_startDateTime)) {
      final l10n = Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.endTimeAfterStart ?? 'End time must be after start time',
          ),
        ),
      );
      return;
    }
    setState(() {
      _endDateTime = stored;
      _step = _MergeStep.review;
    });
  }

  void _handleStartTimezoneChanged(String newTimezone) {
    if (newTimezone == _startTimeZone) return;
    final adjusted = TimezoneConverter.recalculateForTimezoneChange(
      _startDateTime,
      _startTimeZone,
      newTimezone,
    );
    setState(() {
      _startDateTime = adjusted;
      _startTimeZone = newTimezone;
    });
  }

  void _handleEndTimezoneChanged(String newTimezone) {
    if (newTimezone == _endTimeZone) return;
    final end = _endDateTime;
    if (end == null) {
      setState(() => _endTimeZone = newTimezone);
      return;
    }
    final adjusted = TimezoneConverter.recalculateForTimezoneChange(
      end,
      _endTimeZone,
      newTimezone,
    );
    setState(() {
      _endDateTime = adjusted;
      _endTimeZone = newTimezone;
    });
  }

  /// The editor for the active step — the same widgets the recording flow
  /// uses (TimePickerDial / IntensityPicker).
  Widget _buildStep(AppLocalizations? l10n) {
    switch (_step) {
      case _MergeStep.startTime:
        return TimePickerDial(
          key: const ValueKey('merge_start_time_picker'),
          title: l10n?.nosebleedStart ?? 'Nosebleed Start',
          initialTime: TimezoneConverter.toDisplayedDateTime(
            _startDateTime,
            _startTimeZone,
          ),
          initialTimezone: _startTimeZone,
          onConfirm: _handleStartConfirm,
          onTimezoneChanged: _handleStartTimezoneChanged,
          confirmLabel: l10n?.setStartTime ?? 'Set Start Time',
        );

      case _MergeStep.endTime:
        final initial = _endDateTime ?? _startDateTime;
        final zone = _endTimeZone ?? _startTimeZone;
        return TimePickerDial(
          key: const ValueKey('merge_end_time_picker'),
          title: l10n?.nosebleedEndTime ?? 'Nosebleed End Time',
          initialTime: TimezoneConverter.toDisplayedDateTime(initial, zone),
          initialTimezone: zone,
          onConfirm: _handleEndConfirm,
          onTimezoneChanged: _handleEndTimezoneChanged,
          confirmLabel: l10n?.setEndTime ?? 'Set End Time',
        );

      case _MergeStep.intensity:
        return IntensityPicker(
          key: const ValueKey('merge_intensity_picker'),
          selectedIntensity: _intensity == null
              ? null
              : ui.NosebleedIntensity.fromString(_intensity!.name),
          onSelect: (selected) => setState(() {
            // Same-name enums on both sides (the recording flow relies on
            // this too).
            _intensity = NosebleedIntensity.values.byName(selected.name);
            _step = _MergeStep.review;
          }),
        );

      case _MergeStep.review:
        // Never reached — review renders inline in build.
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final intensityName = _intensity?.name;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: BackToHomeRow(
                  // TODO(i18n): localize "Back".
                  label: 'Back',
                  semanticLabel: 'Back',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    DateFormat('EEEE, MMM d', locale).format(_startDateTime),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      letterSpacing: -0.33,
                      color: Color(0xFF54636A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // TODO(i18n): localize labels on this screen.
                  const Text(
                    'Edit Record',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      letterSpacing: -0.33,
                      color: Color(0xFF04161E),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Merged-record summary bar (Figma 675:801, same chrome as
                  // the recording flow's summary bar). Tapping a segment opens
                  // its editor below, like the recording screen.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEEF0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MergeSummaryItem(
                            label: 'Start',
                            value: _fmtDisplay(
                              _startDateTime,
                              _startTimeZone,
                              locale,
                            ),
                            isActive: _step == _MergeStep.startTime,
                            onTap: () =>
                                setState(() => _step = _MergeStep.startTime),
                          ),
                        ),
                        _divider(),
                        Expanded(
                          child: _MergeSummaryItem(
                            label: 'Max Intensity',
                            value: intensityName == null
                                ? '--'
                                : l10n?.intensityName(intensityName) ??
                                      _humanizeIntensity(intensityName),
                            isActive: _step == _MergeStep.intensity,
                            onTap: () =>
                                setState(() => _step = _MergeStep.intensity),
                          ),
                        ),
                        _divider(),
                        Expanded(
                          child: _MergeSummaryItem(
                            label: 'End',
                            value: _fmtDisplay(
                              _endDateTime,
                              _endTimeZone ?? _startTimeZone,
                              locale,
                            ),
                            isActive: _step == _MergeStep.endTime,
                            onTap: () =>
                                setState(() => _step = _MergeStep.endTime),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _step != _MergeStep.review
                  ? _buildStep(l10n)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Tap any field to edit it.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 17 / 14,
                              letterSpacing: -0.06,
                              color: Color(0xFF717182),
                            ),
                          ),
                          const SizedBox(height: 56),
                          AppButton(
                            key: const Key('overlap-merge-confirm'),
                            size: AppButtonSize.large,
                            fullWidth: true,
                            label: 'Save Changes',
                            onPressed: () {
                              // Submit actions synchronously before closing
                              // so they are observable immediately after a
                              // single pump() in tests.
                              widget.onConfirm(_payload());
                              Navigator.of(context).pop();
                            },
                          ),
                          const SizedBox(height: 16),
                          AppButton(
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.large,
                            fullWidth: true,
                            label: 'Cancel',
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 56,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: const Color(0xFFA4B9C2).withValues(alpha: 0.5),
  );
}

/// One Start / Max Intensity / End segment of the merge summary bar. The
/// active (being-edited) segment gets the white chip, like the recording
/// flow's summary bar.
class _MergeSummaryItem extends StatelessWidget {
  const _MergeSummaryItem({
    required this.label,
    required this.value,
    this.isActive = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 17 / 12,
                letterSpacing: -0.06,
                color: Color(0xFF54636A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 25.5 / 16,
                letterSpacing: -0.43,
                color: Color(0xFF04161E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
