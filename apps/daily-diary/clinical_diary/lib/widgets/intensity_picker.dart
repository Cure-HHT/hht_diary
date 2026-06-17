import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/widgets/nosebleed_intensity.dart';
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
    // CUR-488 Phase 2: Reduced top padding from 8 to 4 for small screens with large text
    return Padding(
      padding: const EdgeInsets.only(
        left: 12.0,
        right: 12.0,
        top: 4.0,
        bottom: 8.0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate icon size based on available height
          // Header ~70px (title + subtitle + spacing), grid spacing ~24px (2 gaps)
          // We need 3 rows of boxes to fit
          const headerHeight = 70.0;
          const gridSpacing = 24.0; // 2 gaps * 12px each
          final availableHeight =
              constraints.maxHeight - headerHeight - gridSpacing;
          final boxHeight = (availableHeight / 3).clamp(70.0, 150.0);

          // Illustration fills most of the box, leaving room for the label
          // (Figma 515:3296 — ~94px image + 19px label in a ~148px cell).
          final iconSize = (boxHeight * 0.62).clamp(40.0, 94.0);
          final fontSize = (boxHeight * 0.12).clamp(11.0, 15.0);

          final l10n = AppLocalizations.of(context);
          return Column(
            children: [
              // CUR-488 Phase 2: Don't scale titles to avoid scrolling on small screens
              MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.noScaling),
                child: Column(
                  children: [
                    // Figma "Heading 3" — Inter SemiBold 24 on Black.
                    Text(
                      l10n.howSevere,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        height: 34 / 24,
                        letterSpacing: 0.18,
                        color: Color(0xFF04161E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.translate('selectBestOption'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 21.25 / 15,
                        letterSpacing: -0.22,
                        color: Color(0xFF717182),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: (constraints.maxWidth / 2 - 18) / boxHeight,
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

  // Figma 515:3288 illustrations, exported per-severity from the masked
  // sprite (nodes 682:3046/3031/3051/3037/3040/3043).
  String get _imagePath {
    switch (intensity) {
      case NosebleedIntensity.spotting:
        return 'assets/icons/figma/intensity_spotting.png';
      case NosebleedIntensity.dripping:
        return 'assets/icons/figma/intensity_dripping.png';
      case NosebleedIntensity.drippingQuickly:
        return 'assets/icons/figma/intensity_dripping_quickly.png';
      case NosebleedIntensity.steadyStream:
        return 'assets/icons/figma/intensity_steady_stream.png';
      case NosebleedIntensity.pouring:
        return 'assets/icons/figma/intensity_pouring.png';
      case NosebleedIntensity.gushing:
        return 'assets/icons/figma/intensity_gushing.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Figma 515:3296: borderless option — illustration over a Medium label.
    // The selected state keeps a visible cue (Light Gray chip + primary ring)
    // so the summary-bar edit path still shows the current choice.
    return Material(
      color: isSelected ? const Color(0xFFECEEF0) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(_imagePath, height: iconSize, fit: BoxFit.contain),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    intensityLabel,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.22,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFF0A0A0A),
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
