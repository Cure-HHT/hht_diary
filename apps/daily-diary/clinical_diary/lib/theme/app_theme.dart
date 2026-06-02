import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

/// Mobile app theme — thin wrapper around `diary_design_system`'s `buildAppTheme`.
///
/// All real theme construction now lives in the shared package. This class
/// preserves the legacy string-typed API one release for safety; new call sites
/// should use [buildAppTheme] directly with [AppFontFamily].
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Font family constants — kept for backward compatibility with FontOption
  // (lib/config/feature_flags.dart) and any persisted preference values.
  // ---------------------------------------------------------------------------

  /// OpenDyslexic font family name (CUR-528).
  @Deprecated('Use AppFontFamily.openDyslexic from diary_design_system')
  static const String openDyslexicFontFamily = 'OpenDyslexic';

  /// Atkinson Hyperlegible font family name (CUR-528).
  @Deprecated('Use AppFontFamily.atkinsonHyperlegible from diary_design_system')
  static const String atkinsonHyperlegibleFontFamily = 'AtkinsonHyperlegible';

  // ---------------------------------------------------------------------------
  // Legacy color constants — preserved to avoid breaking outside callers, but
  // the live theme now uses Carina blue (decision #7 in the design system plan).
  // Callers reading these should migrate to `Theme.of(context).colorScheme`.
  // ---------------------------------------------------------------------------

  @Deprecated('Use Theme.of(context).colorScheme.primary')
  static const Color primaryTeal = Color(0xFF0D9488);

  @Deprecated('Use Theme.of(context).colorScheme.primary')
  static const Color primaryTealDark = Color(0xFF0F766E);

  @Deprecated('Use Theme.of(context).colorScheme.primary')
  static const Color primaryTealLight = Color(0xFF14B8A6);

  @Deprecated('Use AppSemanticColors via Theme.of(context).extension')
  static const Color intensityLow = Color(0xFFE0F2FE);

  @Deprecated('Use AppSemanticColors via Theme.of(context).extension')
  static const Color intensityMedium = Color(0xFFFEF3C7);

  @Deprecated('Use AppSemanticColors via Theme.of(context).extension')
  static const Color intensityHigh = Color(0xFFFFE4E6);

  @Deprecated('Use AppSemanticColors via Theme.of(context).extension')
  static const Color warningYellow = Color(0xFFFEF9C3);

  @Deprecated('Use AppSemanticColors via Theme.of(context).extension')
  static const Color warningOrange = Color(0xFFFFEDD5);

  @Deprecated('Use AppSemanticColors via Theme.of(context).extension')
  static const Color infoBlue = Color(0xFFDBEAFE);

  // ---------------------------------------------------------------------------
  // Theme builders
  // ---------------------------------------------------------------------------

  /// Map the persisted font-family string to [AppFontFamily].
  ///
  /// `'Roboto'` (the historical system-default sentinel) and `null` both map to
  /// [AppFontFamily.inter] — the shared default per decision #2.
  static AppFontFamily fontFromString(String? value) {
    return switch (value) {
      'OpenDyslexic' => AppFontFamily.openDyslexic,
      'AtkinsonHyperlegible' => AppFontFamily.atkinsonHyperlegible,
      _ => AppFontFamily.inter,
    };
  }

  /// Light theme with optional dyslexia-friendly font.
  @Deprecated(
    'Use buildAppTheme(font: AppFontFamily.X) from diary_design_system',
  )
  static ThemeData getLightTheme({bool useDyslexicFont = false}) {
    return buildAppTheme(
      font: useDyslexicFont ? AppFontFamily.openDyslexic : AppFontFamily.inter,
      brightness: Brightness.light,
    );
  }

  /// Dark theme with optional dyslexia-friendly font.
  @Deprecated(
    'Use buildAppTheme(font: AppFontFamily.X) from diary_design_system',
  )
  static ThemeData getDarkTheme({bool useDyslexicFont = false}) {
    return buildAppTheme(
      font: useDyslexicFont ? AppFontFamily.openDyslexic : AppFontFamily.inter,
      brightness: Brightness.dark,
    );
  }

  /// CUR-528: Light theme with selected font.
  @Deprecated(
    'Use buildAppTheme(font: AppFontFamily.X) from diary_design_system',
  )
  static ThemeData getLightThemeWithFont({String? fontFamily}) {
    return buildAppTheme(
      font: fontFromString(fontFamily),
      brightness: Brightness.light,
    );
  }

  /// CUR-528: Dark theme with selected font.
  @Deprecated(
    'Use buildAppTheme(font: AppFontFamily.X) from diary_design_system',
  )
  static ThemeData getDarkThemeWithFont({String? fontFamily}) {
    return buildAppTheme(
      font: fontFromString(fontFamily),
      brightness: Brightness.dark,
    );
  }
}
