// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:shared_preferences/shared_preferences.dart';

/// User preferences data model
class UserPreferences {
  const UserPreferences({
    this.isDarkMode = false,
    this.largerTextAndControls = false,
    this.useAnimation = true,
    this.compactView = false,
    this.languageCode = 'en',
    this.selectedFont = 'Roboto',
  });

  /// Create from JSON (Firebase)
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    // Migrate old dyslexiaFriendlyFont boolean to selectedFont
    final legacyDyslexiaFont = json['dyslexiaFriendlyFont'] as bool? ?? false;
    final savedFont = json['selectedFont'] as String?;
    final effectiveFont =
        savedFont ?? (legacyDyslexiaFont ? 'OpenDyslexic' : 'Roboto');

    return UserPreferences(
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      largerTextAndControls: json['largerTextAndControls'] as bool? ?? false,
      useAnimation: json['useAnimation'] as bool? ?? true,
      compactView: json['compactView'] as bool? ?? false,
      languageCode: json['languageCode'] as String? ?? 'en',
      selectedFont: effectiveFont,
    );
  }

  final bool isDarkMode;
  final bool largerTextAndControls;
  final bool useAnimation;
  final bool compactView;
  final String languageCode;

  /// CUR-528: Selected font family name (e.g., 'Roboto', 'OpenDyslexic', 'AtkinsonHyperlegible')
  final String selectedFont;

  UserPreferences copyWith({
    bool? isDarkMode,
    @Deprecated('Use selectedFont instead') bool? dyslexiaFriendlyFont,
    bool? largerTextAndControls,
    bool? useAnimation,
    bool? compactView,
    String? languageCode,
    String? selectedFont,
  }) {
    return UserPreferences(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      largerTextAndControls:
          largerTextAndControls ?? this.largerTextAndControls,
      useAnimation: useAnimation ?? this.useAnimation,
      compactView: compactView ?? this.compactView,
      languageCode: languageCode ?? this.languageCode,
      selectedFont: selectedFont ?? this.selectedFont,
    );
  }

  /// Convert to JSON for Firebase storage
  Map<String, dynamic> toJson() => {
    'isDarkMode': isDarkMode,
    'largerTextAndControls': largerTextAndControls,
    'useAnimation': useAnimation,
    'compactView': compactView,
    'languageCode': languageCode,
    'selectedFont': selectedFont,
  };
}

/// Service for managing user preferences
class PreferencesService {
  PreferencesService({SharedPreferences? sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  static const _keyDarkMode = 'pref_dark_mode';
  static const _keyDyslexiaFont =
      'pref_dyslexia_font'; // Deprecated, kept for migration
  static const _keyLargerControls = 'pref_larger_controls';
  static const _keyUseAnimation = 'pref_use_animation';
  static const _keyCompactView = 'pref_compact_view';
  static const _keyLanguageCode = 'pref_language_code';
  static const _keySelectedFont = 'pref_selected_font';

  SharedPreferences? _sharedPreferences;

  Future<SharedPreferences> _getPrefs() async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
    return _sharedPreferences!;
  }

  /// Get current user preferences
  Future<UserPreferences> getPreferences() async {
    final prefs = await _getPrefs();

    // Migration: if selectedFont not set but dyslexia font was, migrate
    final legacyDyslexiaFont = prefs.getBool(_keyDyslexiaFont) ?? false;
    final savedFont = prefs.getString(_keySelectedFont);
    final effectiveFont =
        savedFont ?? (legacyDyslexiaFont ? 'OpenDyslexic' : 'Roboto');

    return UserPreferences(
      isDarkMode: prefs.getBool(_keyDarkMode) ?? false,
      largerTextAndControls: prefs.getBool(_keyLargerControls) ?? false,
      useAnimation: prefs.getBool(_keyUseAnimation) ?? true,
      compactView: prefs.getBool(_keyCompactView) ?? false,
      languageCode: prefs.getString(_keyLanguageCode) ?? 'en',
      selectedFont: effectiveFont,
    );
  }

  /// Save user preferences
  Future<void> savePreferences(UserPreferences preferences) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyDarkMode, preferences.isDarkMode);
    await prefs.setBool(_keyLargerControls, preferences.largerTextAndControls);
    await prefs.setBool(_keyUseAnimation, preferences.useAnimation);
    await prefs.setBool(_keyCompactView, preferences.compactView);
    await prefs.setString(_keyLanguageCode, preferences.languageCode);
    await prefs.setString(_keySelectedFont, preferences.selectedFont);
  }

  /// Update dark mode preference
  Future<void> setDarkMode(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyDarkMode, value);
  }

  /// Update dyslexia-friendly font preference
  @Deprecated('Use setSelectedFont instead')
  Future<void> setDyslexiaFriendlyFont(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyDyslexiaFont, value);
  }

  /// CUR-528: Update selected font preference
  Future<void> setSelectedFont(String fontFamily) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keySelectedFont, fontFamily);
  }

  /// CUR-528: Get selected font preference
  Future<String> getSelectedFont() async {
    final prefs = await _getPrefs();
    // Migration: check old dyslexia font setting if selectedFont not set
    final savedFont = prefs.getString(_keySelectedFont);
    if (savedFont != null) return savedFont;

    final legacyDyslexiaFont = prefs.getBool(_keyDyslexiaFont) ?? false;
    return legacyDyslexiaFont ? 'OpenDyslexic' : 'Roboto';
  }

  /// Update larger text and controls preference
  Future<void> setLargerTextAndControls(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyLargerControls, value);
  }

  /// Update use animation preference
  Future<void> setUseAnimation(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyUseAnimation, value);
  }

  /// Get use animation preference
  Future<bool> getUseAnimation() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyUseAnimation) ?? true;
  }

  /// Update compact view preference
  Future<void> setCompactView(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyCompactView, value);
  }

  /// Get compact view preference
  Future<bool> getCompactView() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyCompactView) ?? false;
  }

  /// Update language preference
  Future<void> setLanguageCode(String code) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyLanguageCode, code);
  }

  /// Get language code
  Future<String> getLanguageCode() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyLanguageCode) ?? 'en';
  }
}
