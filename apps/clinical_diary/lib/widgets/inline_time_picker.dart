// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

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
  });

  /// Initial time, or null to show unset state (--:--)
  final DateTime? initialTime;
  final ValueChanged<DateTime> onTimeChanged;
  final bool allowFutureTimes;
  final DateTime? minTime;

  @override
  State<InlineTimePicker> createState() => _InlineTimePickerState();
}

class _InlineTimePickerState extends State<InlineTimePicker> {
  DateTime? _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = _clampToNowIfNeeded(widget.initialTime);
  }

  /// Clamps the given time to now if future times are not allowed
  DateTime? _clampToNowIfNeeded(DateTime? time) {
    if (time == null) return null;
    if (!widget.allowFutureTimes && time.isAfter(DateTime.now())) {
      return DateTime.now();
    }
    return time;
  }

  @override
  void didUpdateWidget(InlineTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update if initial time changed significantly (not just minor adjustments)
    final oldTime = oldWidget.initialTime;
    final newTime = widget.initialTime;
    if (oldTime == null && newTime != null) {
      _selectedTime = _clampToNowIfNeeded(newTime);
    } else if (oldTime != null &&
        newTime != null &&
        newTime.difference(oldTime).inMinutes.abs() > 1) {
      _selectedTime = _clampToNowIfNeeded(newTime);
    }
  }

  // Track which button should show error flash
  int? _errorButtonDelta;

  void _adjustMinutes(int delta) {
    // If no time is set, start from now (clamped)
    final baseTime = _selectedTime ?? DateTime.now();
    final newTime = baseTime.add(Duration(minutes: delta));

    // Check if this would go into the future
    if (!widget.allowFutureTimes && newTime.isAfter(DateTime.now())) {
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
    // Use current time as base if no time is set
    final baseTime = _selectedTime ?? DateTime.now();
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

      // Don't allow future times unless explicitly permitted
      if (!widget.allowFutureTimes && newTime.isAfter(DateTime.now())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot select a time in the future'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Don't allow times before min time
      if (widget.minTime != null && newTime.isBefore(widget.minTime!)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End time must be after start time'),
              duration: Duration(seconds: 2),
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
    final timeFormat = DateFormat('h:mm');
    final periodFormat = DateFormat('a');
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
                  isUnset ? '--:--' : timeFormat.format(_selectedTime!),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w300,
                    color: isUnset
                        ? Theme.of(context).colorScheme.outline
                        : null,
                  ),
                ),
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
