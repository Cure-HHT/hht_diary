// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Compact inline date picker for use alongside time pickers
class CompactDatePicker extends StatelessWidget {
  const CompactDatePicker({
    required this.date,
    required this.onChange,
    super.key,
    this.maxDate,
  });

  final DateTime date;
  final ValueChanged<DateTime> onChange;
  final DateTime? maxDate;

  String _formattedDate(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    // Short format: "Dec 5" or "5 Dec" depending on locale
    return DateFormat('MMM d', locale).format(date);
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: maxDate ?? DateTime.now(),
    );

    if (picked != null && picked != date) {
      onChange(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              size: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              _formattedDate(context),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
