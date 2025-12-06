// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:shared_preferences/shared_preferences.dart';

/// User preferences data model
class UserPreferences {
  const UserPreferences({
    this.isDarkMode = false,
    this.dyslexiaFriendlyFont = false,
    this.largerTextAndControls = false,
    this.useAnimation = true,
    this.languageCode = 'en',
  });

  /// Create from JSON (Firebase)
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      dyslexiaFriendlyFont: json['dyslexiaFriendlyFont'] as bool? ?? false,
      largerTextAndControls: json['largerTextAndControls'] as bool? ?? false,
      useAnimation: json['useAnimation'] as bool? ?? true,
      languageCode: json['languageCode'] as String? ?? 'en',
    );
  }

  final bool isDarkMode;
  final bool dyslexiaFriendlyFont;
  final bool largerTextAndControls;
  final bool useAnimation;
  final String languageCode;

  UserPreferences copyWith({
    bool? isDarkMode,
    bool? dyslexiaFriendlyFont,
    bool? largerTextAndControls,
    bool? useAnimation,
    String? languageCode,
  }) {
    return UserPreferences(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      dyslexiaFriendlyFont: dyslexiaFriendlyFont ?? this.dyslexiaFriendlyFont,
      largerTextAndControls:
          largerTextAndControls ?? this.largerTextAndControls,
      useAnimation: useAnimation ?? this.useAnimation,
      languageCode: languageCode ?? this.languageCode,
    );
  }

  /// Convert to JSON for Firebase storage
  Map<String, dynamic> toJson() => {
    'isDarkMode': isDarkMode,
    'dyslexiaFriendlyFont': dyslexiaFriendlyFont,
    'largerTextAndControls': largerTextAndControls,
    'useAnimation': useAnimation,
    'languageCode': languageCode,
  };
}

/// Service for managing user preferences
class PreferencesService {
  PreferencesService({SharedPreferences? sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  static const _keyDarkMode = 'pref_dark_mode';
  static const _keyDyslexiaFont = 'pref_dyslexia_font';
  static const _keyLargerControls = 'pref_larger_controls';
  static const _keyUseAnimation = 'pref_use_animation';
  static const _keyLanguageCode = 'pref_language_code';

  SharedPreferences? _sharedPreferences;

  Future<SharedPreferences> _getPrefs() async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
    return _sharedPreferences!;
  }

  /// Get current user preferences
  Future<UserPreferences> getPreferences() async {
    final prefs = await _getPrefs();
    return UserPreferences(
      isDarkMode: prefs.getBool(_keyDarkMode) ?? false,
      dyslexiaFriendlyFont: prefs.getBool(_keyDyslexiaFont) ?? false,
      largerTextAndControls: prefs.getBool(_keyLargerControls) ?? false,
      useAnimation: prefs.getBool(_keyUseAnimation) ?? true,
      languageCode: prefs.getString(_keyLanguageCode) ?? 'en',
    );
  }

  /// Save user preferences
  Future<void> savePreferences(UserPreferences preferences) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyDarkMode, preferences.isDarkMode);
    await prefs.setBool(_keyDyslexiaFont, preferences.dyslexiaFriendlyFont);
    await prefs.setBool(_keyLargerControls, preferences.largerTextAndControls);
    await prefs.setBool(_keyUseAnimation, preferences.useAnimation);
    await prefs.setString(_keyLanguageCode, preferences.languageCode);
  }

  /// Update dark mode preference
  Future<void> setDarkMode(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyDarkMode, value);
  }

  /// Update dyslexia-friendly font preference
  Future<void> setDyslexiaFriendlyFont(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyDyslexiaFont, value);
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
