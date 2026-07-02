import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/timezone_picker.dart';
import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Time picker widget with a dial-style interface
// Implements: DIARY-PRD-questionnaire-daily-epistaxis
// Implements: DIARY-GUI-epistaxis-record/E+J
class TimePickerDial extends StatefulWidget {
  const TimePickerDial({
    required this.title,
    required this.initialTime,
    required this.onConfirm,
    super.key,
    this.confirmLabel = 'Confirm',
    this.allowFutureTimes = false,
    this.maxDateTime,
    this.onTimeChanged,
    this.initialTimezone,
    this.onTimezoneChanged,
  });
  final String title;
  final DateTime initialTime;
  final ValueChanged<DateTime> onConfirm;
  final String confirmLabel;
  final bool allowFutureTimes;

  /// Optional maximum DateTime. When [allowFutureTimes] is false, this is used
  /// as the limit instead of DateTime.now(). Useful when editing past dates
  /// where the limit should be end-of-day rather than current moment.
  final DateTime? maxDateTime;

  /// Called when the time changes via adjustment buttons or time picker.
  /// This allows the parent to track live changes before confirm is pressed.
  final ValueChanged<DateTime>? onTimeChanged;

  /// Initial IANA timezone string (e.g., "America/New_York").
  /// If null, uses device's current timezone.
  final String? initialTimezone;

  /// Called when the timezone changes.
  final ValueChanged<String>? onTimezoneChanged;

  @override
  State<TimePickerDial> createState() => _TimePickerDialState();
}

class _TimePickerDialState extends State<TimePickerDial> {
  late DateTime _selectedTime;
  late String _selectedTimezone;

