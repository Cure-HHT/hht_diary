import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:flutter/material.dart';

/// Severity selection widget with visual icons
class SeverityPicker extends StatelessWidget {
  const SeverityPicker({
    required this.onSelect,
    super.key,
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
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the option that best describes the bleeding',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
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

  String get _imagePath {
    switch (severity) {
      case NosebleedSeverity.spotting:
        return 'assets/images/severity_spotting.png';
      case NosebleedSeverity.dripping:
        return 'assets/images/severity_dripping.png';
      case NosebleedSeverity.drippingQuickly:
        return 'assets/images/severity_dripping_quickly.png';
      case NosebleedSeverity.steadyStream:
        return 'assets/images/severity_steady_stream.png';
      case NosebleedSeverity.pouring:
        return 'assets/images/severity_pouring.png';
      case NosebleedSeverity.gushing:
        return 'assets/images/severity_gushing.png';
    }
  }

  Color _getBackgroundColor(BuildContext context) {
    if (isSelected) {
      return Theme.of(context).colorScheme.primaryContainer;
    }
    return Theme.of(context).colorScheme.surfaceContainerHighest;
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
              Image.asset(
                _imagePath,
                width: 56,
                height: 56,
                fit: BoxFit.contain,
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
