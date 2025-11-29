// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:shared_preferences/shared_preferences.dart';

/// User preferences data model
class UserPreferences {
  const UserPreferences({
    this.isDarkMode = false,
    this.dyslexiaFriendlyFont = false,
    this.largerTextAndControls = false,
    this.languageCode = 'en',
  });

  final bool isDarkMode;
  final bool dyslexiaFriendlyFont;
  final bool largerTextAndControls;
  final String languageCode;

  UserPreferences copyWith({
    bool? isDarkMode,
    bool? dyslexiaFriendlyFont,
    bool? largerTextAndControls,
    String? languageCode,
  }) {
    return UserPreferences(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      dyslexiaFriendlyFont: dyslexiaFriendlyFont ?? this.dyslexiaFriendlyFont,
      largerTextAndControls:
          largerTextAndControls ?? this.largerTextAndControls,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}

/// Service for managing user preferences
class PreferencesService {
  PreferencesService({SharedPreferences? sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  static const _keyDarkMode = 'pref_dark_mode';
  static const _keyDyslexiaFont = 'pref_dyslexia_font';
  static const _keyLargerControls = 'pref_larger_controls';
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
      languageCode: prefs.getString(_keyLanguageCode) ?? 'en',
    );
  }

  /// Save user preferences
  Future<void> savePreferences(UserPreferences preferences) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyDarkMode, preferences.isDarkMode);
    await prefs.setBool(_keyDyslexiaFont, preferences.dyslexiaFriendlyFont);
    await prefs.setBool(_keyLargerControls, preferences.largerTextAndControls);
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