  @override
  void initState() {
    super.initState();
    // Initialize timezone FIRST, before clamping time.
    // _clampToMaxIfNeeded now uses timezone for validation.
    // Use initial timezone or detect from device, then normalize to IANA format.
    // Check TimezoneService.testTimezoneOverride first for consistent test behavior.
    final rawTimezone =
        widget.initialTimezone ??
        TimezoneService.instance.testTimezoneOverride ??
        DateTime.now().timeZoneName;
    _selectedTimezone = _normalizeTimezone(rawTimezone);

    // Clamp initial time to max if future times are not allowed
    _selectedTime = _clampToMaxIfNeeded(widget.initialTime);

    // CUR-516: Notify parent of initial timezone so it gets saved even if user doesn't change it
    // This ensures the timezone is persisted when saving incomplete records
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onTimezoneChanged?.call(_selectedTimezone);
    });
  }

  @override
  void didUpdateWidget(TimePickerDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When maxDateTime changes (e.g., user selected a different date),
    // we need to re-validate the selected time against the new max.
    // This ensures past dates allow full 24-hour selection.
    // Only re-clamp if maxDateTime changed significantly (>1 sec) to avoid
    // unnecessary re-clamping when parent rebuilds with DateTime.now().
    // CRITICAL: Don't re-clamp when timezone changes, since the time itself hasn't
    // changed - only the timezone interpretation. The user's selected time should
    // stay the same; it's just now interpreted in a different timezone.
    final timezoneChanging =
        widget.initialTimezone != oldWidget.initialTimezone;
    final maxDateTimeChangedSignificantly =
        widget.maxDateTime != null &&
        oldWidget.maxDateTime != null &&
        widget.maxDateTime!.difference(oldWidget.maxDateTime!).inSeconds.abs() >
            1;
    // Only treat maxDateTime changes as meaningful when it becomes
    // newly non-null (i.e., constraints get stricter). When maxDateTime is
    // removed (non-null -> null), do NOT re-clamp to avoid unexpected jumps
    // in existing selections (e.g., end time picker dropping stale maxDateTime).
    // Enforce the future-time constraint only when
    // a genuine limit is being applied, not when the constraint is lifted.
    final maxDateTimeBecameNonNull =
        widget.maxDateTime != null && oldWidget.maxDateTime == null;
    // Only re-clamp if time/max changed AND timezone is NOT changing
    // When timezone changes, the selected time stays the same - we just interpret
    // it differently. The confirm button will validate using the new timezone.
    final shouldReclamp =
        !timezoneChanging &&
        (maxDateTimeChangedSignificantly ||
            maxDateTimeBecameNonNull ||
            widget.initialTime != oldWidget.initialTime);
    if (shouldReclamp) {
      // Re-clamp the selected time with the new maxDateTime
      _selectedTime = _clampToMaxIfNeeded(widget.initialTime);
    }
    // Update timezone when parent provides a new one (e.g., after async detection)
    if (timezoneChanging && widget.initialTimezone != null) {
      _selectedTimezone = widget.initialTimezone!;
    }
  }

  /// Gets the effective maximum DateTime for validation.
  /// Uses maxDateTime if provided, otherwise DateTime.now().
  DateTime get _effectiveMaxDateTime => widget.maxDateTime ?? DateTime.now();

  /// Convert displayed time to comparable time (device timezone).
  /// When a timezone is selected, the displayed time represents a moment in
  /// that timezone. To validate against DateTime.now() (device time), we must
  /// first convert the displayed time to device timezone.
  ///
  /// Example: Display shows "3:24 PM EST", device is in PST.
  /// - Displayed time: 3:24 PM (the DateTime has hour=15, minute=24)
  /// - Selected timezone: EST (UTC-5)
  /// - Converted to device time: 12:24 PM PST
  /// - DateTime.now(): 12:54 PM PST
  /// - 12:24 PM < 12:54 PM = VALID (30 min in past)
  DateTime _convertToDeviceTime(DateTime displayedTime) {
    return TimezoneConverter.toStoredDateTime(displayedTime, _selectedTimezone);
  }

  /// Check if a displayed time would be in the future when
  /// properly converted to device timezone.
  bool _isDisplayedTimeInFuture(DateTime displayedTime) {
    if (widget.allowFutureTimes) return false;

    final deviceTime = _convertToDeviceTime(displayedTime);
    return deviceTime.isAfter(_effectiveMaxDateTime);
  }

  /// Clamps the given time to the effective max if future times are not allowed.
  /// Uses timezone-aware comparison to properly handle cross-timezone times.
  /// When displaying 4:34 PM EST (which equals 1:34 PM PST), we need to convert
  /// to device time before comparing against DateTime.now().
  DateTime _clampToMaxIfNeeded(DateTime time) {
    // Use timezone-aware check instead of raw DateTime comparison
    final normalizedTime = time.copyWith(
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );

    if (_isDisplayedTimeInFuture(normalizedTime)) {
      // Return a clamped time that represents "now" in the display timezone
      // Convert _effectiveMaxDateTime (device time) to display timezone
      return TimezoneConverter.toDisplayedDateTime(
        _effectiveMaxDateTime,
        _selectedTimezone,
      ).copyWith(second: 0, millisecond: 0, microsecond: 0);
    }
    return normalizedTime;
  }

  // Track which button should show error flash
  int? _errorButtonDelta;

  // Reject any minute adjustment that would push
  // the selected time into the future, using timezone-aware comparison.
  void _adjustMinutes(int delta) {
    final newTime = _selectedTime
        .copyWith(second: 0, millisecond: 0, microsecond: 0)
        .add(Duration(minutes: delta));

    // Check if this would exceed the max time, considering timezone

    if (_isDisplayedTimeInFuture(newTime)) {
      // Show error flash on the button
      setState(() => _errorButtonDelta = delta);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _errorButtonDelta = null);
      });
      return;
    }

    setState(() {
      _selectedTime = newTime;
    });
    // Notify parent of the time change
    widget.onTimeChanged?.call(newTime);
  }

  /// Figma 515:3482 ("Time Picker" dialog): the Material pickers run on the
  /// full design-system [ColorScheme] (buildAppLightColorScheme) instead of
  /// the app's legacy teal seed, so every slot M3 reads (selection chrome,
  /// dial, day-period toggle, Cancel/OK) resolves to the Figma palette.
  ///
  /// The dialog background is forced to `scheme.surface` (white): M3 paints
  /// picker dialogs with `surfaceContainerHigh` by default, which is a grey
  /// in the design-system surface scale.
  Widget _pickerTheme(BuildContext context, Widget? child) {
    final theme = Theme.of(context);
    final scheme = buildAppLightColorScheme();
    // M3 rounds picker dialogs at 28; the design system caps surfaces at the
    // `lg` radius token (12).
    final dialogShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return Theme(
      data: theme.copyWith(
        colorScheme: scheme,
        datePickerTheme: DatePickerThemeData(
          backgroundColor: scheme.surface,
          shape: dialogShape,
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: scheme.surface,
          shape: dialogShape,
          // Light Gray dial face with the primary hand/knob (Figma 515:3502).
          dialBackgroundColor: scheme.surfaceContainer,
          dialHandColor: scheme.primary,
          // Selected hour/minute field: primary-tinted container; unselected:
          // Light Gray (Figma 515:3486/3491).
          hourMinuteColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primaryContainer
                : scheme.surfaceContainer,
          ),
          hourMinuteTextColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
          // AM/PM toggle: filled primary when selected (Figma 515:3496).
          dayPeriodColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surface,
          ),
          dayPeriodTextColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      child: child!,
    );
  }

  Future<void> _showTimePicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTime),
      builder: _pickerTheme,
    );

    if (picked != null) {
      final newTime = DateTime(
        _selectedTime.year,
        _selectedTime.month,
        _selectedTime.day,
        picked.hour,
        picked.minute,
      );
      // Don't allow times past the max unless explicitly permitted.
      // Use timezone-aware validation.
      if (_isDisplayedTimeInFuture(newTime)) {
        // Show feedback that the time was rejected
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.cannotSelectFutureTime),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      setState(() {
        _selectedTime = newTime;
      });
      // Notify parent of the time change - user still needs to tap confirm button
      widget.onTimeChanged?.call(newTime);
    }
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: _pickerTheme,
    );

    if (picked != null) {
      // Preserve the time, just change the date
      final newDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      // Clamp if needed (e.g., if picked today but time is in the future)
      final clampedDateTime = _clampToMaxIfNeeded(newDateTime);
      setState(() {
        _selectedTime = clampedDateTime;
      });
      // Notify parent of the date change
      widget.onTimeChanged?.call(clampedDateTime);
    }
  }

  Future<void> _showTimezonePicker() async {
    final selected = await showTimezonePicker(
      context: context,
      selectedTimezone: _normalizeTimezone(_selectedTimezone),
    );
    if (selected != null) {
      setState(() {
        _selectedTimezone = selected;
      });
      widget.onTimezoneChanged?.call(selected);
    }
  }

  /// Normalize various timezone formats to IANA format for the dropdown.
  /// Handles:
  /// - POSIX format like "EST5EDT" -> "America/New_York"
  /// - Abbreviations like "PST" -> "America/Los_Angeles"
  /// - Full display names like "Central European Standard Time" -> "Europe/Paris"
  String _normalizeTimezone(String tzInput) {
    // If already an IANA format (contains /), return as-is
    if (tzInput.contains('/')) {
      return tzInput;
    }

    // Map common POSIX timezones and abbreviations to IANA equivalents
    const posixToIana = {
      // POSIX formats
      'EST5EDT': 'America/New_York',
      'CST6CDT': 'America/Chicago',
      'MST7MDT': 'America/Denver',
      'PST8PDT': 'America/Los_Angeles',
      // Abbreviations
      'EST': 'America/New_York',
      'EDT': 'America/New_York',
      'CST': 'America/Chicago',
      'CDT': 'America/Chicago',
      'MST': 'America/Denver',
      'MDT': 'America/Denver',
      'PST': 'America/Los_Angeles',
      'PDT': 'America/Los_Angeles',
      'AKST': 'America/Anchorage',
      'AKDT': 'America/Anchorage',
      'HST': 'Pacific/Honolulu',
      'CET': 'Europe/Paris',
      'CEST': 'Europe/Paris',
      'EET': 'Europe/Helsinki',
      'EEST': 'Europe/Helsinki',
      'WET': 'Europe/Lisbon',
      'WEST': 'Europe/Lisbon',
      'GMT': 'Europe/London',
      'BST': 'Europe/London',
      'UTC': 'Etc/UTC',
      'IST': 'Asia/Kolkata',
      'JST': 'Asia/Tokyo',
      'KST': 'Asia/Seoul',
      'CST (China)': 'Asia/Shanghai',
      'AEST': 'Australia/Sydney',
      'AEDT': 'Australia/Sydney',
      'AWST': 'Australia/Perth',
      'ACST': 'Australia/Adelaide',
      'ACDT': 'Australia/Adelaide',
      'NZST': 'Pacific/Auckland',
      'NZDT': 'Pacific/Auckland',
    };

    // Map full display names to IANA equivalents
    const displayNameToIana = {
      'Eastern Standard Time': 'America/New_York',
      'Eastern Daylight Time': 'America/New_York',
      'Central Standard Time': 'America/Chicago',
      'Central Daylight Time': 'America/Chicago',
      'Mountain Standard Time': 'America/Denver',
      'Mountain Daylight Time': 'America/Denver',
      'Pacific Standard Time': 'America/Los_Angeles',
      'Pacific Daylight Time': 'America/Los_Angeles',
      'Alaska Standard Time': 'America/Anchorage',
      'Alaska Daylight Time': 'America/Anchorage',
      'Hawaii-Aleutian Standard Time': 'Pacific/Honolulu',
      'Hawaii Standard Time': 'Pacific/Honolulu',
      'Central European Standard Time': 'Europe/Paris',
      'Central European Summer Time': 'Europe/Paris',
      'Eastern European Standard Time': 'Europe/Helsinki',
      'Eastern European Summer Time': 'Europe/Helsinki',
      'Western European Standard Time': 'Europe/Lisbon',
      'Western European Summer Time': 'Europe/Lisbon',
      'Greenwich Mean Time': 'Europe/London',
      'British Summer Time': 'Europe/London',
      'Coordinated Universal Time': 'Etc/UTC',
      'India Standard Time': 'Asia/Kolkata',
      'Japan Standard Time': 'Asia/Tokyo',
      'Korea Standard Time': 'Asia/Seoul',
      'China Standard Time': 'Asia/Shanghai',
      'Australian Eastern Standard Time': 'Australia/Sydney',
      'Australian Eastern Daylight Time': 'Australia/Sydney',
      'Australian Western Standard Time': 'Australia/Perth',
      'Australian Central Standard Time': 'Australia/Adelaide',
      'Australian Central Daylight Time': 'Australia/Adelaide',
      'New Zealand Standard Time': 'Pacific/Auckland',
      'New Zealand Daylight Time': 'Pacific/Auckland',
    };

    // Try abbreviation first
    if (posixToIana.containsKey(tzInput)) {
      return posixToIana[tzInput]!;
    }

    // Try full display name
    if (displayNameToIana.containsKey(tzInput)) {
      return displayNameToIana[tzInput]!;
    }

    // Handle numeric UTC offset formats like "+00", "-05", "+0530", "+05:30"
    // Some platforms return these from DateTime.now().timeZoneName
    final offsetMatch = RegExp(
      r'^([+-])(\d{2}):?(\d{2})?$',
    ).firstMatch(tzInput);
    if (offsetMatch != null) {
      final sign = offsetMatch.group(1) == '+' ? 1 : -1;
      final hours = int.parse(offsetMatch.group(2)!);
      final minutes = int.parse(offsetMatch.group(3) ?? '0');
      final totalMinutes = sign * (hours * 60 + minutes);
      final match = commonTimezones
          .where((tz) => tz.utcOffsetMinutes == totalMinutes)
          .firstOrNull;
      if (match != null) {
        return match.ianaId;
      }
    }

    // Default to UTC if unknown
    debugPrint('Unknown timezone format: $tzInput, defaulting to Etc/UTC');
    return 'Etc/UTC';
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final timeFormat = DateFormat('H:mm', locale);
    final periodFormat = DateFormat('a', locale);
    // Check if locale uses 24-hour format
    final use24Hour = !DateFormat.jm(locale).pattern!.contains('a');

    // CUR-488 Phase 2: Reduced horizontal padding from 24 to 23 for small screens
    // Reduced vertical padding from 24 to 16 to accommodate timezone selector
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 23.0, vertical: 16.0),
      child: Column(
        children: [
          // Figma 682:2947: the heading + date chip + time + nudges + confirm
          // button render as one vertically-centered group.
          const Spacer(),

          // CUR-488 Phase 2: Don't scale title to avoid scrolling on small screens
          MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              // Figma "Heading 3" — Inter SemiBold 24 on Black.
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                height: 34 / 24,
                letterSpacing: 0.18,
                color: Color(0xFF04161E),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Date chip above time (tappable, Figma 682:2953)
          GestureDetector(
            onTap: _showDatePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECEEF0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 17,
                    color: Color(0xFF54636A),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEEE, MMM d', locale).format(_selectedTime),
                    style: const TextStyle(
                      fontSize: 17,
                      height: 25.5 / 17,
                      letterSpacing: -0.43,
                      color: Color(0xFF54636A),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Time display (tappable, Figma 682:2966 — Inter Light 64)
          GestureDetector(
            onTap: _showTimePicker,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                use24Hour
                    ? timeFormat.format(_selectedTime)
                    : '${DateFormat('h:mm', locale).format(_selectedTime)} '
                          '${periodFormat.format(_selectedTime)}',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w300,
                  height: 1,
                  letterSpacing: 0.22,
                  color: Color(0xFF04161E),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Timezone selector (subtle, below time — Figma 682:2967)
          GestureDetector(
            onTap: _showTimezonePicker,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.public, size: 17, color: Color(0xFFA4B9C2)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _timezoneLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 21.25 / 15,
                      letterSpacing: -0.22,
                      color: Color(0xFF54636A),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Quick adjust buttons (Figma 682:2973)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AdjustButton(
                label: '-15',
                onPressed: () => _adjustMinutes(-15),
                showError: _errorButtonDelta == -15,
              ),
              const SizedBox(width: 8),
              _AdjustButton(
                label: '-5',
                onPressed: () => _adjustMinutes(-5),
                showError: _errorButtonDelta == -5,
              ),
              const SizedBox(width: 8),
              _AdjustButton(
                label: '-1',
                onPressed: () => _adjustMinutes(-1),
                showError: _errorButtonDelta == -1,
              ),
              const SizedBox(width: 8),
              _AdjustButton(
                label: '+1',
                onPressed: () => _adjustMinutes(1),
                showError: _errorButtonDelta == 1,
              ),
              const SizedBox(width: 8),
              _AdjustButton(
                label: '+5',
                onPressed: () => _adjustMinutes(5),
                showError: _errorButtonDelta == 5,
              ),
              const SizedBox(width: 8),
              _AdjustButton(
                label: '+15',
                onPressed: () => _adjustMinutes(15),
                showError: _errorButtonDelta == 15,
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Confirm button (Figma 682:2987 — design-system AppButton)
          AppButton(
            size: AppButtonSize.large,
            fullWidth: true,
            label: widget.confirmLabel,
            onPressed: () {
              // Show error for future times instead of silently clamping
              // This can happen when timezone conversion shifts the time forward
              // (e.g., picking Hawaii time from CET device shifts stored time +11 hours)
              if (_isDisplayedTimeInFuture(_selectedTime)) {
                final l10n = AppLocalizations.of(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.cannotSelectFutureTime),
                    duration: const Duration(seconds: 2),
                  ),
                );
                return;
              }
              widget.onConfirm(_selectedTime);
            },
          ),

          const Spacer(),
        ],
      ),
    );
  }

  /// Figma 682:2970 renders the timezone as "PDT - America/Los Angeles":
  /// abbreviation + the IANA id with underscores opened up.
  String _timezoneLabel() {
    final iana = _normalizeTimezone(_selectedTimezone);
    final abbr = getTimezoneAbbreviation(iana, at: _selectedTime);
    return '$abbr - ${iana.replaceAll('_', ' ')}';
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({
    required this.label,
    required this.onPressed,
    this.showError = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    // Figma 682:2974: Light Gray pill, radius ~10, primary-colored Medium 17
    // label. The primary hex comes from the design-system button extension so
    // sponsor brand overrides keep flowing through.
    final primary =
        Theme.of(context).extension<AppButtonColors>()?.primary.background ??
        Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: showError
            ? Theme.of(context).colorScheme.errorContainer
            : const Color(0xFFECEEF0),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                height: 25.5 / 17,
                letterSpacing: -0.43,
                color: showError
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
