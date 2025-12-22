import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/services/timezone_service.dart';
import 'package:clinical_diary/utils/timezone_converter.dart';
import 'package:clinical_diary/widgets/timezone_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Time picker widget with a dial-style interface
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
    // CUR-564: Initialize timezone FIRST, before clamping time.
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
    // CUR-447: This ensures past dates allow full 24-hour selection.
    if (widget.maxDateTime != oldWidget.maxDateTime ||
        widget.initialTime != oldWidget.initialTime) {
      // Re-clamp the selected time with the new maxDateTime
      _selectedTime = _clampToMaxIfNeeded(widget.initialTime);
    }
    // Update timezone when parent provides a new one (e.g., after async detection)
    if (widget.initialTimezone != oldWidget.initialTimezone &&
        widget.initialTimezone != null) {
      _selectedTimezone = widget.initialTimezone!;
    }
  }

  /// Gets the effective maximum DateTime for validation.
  /// Uses maxDateTime if provided, otherwise DateTime.now().
  DateTime get _effectiveMaxDateTime => widget.maxDateTime ?? DateTime.now();

  /// CUR-564: Convert displayed time to comparable time (device timezone).
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

  /// CUR-564: Check if a displayed time would be in the future when
  /// properly converted to device timezone.
  bool _isDisplayedTimeInFuture(DateTime displayedTime) {
    if (widget.allowFutureTimes) return false;

    final deviceTime = _convertToDeviceTime(displayedTime);
    return deviceTime.isAfter(_effectiveMaxDateTime);
  }

  /// Clamps the given time to the effective max if future times are not allowed.
  /// CUR-564: Uses timezone-aware comparison to properly handle cross-timezone times.
  /// When displaying 4:34 PM EST (which equals 1:34 PM PST), we need to convert
  /// to device time before comparing against DateTime.now().
  DateTime _clampToMaxIfNeeded(DateTime time) {
    // CUR-564: Use timezone-aware check instead of raw DateTime comparison
    if (_isDisplayedTimeInFuture(time)) {
      // Return a clamped time that represents "now" in the display timezone
      // Convert _effectiveMaxDateTime (device time) to display timezone
      return TimezoneConverter.toDisplayedDateTime(
        _effectiveMaxDateTime,
        _selectedTimezone,
      );
    }
    return time;
  }

  // Track which button should show error flash
  int? _errorButtonDelta;

  void _adjustMinutes(int delta) {
    final newTime = _selectedTime.add(Duration(minutes: delta));

    // CUR-564: Check if this would exceed the max time, considering timezone
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

  Future<void> _showTimePicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTime),
    );

    if (picked != null) {
      final newTime = DateTime(
        _selectedTime.year,
        _selectedTime.month,
        _selectedTime.day,
        picked.hour,
        picked.minute,
      );
      // CUR-564: Don't allow times past the max unless explicitly permitted.
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

    // Default to UTC if unknown
    debugPrint(
      'Unknown timezone format: $tzInput, defaulting to America/New_York',
    );
    return 'America/New_York';
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
          // CUR-488 Phase 2: Don't scale title to avoid scrolling on small screens
          MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: Text(
              widget.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),

          const Spacer(),

          // Date display above time (tappable, DateHeader-like styling)
          GestureDetector(
            onTap: _showDatePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d', locale).format(_selectedTime),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Time display (tappable)
          GestureDetector(
            onTap: _showTimePicker,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  use24Hour
                      ? timeFormat.format(_selectedTime)
                      : DateFormat('h:mm', locale).format(_selectedTime),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w300,
                    fontSize: 72,
                  ),
                ),
                if (!use24Hour) ...[
                  const SizedBox(width: 8),
                  Text(
                    periodFormat.format(_selectedTime),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Timezone selector (subtle, below time)
          GestureDetector(
            onTap: _showTimezonePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.public,
                    size: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    getTimezoneDisplayName(
                      _normalizeTimezone(_selectedTimezone),
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick adjust buttons
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
              const SizedBox(width: 16),
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

          const Spacer(),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                // Final validation: clamp to max if future times not allowed
                final timeToConfirm = _clampToMaxIfNeeded(_selectedTime);
                widget.onConfirm(timeToConfirm);
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                widget.confirmLabel,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: showError
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: showError
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
