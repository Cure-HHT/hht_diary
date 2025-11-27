import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:flutter/material.dart';

/// Severity selection widget with visual icons
class SeverityPicker extends StatelessWidget {

  const SeverityPicker({
    required this.onSelect, super.key,
    this.selectedSeverity,
  });
  final NosebleedSeverity? selectedSeverity;
  final ValueChanged<NosebleedSeverity> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'How severe is the nosebleed?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the option that best describes the bleeding',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: NosebleedSeverity.values.map((severity) {
                final isSelected = selectedSeverity == severity;
                return _SeverityOption(
                  severity: severity,
                  isSelected: isSelected,
                  onTap: () => onSelect(severity),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityOption extends StatelessWidget {

  const _SeverityOption({
    required this.severity,
    required this.isSelected,
    required this.onTap,
  });
  final NosebleedSeverity severity;
  final bool isSelected;
  final VoidCallback onTap;

  IconData get _icon {
    switch (severity) {
      case NosebleedSeverity.spotting:
        return Icons.water_drop_outlined;
      case NosebleedSeverity.dripping:
        return Icons.water_drop;
      case NosebleedSeverity.drippingQuickly:
        return Icons.opacity;
      case NosebleedSeverity.steadyStream:
        return Icons.stream;
      case NosebleedSeverity.pouring:
        return Icons.water;
      case NosebleedSeverity.gushing:
        return Icons.waves;
    }
  }

  Color _getBackgroundColor(BuildContext context) {
    if (isSelected) {
      return Theme.of(context).colorScheme.primaryContainer;
    }
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  Color _getIconColor(BuildContext context) {
    // Use a neutral blue-grey scale instead of alarming red
    switch (severity) {
      case NosebleedSeverity.spotting:
        return Colors.blueGrey.shade200;
      case NosebleedSeverity.dripping:
        return Colors.blueGrey.shade300;
      case NosebleedSeverity.drippingQuickly:
        return Colors.blueGrey.shade400;
      case NosebleedSeverity.steadyStream:
        return Colors.blueGrey.shade500;
      case NosebleedSeverity.pouring:
        return Colors.blueGrey.shade600;
      case NosebleedSeverity.gushing:
        return Colors.blueGrey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _getBackgroundColor(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _icon,
                size: 48,
                color: _getIconColor(context),
              ),
              const SizedBox(height: 8),
              Text(
                severity.displayName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
