// Implements: DIARY-DEV-deployment-config-defaults/B+C — per-distribution UI
//   defaults from a bundled asset; absent/missing keys fall to code defaults.
//   Resolution-time fallback only; never written to the event log.
import 'dart:convert';

import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Loads `assets/config/config_defaults.json` into a [SponsorUiConfig] used as the
/// deployment-default fallback. A missing file, unparseable JSON, or missing keys
/// fall through to the code defaults.
Future<SponsorUiConfig> loadDeploymentUiDefaults({AssetBundle? bundle}) async {
  final b = bundle ?? rootBundle;
  Map<String, Object?> json;
  try {
    final raw = await b.loadString('assets/config/config_defaults.json');
    json = (jsonDecode(raw) as Map).cast<String, Object?>();
  } catch (_) {
    return SponsorUiConfig.codeDefault;
  }

  List<String> list(String key, List<String> fallback) {
    final v = json[key];
    return v is List ? v.whereType<String>().toList() : fallback;
  }

  String str(String key, String fallback) {
    final v = json[key];
    return v is String ? v : fallback;
  }

  String? nullableStr(String key) {
    final v = json[key];
    return v is String ? v : null;
  }

  bool boolean(String key, bool fallback) {
    final v = json[key];
    return v is bool ? v : fallback;
  }

  const d = SponsorUiConfig.codeDefault;
  return SponsorUiConfig(
    useAnimations: boolean(uiUseAnimationsKey, d.useAnimations),
    availableFonts: list(uiAvailableFontsKey, d.availableFonts),
    defaultFont: str(uiDefaultFontKey, d.defaultFont),
    availableLanguages: list(uiAvailableLanguagesKey, d.availableLanguages),
    defaultLanguage: str(uiDefaultLanguageKey, d.defaultLanguage),
    notParticipatingMessage: nullableStr(uiNotParticipatingMessageKey),
  );
}
