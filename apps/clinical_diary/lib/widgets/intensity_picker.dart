import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:flutter/material.dart';

/// Intensity selection widget with visual icons
class IntensityPicker extends StatelessWidget {
  const IntensityPicker({
    required this.onSelect,
    super.key,
    this.selectedIntensity,
  });
  final NosebleedIntensity? selectedIntensity;
  final ValueChanged<NosebleedIntensity> onSelect;

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

          // Icon should be ~40% of box height, leaving room for text and border container
          // Border container adds ~11px (4px padding * 2 + 1.5px border * 2)
          final iconSize = (boxHeight * 0.4).clamp(28.0, 48.0);
          final fontSize = (boxHeight * 0.14).clamp(10.0, 14.0);

          final l10n = AppLocalizations.of(context);
          return Column(
            children: [
              Text(
                l10n.howSevere,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.translate('selectBestOption'),
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
                  children: NosebleedIntensity.values.map((intensity) {
                    final isSelected = selectedIntensity == intensity;
                    return _IntensityOption(
                      intensity: intensity,
                      intensityLabel: l10n.intensityName(intensity.name),
                      isSelected: isSelected,
                      onTap: () => onSelect(intensity),
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

class _IntensityOption extends StatelessWidget {
  const _IntensityOption({
    required this.intensity,
    required this.intensityLabel,
    required this.isSelected,
    required this.onTap,
    this.iconSize = 56,
    this.fontSize = 14,
  });
  final NosebleedIntensity intensity;
  final String intensityLabel;
  final bool isSelected;
  final VoidCallback onTap;
  final double iconSize;
  final double fontSize;

  String get _imagePath {
    switch (intensity) {
      case NosebleedIntensity.spotting:
        return 'assets/images/intensity_spotting.png';
      case NosebleedIntensity.dripping:
        return 'assets/images/intensity_dripping.png';
      case NosebleedIntensity.drippingQuickly:
        return 'assets/images/intensity_dripping_quickly.png';
      case NosebleedIntensity.steadyStream:
        return 'assets/images/intensity_steady_stream.png';
      case NosebleedIntensity.pouring:
        return 'assets/images/intensity_pouring.png';
      case NosebleedIntensity.gushing:
        return 'assets/images/intensity_gushing.png';
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
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.5)
                        : Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  _imagePath,
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                // Split two-word labels onto separate lines
                intensityLabel.replaceAll(' ', '\n'),
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
