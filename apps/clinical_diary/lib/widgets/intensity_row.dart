// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:flutter/material.dart';

/// Compact intensity selector displayed as a single row of tappable icons
/// Icons are at least 40x40 (preferably 60x60+) and fill available horizontal space
class IntensityRow extends StatelessWidget {
  const IntensityRow({
    required this.onSelect,
    super.key,
    this.selectedIntensity,
  });

  final NosebleedSeverity? selectedIntensity;
  final ValueChanged<NosebleedSeverity> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate item width to fill available space
        // 6 items with 4px spacing between them = 5 gaps * 4px = 20px total spacing
        const itemCount = 6;
        const spacingBetween = 4.0;
        const totalSpacing = (itemCount - 1) * spacingBetween;
        final itemWidth = (constraints.maxWidth - totalSpacing) / itemCount;

        // Ensure minimum size of 40, prefer 60+
        final effectiveSize = itemWidth.clamp(40.0, double.infinity);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: NosebleedSeverity.values.map((intensity) {
            final isSelected = selectedIntensity == intensity;
            return _IntensityItem(
              intensity: intensity,
              label: l10n.severityName(intensity.name),
              isSelected: isSelected,
              onTap: () => onSelect(intensity),
              size: effectiveSize,
            );
          }).toList(),
        );
      },
    );
  }
}

class _IntensityItem extends StatelessWidget {
  const _IntensityItem({
    required this.intensity,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.size,
  });

  final NosebleedSeverity intensity;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double size;

  String get _imagePath {
    switch (intensity) {
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
    // Icon should be about 50% of the container size to leave room for text
    final iconSize = size * 0.5;
    // Font size scales with container
    final fontSize = (size * 0.18).clamp(9.0, 13.0);

    return Tooltip(
      message: label,
      child: Material(
        color: _getBackgroundColor(context),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
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
                const SizedBox(height: 2),
                Text(
                  // Split two-word labels onto separate lines
                  label.replaceAll(' ', '\n'),
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
