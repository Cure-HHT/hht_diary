import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone_button_dropdown/timezone_button_dropdown.dart';

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
    // Clamp initial time to max if future times are not allowed
    _selectedTime = _clampToMaxIfNeeded(widget.initialTime);
    // Use initial timezone or detect from device
    _selectedTimezone = widget.initialTimezone ?? DateTime.now().timeZoneName;
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

  /// Clamps the given time to the effective max if future times are not allowed
  DateTime _clampToMaxIfNeeded(DateTime time) {
    if (!widget.allowFutureTimes && time.isAfter(_effectiveMaxDateTime)) {
      return _effectiveMaxDateTime;
    }
    return time;
  }

  // Track which button should show error flash
  int? _errorButtonDelta;

  void _adjustMinutes(int delta) {
    final newTime = _selectedTime.add(Duration(minutes: delta));

    // Check if this would exceed the max time
    if (!widget.allowFutureTimes && newTime.isAfter(_effectiveMaxDateTime)) {
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
      // Don't allow times past the max unless explicitly permitted
      if (!widget.allowFutureTimes && newTime.isAfter(_effectiveMaxDateTime)) {
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

  void _showTimezonePicker() {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Select Timezone',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: TimezoneDropdown(
                selectHint: 'Search timezones...',
                searchHint: 'Search...',
                selectedTimezone: _normalizeTimezone(_selectedTimezone),
                onTimezoneSelected: (timezone) {
                  setState(() {
                    _selectedTimezone = timezone;
                  });
                  widget.onTimezoneChanged?.call(timezone);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Normalize POSIX-style timezones to IANA format for the dropdown.
  /// Some platforms (iOS simulator) return POSIX format like "EST5EDT" instead
  /// of IANA format like "America/New_York".
  String _normalizeTimezone(String tz) {
    // Map common POSIX timezones to IANA equivalents
    const posixToIana = {
      'EST5EDT': 'America/New_York',
      'CST6CDT': 'America/Chicago',
      'MST7MDT': 'America/Denver',
      'PST8PDT': 'America/Los_Angeles',
      'EST': 'America/New_York',
      'CST': 'America/Chicago',
      'MST': 'America/Denver',
      'PST': 'America/Los_Angeles',
      'CET': 'Europe/Paris',
      'EET': 'Europe/Helsinki',
      'WET': 'Europe/Lisbon',
      'GMT': 'Etc/GMT',
    };
    return posixToIana[tz] ?? tz;
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
                    _normalizeTimezone(_selectedTimezone),
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
