import 'package:clinical_diary/l10n/app_localizations.dart';
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

  @override
  State<TimePickerDial> createState() => _TimePickerDialState();
}

class _TimePickerDialState extends State<TimePickerDial> {
  late DateTime _selectedTime;

  @override
  void initState() {
    super.initState();
    // Clamp initial time to max if future times are not allowed
    _selectedTime = _clampToMaxIfNeeded(widget.initialTime);
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
      // Auto-confirm when user selects from native time picker
      widget.onConfirm(newTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final timeFormat = DateFormat('H:mm', locale);
    final periodFormat = DateFormat('a', locale);
    // Check if locale uses 24-hour format
    final use24Hour = !DateFormat.jm(locale).pattern!.contains('a');

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text(
            widget.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),

          const Spacer(),

          // Time display with date below (CUR-447: show date for clarity)
          GestureDetector(
            onTap: _showTimePicker,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
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
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // CUR-447: Show date below time for clarity in cross-day scenarios
                Text(
                  DateFormat.yMMMd(locale).format(_selectedTime),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

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
