/// Shared design system for the diary mobile app and sponsor portal —
/// tokens, theme, and reusable components.
///
/// Public API:
/// - Theme construction: [buildAppTheme], [AppFontFamily], [BrandPalette]
/// - Semantic colors: [AppSemanticColors] (read via Theme.of(context).extension)
/// - Components: [EnvironmentBanner] (more land in later phases)
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
