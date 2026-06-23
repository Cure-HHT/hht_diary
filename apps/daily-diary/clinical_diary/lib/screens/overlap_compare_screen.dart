// lib/screens/overlap_compare_screen.dart
// Implements: DIARY-GUI-entry-overlap-resolution/A+B+C+D — side-by-side resolve
//   view. Reactive: while both entries exist and overlap it renders the compare
//   body; once the pair is resolved it auto-pops. Resolution emits ordinary
//   events (delete_entry duplicate; the surviving record's edit is written by
//   the recording flow's single Confirm Record save). EVERY choice — Keep New,
//   Keep Existing, Merge — routes through that one Confirm Record step so the
//   participant reviews + confirms exactly once (CUR-1548 follow-up). Merge
//   tombstones the new entry and hands back an [OverlapMergePrefill] (the union
//   span + max severity) so the Confirm Record step shows the merged result;
//   the confirming save then writes it onto the surviving (pre-existing) entry.
import 'dart:async';

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_overlap.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:clinical_diary/read/diary_view_builder.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/widgets/back_to_home_row.dart';
import 'package:diary_design_system/diary_design_system.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

/// The resolution action the participant committed on the Resolution Screen.
/// Carried back to the recording flow (in [OverlapResolutionResult]) so it can
/// pre-fill the Confirm Record step correctly (notably: a Merge pre-fills the
/// union span rather than the surviving entry's stored data).
enum OverlapResolution { keepNew, keepExisting, merge }

/// The merged-record values handed to the recording flow's Confirm Record step
/// when the participant chooses Merge. The merge writes nothing itself — the
/// single confirming save edits the surviving (pre-existing) entry to these
/// values, so the whole flow ends in exactly one save (CUR-1548 follow-up).
/// START comes from the entry with the earlier start, END from the entry with
/// the later end, and intensity is the higher (more severe) of the two.
class OverlapMergePrefill {
  const OverlapMergePrefill({
    required this.startTime,
    required this.startTimeZone,
    required this.endTime,
    required this.endTimeZone,
    required this.intensity,
  });

  final DateTime startTime;
  final String? startTimeZone;
  final DateTime? endTime;
  final String? endTimeZone;
  final NosebleedIntensity? intensity;
}

/// What [OverlapCompareScreen] hands back: the entry the participant chose to
/// keep, the action, the id of the entry to discard, and (for Merge) the union
/// pre-fill.
///
/// In `deferApplication` mode (the recording flow) the screen writes NOTHING —
/// it pops this choice immediately on a button tap and the recording flow's
/// single Confirm Record save applies it atomically (edit [survivor] + delete
/// [loserId]). That keeps the resolution reversible: until the participant
/// confirms, both entries still exist, so Back can re-open the Resolution screen
/// with the pair intact and nothing changed.
///
/// [action] is null when the overlap resolved reactively without an explicit
/// pick (e.g. an Edit on the compare screen removed the overlap); then [loserId]
/// is also null and the caller just reviews the surviving entry.
class OverlapResolutionResult {
  const OverlapResolutionResult({
    this.survivor,
    this.action,
    this.loserId,
    this.mergedPrefill,
  });

  /// The entry the participant chose to keep (and, for Merge, the one the union
  /// is written onto), or null if the pair vanished entirely.
  final EpistaxisEntryView? survivor;

  /// Which action the participant committed, when known.
  final OverlapResolution? action;

  /// The id of the entry to tombstone when the resolution is confirmed. Null for
  /// a reactive (Edit-removed) resolution, which discards nothing.
  final String? loserId;

  /// For Merge: the union values to pre-fill the Confirm Record step with,
  /// overriding the survivor's stored data. Null for Keep New / Keep Existing.
  final OverlapMergePrefill? mergedPrefill;
}

class OverlapCompareScreen extends StatefulWidget {
  const OverlapCompareScreen({
    required this.leftId,
    required this.rightId,
    this.deferApplication = false,
    super.key,
  });

