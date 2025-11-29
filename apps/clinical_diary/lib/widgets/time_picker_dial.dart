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
  });
  final String title;
  final DateTime initialTime;
  final ValueChanged<DateTime> onConfirm;
  final String confirmLabel;
  final bool allowFutureTimes;

  @override
  State<TimePickerDial> createState() => _TimePickerDialState();
}

class _TimePickerDialState extends State<TimePickerDial> {
  late DateTime _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
  }

  // Track which button should show error flash
  int? _errorButtonDelta;

  void _adjustMinutes(int delta) {
    final newTime = _selectedTime.add(Duration(minutes: delta));

    // Check if this would go into the future
    if (!widget.allowFutureTimes && newTime.isAfter(DateTime.now())) {
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
      // Don't allow future times unless explicitly permitted
      if (!widget.allowFutureTimes && newTime.isAfter(DateTime.now())) {
        // Show feedback that future time was rejected
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
      setState(() {
        _selectedTime = newTime;
      });
      // Auto-confirm when user selects from native time picker
      widget.onConfirm(newTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm');
    final periodFormat = DateFormat('a');

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

          // Time display
          GestureDetector(
            onTap: _showTimePicker,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  timeFormat.format(_selectedTime),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w300,
                    fontSize: 72,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  periodFormat.format(_selectedTime),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w400,
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
              const SizedBox(width: 12),
              _AdjustButton(
                label: '-5',
                onPressed: () => _adjustMinutes(-5),
                showError: _errorButtonDelta == -5,
              ),
              const SizedBox(width: 12),
              _AdjustButton(
                label: '-1',
                onPressed: () => _adjustMinutes(-1),
                showError: _errorButtonDelta == -1,
              ),
              const SizedBox(width: 24),
              _AdjustButton(
                label: '+1',
                onPressed: () => _adjustMinutes(1),
                showError: _errorButtonDelta == 1,
              ),
              const SizedBox(width: 12),
              _AdjustButton(
                label: '+5',
                onPressed: () => _adjustMinutes(5),
                showError: _errorButtonDelta == 5,
              ),
              const SizedBox(width: 12),
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
              onPressed: () => widget.onConfirm(_selectedTime),
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
