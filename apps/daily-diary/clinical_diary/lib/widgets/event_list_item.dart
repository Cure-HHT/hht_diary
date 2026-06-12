// Implements: DIARY-DEV-reactive-read-path/B

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/timezone_picker.dart';
import 'package:diary_design_system/diary_design_system.dart' as ds;
import 'package:diary_shared_model/diary_shared_model.dart'
    show NosebleedIntensity;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Domain wrapper around the design system's [ds.EventListItem]. Maps a
/// [DiaryEntryView] (sealed: epistaxis / day-marker / survey) onto a single
/// row across all four states — empty, no-record marker, incomplete, and
/// complete — so every row in "Your Records" goes through one DS primitive.
class EventListItem extends StatelessWidget {
  const EventListItem({
    required DiaryEntryView this.view,
    super.key,
    this.onTap,
    this.hasOverlap = false,
    this.highlightColor,
  }) : emptyMessage = null;

  /// Empty-state row — a muted line of explanatory text in place of the
  /// timestamp/duration layout. Delegates to [ds.EventListItem.empty].
  const EventListItem.empty(String message, {super.key})
    : view = null,
      onTap = null,
      hasOverlap = false,
      highlightColor = null,
      emptyMessage = message;

  /// The typed diary-entry view to render. Null when [EventListItem.empty]
  /// builds the no-records placeholder.
  final DiaryEntryView? view;
  final VoidCallback? onTap;
  final bool hasOverlap;

  /// Optional tint applied behind the row for the flash-on-save animation.
  final Color? highlightColor;

  /// Empty-state message — set only via [EventListItem.empty].
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (emptyMessage != null) {
      return ds.EventListItem.empty(emptyMessage!);
    }
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final v = view!;

    Widget row;
    if (v is EpistaxisEntryView) {
      row = _buildEpistaxisRow(context, l10n, locale, v);
    } else if (v is SurveyEntryView) {
      // Preserves the `Key('survey-card')` finder used by home_screen_test.
      row = KeyedSubtree(
        key: const Key('survey-card'),
        child: _buildSurveyRow(context, locale, v),
      );
    } else {
      row = _buildMarkerRow(context, l10n);
    }

