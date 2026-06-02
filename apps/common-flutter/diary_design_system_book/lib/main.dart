import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  runApp(const DesignSystemBook());
}

/// Widgetbook gallery for the diary_design_system.
///
/// Run locally with `flutter run -d chrome`. Component use cases are added in
/// later phases — Phase 3 (`AppButton` + `AppBanner`), Phase 4 (`AppDialog`),
/// Phase 5 (inputs, tables, tabs), Phase 6 (feedback, layout, badges). Each
/// component phase lands its use cases as the same commit that introduces the
/// component.
class DesignSystemBook extends StatelessWidget {
  const DesignSystemBook({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: const [
        // Use cases land here as each component phase ships.
      ],
      addons: [
        MaterialThemeAddon(
          themes: [
            WidgetbookTheme(
              name: 'Light',
              data: buildAppTheme(
                font: AppFontFamily.inter,
                brightness: Brightness.light,
              ),
            ),
          ],
        ),
        TextScaleAddon(min: 1.0, max: 2.0),
        AlignmentAddon(),
      ],
    );
  }
}
