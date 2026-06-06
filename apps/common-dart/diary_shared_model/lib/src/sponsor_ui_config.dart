// Implements: DIARY-DEV-deployment-config-defaults/A+C — sponsor/deployment UI
//   configuration resolved settings-row -> deployment-default -> code-default; a
//   null settings value counts as unset.
//
// Two concepts live here. `ui.useAnimations` is a value-override capability gate.
// `ui.availableFonts` / `ui.availableLanguages` (with required defaults
// `ui.defaultFont` / `ui.defaultLanguage`) are allow-set constraints: the sponsor
// constrains the option set, the participant still picks within it. None of these
// keys are participant-editable.
library;

import 'settings.dart';

/// Platform language codes the diary ships (code-default allow-set).
const List<String> kPlatformLanguageCodes = <String>['en', 'es', 'fr', 'de'];

/// Platform font families the diary ships (code-default allow-set).
const List<String> kPlatformFontFamilies = <String>[
  'Roboto',
  'OpenDyslexic',
  'AtkinsonHyperlegible',
];

/// Settings-stream keys for the sponsor/deployment UI configuration.
const String uiUseAnimationsKey = 'ui.useAnimations';
const String uiAvailableFontsKey = 'ui.availableFonts';
const String uiDefaultFontKey = 'ui.defaultFont';
const String uiAvailableLanguagesKey = 'ui.availableLanguages';
const String uiDefaultLanguageKey = 'ui.defaultLanguage';

/// Sponsor/deployment-controlled UI configuration: the animation capability gate
/// and the font/language allow-sets with their required defaults. These are never
/// participant-editable; the participant only picks within an allow-set.
class SponsorUiConfig {
  const SponsorUiConfig({
    this.useAnimations = true,
    this.availableFonts = kPlatformFontFamilies,
    this.defaultFont = 'Roboto',
    this.availableLanguages = kPlatformLanguageCodes,
    this.defaultLanguage = 'en',
  });

  final bool useAnimations;
  final List<String> availableFonts;
  final String defaultFont;
  final List<String> availableLanguages;
  final String defaultLanguage;

  /// The hardcoded code-default layer.
  static const SponsorUiConfig codeDefault = SponsorUiConfig();

  /// Resolve from the folded settings map. For each key: a present, non-null
  /// settings value wins; otherwise the [deploymentDefaults] value; otherwise the
  /// code default. Pure and deterministic.
  factory SponsorUiConfig.fromSettings(
    Map<String, SettingPayload> settings, {
    SponsorUiConfig deploymentDefaults = codeDefault,
  }) {
    bool boolOf(String key, bool fallback) {
      final v = settings[key]?.value;
      return v is bool ? v : fallback;
    }

    String stringOf(String key, String fallback) {
      final v = settings[key]?.value;
      return v is String ? v : fallback;
    }

    List<String> listOf(String key, List<String> fallback) {
      final v = settings[key]?.value;
      if (v is List) {
        return v.whereType<String>().toList(growable: false);
      }
      return fallback;
    }

    return SponsorUiConfig(
      useAnimations: boolOf(
        uiUseAnimationsKey,
        deploymentDefaults.useAnimations,
      ),
      availableFonts: listOf(
        uiAvailableFontsKey,
        deploymentDefaults.availableFonts,
      ),
      defaultFont: stringOf(uiDefaultFontKey, deploymentDefaults.defaultFont),
      availableLanguages: listOf(
        uiAvailableLanguagesKey,
        deploymentDefaults.availableLanguages,
      ),
      defaultLanguage: stringOf(
        uiDefaultLanguageKey,
        deploymentDefaults.defaultLanguage,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SponsorUiConfig &&
      other.useAnimations == useAnimations &&
      _listEq(other.availableFonts, availableFonts) &&
      other.defaultFont == defaultFont &&
      _listEq(other.availableLanguages, availableLanguages) &&
      other.defaultLanguage == defaultLanguage;

  @override
  int get hashCode => Object.hash(
    useAnimations,
    Object.hashAll(availableFonts),
    defaultFont,
    Object.hashAll(availableLanguages),
    defaultLanguage,
  );
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Pure reconciliation: if [current] is not in [allowed], returns [fallback]
/// (the value to write); otherwise returns null (no corrective write needed).
// Implements: DIARY-DEV-deployment-config-defaults/E
String? reconcilePick({
  required String current,
  required List<String> allowed,
  required String fallback,
}) {
  if (allowed.contains(current)) return null;
  return fallback;
}