    if (highlightColor == null) return row;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlightColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: row,
    );
  }

  // ---- Epistaxis row --------------------------------------------------------

  /// CUR-443: One-line nosebleed row routed through [ds.EventListItem]. The
  /// DS row supports an `iconAssetPath`, so the per-intensity PNG sits
  /// between time and duration — same layout the previous list used.
  ///
  /// Figma cue: a vertical accent bar on the left edge — `colorScheme.error`
  /// (red) for finalised rows, `semantic.warning` (amber) for in-progress
  /// rows — so the row's status reads at a glance. No chevron: the entire
  /// row is the tap affordance.
  Widget _buildEpistaxisRow(
    BuildContext context,
    AppLocalizations l10n,
    String locale,
    EpistaxisEntryView entry,
  ) {
    final theme = Theme.of(context);
    final semantic = theme.extension<ds.AppSemanticColors>();
    final isIncomplete = !entry.isComplete;
    final (durationText, _) = _durationInfo(entry);
    final time = _startTimeFormatted(locale, entry);
    final secondary = isIncomplete ? l10n.ongoing : durationText;
    final intensityAsset = _intensityImagePath(entry.intensity);
    final accent = isIncomplete
        ? (semantic?.warning ?? theme.colorScheme.error)
        : theme.colorScheme.error;

    return ds.EventListItem(
      leading: time,
      iconAssetPath: intensityAsset,
      icon: intensityAsset == null ? Icons.water_drop_outlined : null,
      secondary: secondary.isEmpty ? null : secondary,
      tone: isIncomplete
          ? ds.EventListItemTone.warning
          : ds.EventListItemTone.neutral,
      accentColor: accent,
      onTap: onTap,
      trailing: _epistaxisTrailing(context, l10n, entry, isIncomplete),
    );
  }

  /// Path to the intensity PNG asset for [intensity]. Mirrors the asset map
  /// the previous list used. Returns null when intensity is unrecorded.
  String? _intensityImagePath(NosebleedIntensity? intensity) {
    if (intensity == null) return null;
    switch (intensity) {
      case NosebleedIntensity.spotting:
        return 'assets/images/intensity_spotting.png';
      case NosebleedIntensity.dripping:
        return 'assets/images/intensity_dripping.png';
      case NosebleedIntensity.drippingQuickly:
        return 'assets/images/intensity_dripping_quickly.png';
      case NosebleedIntensity.steadyStream:
        return 'assets/images/intensity_steady_stream.png';
      case NosebleedIntensity.pouring:
        return 'assets/images/intensity_pouring.png';
      case NosebleedIntensity.gushing:
        return 'assets/images/intensity_gushing.png';
    }
  }

  Widget? _epistaxisTrailing(
    BuildContext context,
    AppLocalizations l10n,
    EpistaxisEntryView entry,
    bool isIncomplete,
  ) {
    final theme = Theme.of(context);
    final semantic = theme.extension<ds.AppSemanticColors>();
    final children = <Widget>[];
    final tzText = _timezoneDisplay(entry);
    if (tzText != null) {
      children.add(
        Text(
          tzText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    if (entry.isMultiDay) {
      children.add(
        Text(
          l10n.translate('plusOneDay'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    if (hasOverlap) {
      children.add(
        Icon(
          Icons.warning_amber_rounded,
          size: 18,
          color: semantic?.warning ?? theme.colorScheme.error,
        ),
      );
    }
    if (isIncomplete) {
      children.add(
        _IncompletePill(
          label: l10n.incomplete,
          accent: semantic?.warning ?? theme.colorScheme.error,
        ),
      );
    }
    // No chevron — the whole row is the tap affordance (Figma cue).
    if (children.isEmpty) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          children[i],
        ],
      ],
    );
  }

  // ---- Survey row -----------------------------------------------------------

  /// Implements: DIARY-PRD-questionnaire-system/B — a finalized questionnaire
  /// surfaces alongside the day's clinical entries.
  Widget _buildSurveyRow(
    BuildContext context,
    String locale,
    SurveyEntryView survey,
  ) {
    final theme = Theme.of(context);
    final name = _questionnaireDisplayName(survey.questionnaireType);
    final timeText = DateFormat.jm(locale).format(survey.completedAt);
    return ds.EventListItem(
      leading: name,
      icon: Icons.assignment_turned_in_outlined,
      secondary: 'Completed · $timeText',
      tone: ds.EventListItemTone.neutral,
      onTap: onTap,
      trailing: onTap == null
          ? null
          : Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
    );
  }

  // ---- Marker row (no_epistaxis_event / unknown_day_event) ------------------

  Widget _buildMarkerRow(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final v = view!;
    final isNoNosebleeds = v.entryType == 'no_epistaxis_event';
    final leading = isNoNosebleeds ? l10n.noNosebleeds : l10n.unknown;
    final secondary = l10n.translate(
      isNoNosebleeds ? 'confirmedNoEvents' : 'unableToRecallEvents',
    );
    return ds.EventListItem(
      leading: leading,
      icon: isNoNosebleeds ? Icons.check_circle_outline : Icons.help_outline,
      secondary: secondary,
      tone: ds.EventListItemTone.neutral,
      onTap: onTap,
      trailing: onTap == null
          ? null
          : Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
    );
  }

  // ---- Field helpers --------------------------------------------------------

  /// CUR-597: Times are displayed in the event's stored timezone, not device
  /// timezone — so a record made in NY still reads "10:00 AM EST" on a UTC
  /// device.
  String _startTimeFormatted(String locale, EpistaxisEntryView entry) {
    final displayTime = TimezoneConverter.toDisplayedDateTime(
      entry.startTime,
      entry.startTimeZone,
    );
    return DateFormat.jm(locale).format(displayTime);
  }

  /// CUR-516: Returns the timezone abbreviation to render alongside the row
  /// when it differs from the device timezone (or differs between start/end).
  /// Null when start matches device and start == end.
  String? _timezoneDisplay(EpistaxisEntryView entry) {
    final deviceTimezone =
        TimezoneService.instance.currentTimezone ?? DateTime.now().timeZoneName;
    final deviceTzAbbr = normalizeDeviceTimezone(deviceTimezone);
    final startTz = entry.startTimeZone;
    final endTz = entry.endTimeZone;
    final startAbbr = getTimezoneAbbreviation(
      startTz,
      at: TimezoneConverter.toDisplayedDateTime(entry.startTime, startTz),
    );
    final endAt = entry.endTime ?? entry.startTime;
    final endAbbr = endTz != null
        ? getTimezoneAbbreviation(
            endTz,
            at: TimezoneConverter.toDisplayedDateTime(endAt, endTz),
          )
        : null;
    final startDiffersFromDevice = startAbbr != deviceTzAbbr;
    final endDiffersFromDevice = endAbbr != null && endAbbr != deviceTzAbbr;
    final timezonesDiffer = endAbbr != null && startAbbr != endAbbr;
    if (!startDiffersFromDevice && !endDiffersFromDevice && !timezonesDiffer) {
      return null;
    }
    if (timezonesDiffer) return '$startAbbr/$endAbbr';
    if (startDiffersFromDevice) return startAbbr;
    if (endDiffersFromDevice) return endAbbr;
    return startAbbr;
  }

  /// Friendly display name for a questionnaire type id.
  String _questionnaireDisplayName(String type) {
    for (final t in QuestionnaireType.values) {
      if (t.value == type) return t.displayName;
    }
    return type;
  }

  /// CUR-488: Format duration as "1m", "45m", "2h", "1h 15m"; null durations
  /// return an empty string (the row's `secondary` is then hidden).
  (String, bool) _durationInfo(EpistaxisEntryView entry) {
    if (entry.endTime == null) return ('', true);
    final minutes = entry.durationMinutes;
    if (minutes == null) return ('', false);
    if (minutes == 0) return ('1m', false);
    if (minutes < 60) return ('${minutes}m', false);
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (remaining == 0) return ('${hours}h', false);
    return ('${hours}h ${remaining}m', false);
  }
}

/// Small "Incomplete" pill rendered in [EventListItem]'s trailing slot when
/// an epistaxis row has no end time yet.
class _IncompletePill extends StatelessWidget {
  const _IncompletePill({required this.label, required this.accent});
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<ds.AppSemanticColors>();
    final bg = semantic?.warningContainer ?? theme.colorScheme.errorContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
