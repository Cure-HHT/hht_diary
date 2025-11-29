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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate icon size based on available height
          // Header ~70px (title + subtitle + spacing), grid spacing ~16px (2 gaps)
          // We need 3 rows of boxes to fit
          const headerHeight = 80.0;
          const gridSpacing = 16.0; // 2 gaps * 8px each
          final availableHeight =
              constraints.maxHeight - headerHeight - gridSpacing;
          final boxHeight = (availableHeight / 3).clamp(60.0, 110.0);

          // Icon should be ~55% of box height, leaving room for text
          final iconSize = (boxHeight * 0.5).clamp(32.0, 56.0);
          final fontSize = (boxHeight * 0.14).clamp(10.0, 14.0);

          return Column(
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
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: (constraints.maxWidth / 2 - 12) / boxHeight,
                  physics: const NeverScrollableScrollPhysics(),
                  children: NosebleedSeverity.values.map((severity) {
                    final isSelected = selectedSeverity == severity;
                    return _SeverityOption(
                      severity: severity,
                      isSelected: isSelected,
                      onTap: () => onSelect(severity),
                      iconSize: iconSize,
                      fontSize: fontSize,
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SeverityOption extends StatelessWidget {
  const _SeverityOption({
    required this.severity,
    required this.isSelected,
    required this.onTap,
    this.iconSize = 56,
    this.fontSize = 14,
  });
  final NosebleedSeverity severity;
  final bool isSelected;
  final VoidCallback onTap;
  final double iconSize;
  final double fontSize;

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
                width: iconSize,
                height: iconSize,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 4),
              Text(
                severity.displayName,
                style: TextStyle(
                  fontSize: fontSize,
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