  /// The pre-existing entry id (rendered on the left).
  final String leftId;

  /// The just-touched entry id (rendered on the right).
  final String rightId;

  /// When true (the recording flow), a pick/merge writes nothing and instead
  /// pops an [OverlapResolutionResult] for the caller to apply on confirm —
  /// keeping the choice reversible (Back re-opens this screen with both entries
  /// intact). When false (the home banner), the choice is applied immediately
  /// here and the screen reactively auto-pops once the pair resolves.
  final bool deferApplication;

  @override
  State<OverlapCompareScreen> createState() => _OverlapCompareScreenState();
}

class _OverlapCompareScreenState extends State<OverlapCompareScreen> {
  bool _popped = false;

  /// True once the view has been seen with BOTH entries present and overlapping
  /// at least once. Before that we are in an initial loading window and must
  /// not auto-pop on an empty view.
  bool _everSawBothEntries = false;

  /// The action the participant committed (set synchronously when they tap a
  /// resolution button), read by the reactive auto-pop so the result handed
  /// back to the caller carries WHICH choice resolved the pair. Null until a
  /// choice is made (e.g. an Edit removed the overlap).
  OverlapResolution? _resolution;

  /// The union pre-fill captured at Merge-tap time (while both entries are
  /// still live), handed back so the recording flow's Confirm Record step shows
  /// the merged result. Null unless the participant chose Merge.
  OverlapMergePrefill? _mergePrefill;

  EpistaxisEntryView? _find(DiaryView view, String id) {
    for (final r in view.finalizedRows) {
      if (r.aggregateId == id && r.entryType == 'epistaxis_event') {
        return diaryEntryViewOf(r, isComplete: true) as EpistaxisEntryView;
      }
    }
    return null;
  }

