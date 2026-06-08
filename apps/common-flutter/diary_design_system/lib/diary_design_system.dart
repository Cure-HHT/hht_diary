/// Shared design system for the diary mobile app and sponsor portal —
/// tokens, theme, and reusable components.
///
/// Public API:
/// - Theme construction: [buildAppTheme], [AppFontFamily], [BrandPalette]
/// - Semantic colors: [AppSemanticColors] (read via Theme.of(context).extension)
/// - Components: [AppButton], [AppBanner], [EnvironmentBanner] (more land in later phases)
///
/// Raw tokens (color/spacing/radius/etc.) are intentionally NOT exported.
/// Components consume the resolved theme, never raw tokens — see Principle #3
/// in docs/superpowers/specs/design-system-plan.md.
library;

export 'src/environment_banner.dart';

// Theme — public API
export 'src/theme/app_color_scheme.dart';
export 'src/theme/app_text_theme.dart';
export 'src/theme/app_theme.dart';
export 'src/theme/app_theme_extension.dart';
export 'src/theme/brand_palette.dart';

// Components
export 'src/buttons/app_button.dart';
export 'src/dialogs/app_dialog.dart';
export 'src/dialogs/app_dialog_size.dart';
export 'src/feedback/app_badge.dart';
export 'src/feedback/app_banner.dart';
export 'src/feedback/status_badge.dart';
export 'src/inputs/app_checkbox.dart';
export 'src/inputs/app_dropdown.dart';
export 'src/inputs/app_text_field.dart';
export 'src/layout/app_card.dart';
export 'src/layout/app_info_row.dart';
export 'src/layout/app_section_header.dart';
export 'src/layout/breakpoints.dart';
export 'src/layout/responsive_builder.dart';
export 'src/tables/app_data_table.dart';
export 'src/tables/app_table_pagination.dart';
export 'src/tables/app_table_tabs.dart';
