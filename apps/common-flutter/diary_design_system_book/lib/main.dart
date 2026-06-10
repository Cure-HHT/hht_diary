import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'use_cases/app_alert_row.dart';
import 'use_cases/app_banner.dart';
import 'use_cases/app_button.dart';
import 'use_cases/app_checkbox.dart';
import 'use_cases/app_code_input.dart';
import 'use_cases/app_consent_row.dart';
import 'use_cases/app_data_table.dart';
import 'use_cases/app_dialog.dart';
import 'use_cases/app_dropdown.dart';
import 'use_cases/app_expansion_tile.dart';
import 'use_cases/app_segmented_choice.dart';
import 'use_cases/app_text_field.dart';
import 'use_cases/branded_status_card.dart';
import 'use_cases/event_list_item.dart';
import 'use_cases/feedback_layout.dart';
import 'use_cases/known_bugs.dart';

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
      directories: [
        WidgetbookFolder(
          name: 'Components',
          children: [
            appButtonComponent(),
            appBannerComponent(),
            appDialogComponent(),
            appTextFieldComponent(),
            appDropdownComponent(),
            appCheckboxComponent(),
            appDataTableComponent(),
          ],
        ),
        WidgetbookFolder(
          name: 'Notifications + Alerts',
          children: [
            appExpansionTileComponent(),
            appAlertRowComponent(),
            eventListItemComponent(),
            appConsentRowComponent(),
            appCodeInputComponent(),
            brandedStatusCardComponent(),
            appSegmentedChoiceComponent(),
          ],
        ),
        feedbackLayoutFolder(),
        knownBugsFolder(),
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
            // Dark is a known-broken placeholder (see "Known Bugs"); wired here
            // so the standard galleries can be flipped to dark to see it too.
            WidgetbookTheme(
              name: 'Dark (broken placeholder)',
              data: buildAppTheme(
                font: AppFontFamily.inter,
                brightness: Brightness.dark,
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