  /// REACTIVE auto-pop: fires when the pair stops overlapping on its own — i.e.
  /// an Edit on the compare screen removed the overlap, or (in the non-deferred
  /// home path) a pick/merge tombstoned a row. Hands back the surviving entry so
  /// the caller can review it; no loser id because nothing further needs
  /// discarding (the resolution already applied).
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
      Navigator.of(context).maybePop(
        OverlapResolutionResult(
          survivor: survivor,
          action: _resolution,
          mergedPrefill: _mergePrefill,
        ),
      );
    });
  }

  /// DEFERRED pop (recording flow): pops the choice immediately on the button
  /// tap WITHOUT writing anything, so the recording flow applies it atomically
  /// on confirm and Back can re-open this screen with both entries intact.
  void _resolveDeferred({
    required OverlapResolution action,
    required EpistaxisEntryView survivor,
    required String loserId,
    OverlapMergePrefill? mergedPrefill,
  }) {
    if (_popped) return;
    _popped = true;
    Navigator.of(context).pop(
      OverlapResolutionResult(
        survivor: survivor,
        action: action,
        loserId: loserId,
        mergedPrefill: mergedPrefill,
      ),
    );
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

  /// Keep New / Keep Existing. Deferred (recording flow): pops the choice with
  /// no write, so the Confirm Record save applies it and Back stays reversible.
  /// Immediate (home banner): tombstones the [loser] now and reactively auto-pops.
  void _pick({
    required OverlapResolution action,
    required EpistaxisEntryView survivor,
    required EpistaxisEntryView loser,
  }) {
    if (widget.deferApplication) {
      _resolveDeferred(
        action: action,
        survivor: survivor,
        loserId: loser.aggregateId,
      );
      return;
    }
    _resolution = action;
    unawaited(_deleteAsDuplicate(loser));
  }

  /// Merge: keep the pre-existing entry (`left`) and discard the new one
  /// (`right`), combining them into the union span + max severity. START comes
  /// from the entry with the earlier start, END from the entry with the later
  /// end (open-ended if that boundary has no end), intensity is the higher (more
  /// severe) of the two.
  ///
  /// Deferred (recording flow): writes nothing — pops the union as a pre-fill so
  /// the single Confirm Record save applies it. Immediate (home banner): writes
  /// the union onto `left` (verbatim boundary timestamps) and tombstones `right`
  /// now, then reactively auto-pops.
  void _merge(EpistaxisEntryView left, EpistaxisEntryView right) {
    final startBoundary = left.startTime.isBefore(right.startTime)
        ? left
        : right;
    final lEnd = left.endTime ?? left.startTime;
    final rEnd = right.endTime ?? right.startTime;
    final endBoundary = lEnd.isAfter(rEnd) ? left : right;
    final hasEnd = endBoundary.endTime != null;
    final candidates = <NosebleedIntensity>[
      if (left.intensity != null) left.intensity!,
      if (right.intensity != null) right.intensity!,
    ];
    final intensity = candidates.isEmpty
        ? null
        : candidates.reduce((a, b) => a.index >= b.index ? a : b);

    if (widget.deferApplication) {
      _resolveDeferred(
        action: OverlapResolution.merge,
        survivor: left,
        loserId: right.aggregateId,
        mergedPrefill: OverlapMergePrefill(
          startTime: startBoundary.startTime,
          startTimeZone: startBoundary.startTimeZone,
          endTime: hasEnd ? endBoundary.endTime : null,
          endTimeZone: endBoundary.endTimeZone,
          intensity: intensity,
        ),
      );
      return;
    }

    // Immediate (home banner): write the union onto `left`, copying the boundary
    // entries' STORED timestamp strings verbatim (no reformatting) so the
    // recorded wall-clock + timezone/offset are preserved, then tombstone
    // `right`. The edit lands before the delete so a failed delete just
    // re-surfaces the pair — no data loss. Reactive auto-pop handles the rest.
    final startPayload = EpistaxisEventPayload.fromJson(startBoundary.row.data);
    final endPayload = hasEnd
        ? EpistaxisEventPayload.fromJson(endBoundary.row.data)
        : null;
    final payload = <String, Object?>{
      'participantId': startPayload.participantId,
      'startTime': startPayload.startTime,
      'startTimeZone': startPayload.startTimeZone,
      'startTimeUtcOffset': startPayload.startTimeUtcOffset,
      if (endPayload != null) ...{
        'endTime': endPayload.endTime,
        'endTimeZone': endPayload.endTimeZone,
        'endTimeUtcOffset': endPayload.endTimeUtcOffset,
      },
      if (intensity != null) 'intensity': intensity.name,
    };
    unawaited(
      _submit('edit_epistaxis_event', <String, Object?>{
        'aggregateId': left.aggregateId,
        ...payload,
      }),
    );
    unawaited(_deleteAsDuplicate(right));
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
                    //    bootstrapping -> wait.
                    // Prefer the new entry (`right`) when it survives (Keep New,
                    // or an Edit that removed the overlap with both intact); the
                    // pre-existing one (`left`, merged on a Merge) otherwise.
                    if (_everSawBothEntries) _popResolved(right ?? left);
                    return const SizedBox.shrink();
                  }
                  // Monotonic latch: once true it never resets. Set here in
                  // build intentionally — it gates the auto-pop above and
                  // never needs to trigger a rebuild of its own (this build
                  // already renders the body). The compare body stays visible
                  // through the delete round-trip (the pair is still live until
                  // the tombstone propagates), so committing a choice does not
                  // blank the screen.
                  _everSawBothEntries = true;
                  return _CompareBody(
                    left: left,
                    right: right,
                    // Keep Existing: keep the pre-existing entry (`left`),
                    // discard the new one (`right`).
                    onPickLeft: () => _pick(
                      action: OverlapResolution.keepExisting,
                      survivor: left,
                      loser: right,
                    ),
                    // Keep New: keep the new entry (`right`), discard the
                    // pre-existing one (`left`).
                    onPickRight: () => _pick(
                      action: OverlapResolution.keepNew,
                      survivor: right,
                      loser: left,
                    ),
                    onMerge: () => _merge(left, right),
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
