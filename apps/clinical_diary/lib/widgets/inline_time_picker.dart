// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Inline time picker widget with time display and adjustment buttons
/// Designed to be used within a form layout without requiring a separate screen
/// Supports null/unset state displaying "--:--"
class InlineTimePicker extends StatefulWidget {
  const InlineTimePicker({
    required this.onTimeChanged,
    super.key,
    this.initialTime,
    this.allowFutureTimes = false,
    this.minTime,
    this.maxDateTime,
  });

  /// Initial time, or null to show unset state (--:--)
  final DateTime? initialTime;
  final ValueChanged<DateTime> onTimeChanged;
  final bool allowFutureTimes;
  final DateTime? minTime;

  /// Optional maximum DateTime. When [allowFutureTimes] is false, this is used
  /// as the limit instead of DateTime.now(). Useful when editing past dates
  /// where the limit should be end-of-day rather than current moment.
  final DateTime? maxDateTime;

  @override
  State<InlineTimePicker> createState() => _InlineTimePickerState();
}

class _InlineTimePickerState extends State<InlineTimePicker> {
  DateTime? _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = _clampToMaxIfNeeded(widget.initialTime);
  }

  /// Gets the effective maximum DateTime for validation.
  /// Uses maxDateTime if provided, otherwise DateTime.now().
  DateTime get _effectiveMaxDateTime => widget.maxDateTime ?? DateTime.now();

  /// Clamps the given time to the effective max if future times are not allowed
  DateTime? _clampToMaxIfNeeded(DateTime? time) {
    if (time == null) return null;
    if (!widget.allowFutureTimes && time.isAfter(_effectiveMaxDateTime)) {
      return _effectiveMaxDateTime;
    }
    return time;
  }

  @override
  void didUpdateWidget(InlineTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // CUR-447: When maxDateTime changes (e.g., user selected a different date),
    // we need to re-validate the selected time against the new max.
    if (widget.maxDateTime != oldWidget.maxDateTime) {
      _selectedTime = _clampToMaxIfNeeded(_selectedTime ?? widget.initialTime);
    }
    // Update if initial time changed significantly (not just minor adjustments)
    final oldTime = oldWidget.initialTime;
    final newTime = widget.initialTime;
    if (oldTime == null && newTime != null) {
      _selectedTime = _clampToMaxIfNeeded(newTime);
    } else if (oldTime != null &&
        newTime != null &&
        newTime.difference(oldTime).inMinutes.abs() > 1) {
      _selectedTime = _clampToMaxIfNeeded(newTime);
    }
  }

  // Track which button should show error flash
  int? _errorButtonDelta;

  void _adjustMinutes(int delta) {
    // If no time is set, use minTime's date (for correct date context) or effective max
    // This ensures end time uses the same date as start time (CUR-451)
    final baseTime = _selectedTime ?? widget.minTime ?? _effectiveMaxDateTime;
    final newTime = baseTime.add(Duration(minutes: delta));

    // Check if this would exceed the max time
    if (!widget.allowFutureTimes && newTime.isAfter(_effectiveMaxDateTime)) {
      setState(() => _errorButtonDelta = delta);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _errorButtonDelta = null);
      });
      return;
    }

    // Check if this would go before min time
    if (widget.minTime != null && newTime.isBefore(widget.minTime!)) {
      setState(() => _errorButtonDelta = delta);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _errorButtonDelta = null);
      });
      return;
    }

    setState(() {
      _selectedTime = newTime;
    });
    widget.onTimeChanged(newTime);
  }

  Future<void> _showTimePicker() async {
    // Use minTime's date (for correct date context) or effective max if no time is set
    // This ensures end time uses the same date as start time (CUR-451)
    final baseTime = _selectedTime ?? widget.minTime ?? _effectiveMaxDateTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(baseTime),
    );

    if (picked != null) {
      final newTime = DateTime(
        baseTime.year,
        baseTime.month,
        baseTime.day,
        picked.hour,
        picked.minute,
      );

      // Don't allow times past the max unless explicitly permitted
      if (!widget.allowFutureTimes && newTime.isAfter(_effectiveMaxDateTime)) {
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

      // Don't allow times before min time
      if (widget.minTime != null && newTime.isBefore(widget.minTime!)) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.endTimeAfterStart),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedTime = newTime;
      });
      widget.onTimeChanged(newTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final timeFormat = DateFormat('H:mm', locale);
    final periodFormat = DateFormat('a', locale);
    // Check if locale uses 24-hour format
    final use24Hour = !DateFormat.jm(locale).pattern!.contains('a');
    final isUnset = _selectedTime == null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Time display (tappable to show native picker)
          GestureDetector(
            onTap: _showTimePicker,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  isUnset
                      ? '--:--'
                      : (use24Hour
                            ? timeFormat.format(_selectedTime!)
                            : DateFormat(
                                'h:mm',
                                locale,
                              ).format(_selectedTime!)),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w300,
                    color: isUnset
                        ? Theme.of(context).colorScheme.outline
                        : null,
                  ),
                ),
                if (!use24Hour) ...[
                  const SizedBox(width: 8),
                  Text(
                    isUnset ? '--' : periodFormat.format(_selectedTime!),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: isUnset
                          ? Theme.of(context).colorScheme.outline
                          : null,
                    ),
                  ),
                ],
              ],
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
            : Theme.of(context).colorScheme.surface,
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
