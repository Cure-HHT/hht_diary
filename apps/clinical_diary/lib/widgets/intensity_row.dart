// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

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
    required this.isSelected,
    required this.onTap,
    required this.size,
  });

  final NosebleedSeverity intensity;
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
    // Icon should be about 70% of the container size
    final iconSize = size * 0.7;

    return Tooltip(
      message: intensity.displayName,
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
            child: Center(
              child: Image.asset(
                _imagePath,
                width: iconSize,
                height: iconSize,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
