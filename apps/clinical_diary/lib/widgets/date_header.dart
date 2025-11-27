// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Date header widget that allows selecting a date
class DateHeader extends StatelessWidget {
  const DateHeader({
    required this.date,
    required this.onChange,
    this.editable = true,
    super.key,
  });

  final DateTime date;
  final ValueChanged<DateTime> onChange;
  final bool editable;

  String get _formattedDate => DateFormat('EEEE, MMMM d').format(date);

  Future<void> _selectDate(BuildContext context) async {
    if (!editable) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != date) {
      onChange(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: editable ? () => _selectDate(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: editable
              ? Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formattedDate,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            if (editable) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.calendar_today,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
