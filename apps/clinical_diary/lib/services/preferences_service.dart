// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-CAL-p00002: Short Duration Nosebleed Confirmation
//   REQ-CAL-p00003: Long Duration Nosebleed Confirmation

import 'package:shared_preferences/shared_preferences.dart';

/// User preferences data model
class UserPreferences {
  const UserPreferences({
    this.isDarkMode = false,
    this.dyslexiaFriendlyFont = false,
    this.largerTextAndControls = false,
    this.useAnimation = true,
    this.compactView = false,
    this.languageCode = 'en',
    // REQ-CAL-p00002: Short duration confirmation preference
    this.shortDurationConfirmation = true,
    // REQ-CAL-p00003: Long duration confirmation preference
    this.longDurationConfirmation = true,
    this.longDurationThresholdHours = 1,
  });

  /// Create from JSON (Firebase)
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      dyslexiaFriendlyFont: json['dyslexiaFriendlyFont'] as bool? ?? false,
      largerTextAndControls: json['largerTextAndControls'] as bool? ?? false,
      useAnimation: json['useAnimation'] as bool? ?? true,
      compactView: json['compactView'] as bool? ?? false,
      languageCode: json['languageCode'] as String? ?? 'en',
      shortDurationConfirmation:
          json['shortDurationConfirmation'] as bool? ?? true,
      longDurationConfirmation:
          json['longDurationConfirmation'] as bool? ?? true,
      longDurationThresholdHours:
          json['longDurationThresholdHours'] as int? ?? 1,
    );
  }

  final bool isDarkMode;
  final bool dyslexiaFriendlyFont;
  final bool largerTextAndControls;
  final bool useAnimation;
  final bool compactView;
  final String languageCode;

  /// REQ-CAL-p00002: Whether to show confirmation for durations <= 1 minute
  final bool shortDurationConfirmation;

  /// REQ-CAL-p00003: Whether to show confirmation for long durations
  final bool longDurationConfirmation;

  /// REQ-CAL-p00003: Threshold in hours for long duration confirmation (1-9)
  final int longDurationThresholdHours;

  /// Get the long duration threshold in minutes
  int get longDurationThresholdMinutes => longDurationThresholdHours * 60;

  UserPreferences copyWith({
    bool? isDarkMode,
    bool? dyslexiaFriendlyFont,
    bool? largerTextAndControls,
    bool? useAnimation,
    bool? compactView,
    String? languageCode,
    bool? shortDurationConfirmation,
    bool? longDurationConfirmation,
    int? longDurationThresholdHours,
  }) {
    return UserPreferences(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      dyslexiaFriendlyFont: dyslexiaFriendlyFont ?? this.dyslexiaFriendlyFont,
      largerTextAndControls:
          largerTextAndControls ?? this.largerTextAndControls,
      useAnimation: useAnimation ?? this.useAnimation,
      compactView: compactView ?? this.compactView,
      languageCode: languageCode ?? this.languageCode,
      shortDurationConfirmation:
          shortDurationConfirmation ?? this.shortDurationConfirmation,
      longDurationConfirmation:
          longDurationConfirmation ?? this.longDurationConfirmation,
      longDurationThresholdHours:
          longDurationThresholdHours ?? this.longDurationThresholdHours,
    );
  }

  /// Convert to JSON for Firebase storage
  Map<String, dynamic> toJson() => {
    'isDarkMode': isDarkMode,
    'dyslexiaFriendlyFont': dyslexiaFriendlyFont,
    'largerTextAndControls': largerTextAndControls,
    'useAnimation': useAnimation,
    'compactView': compactView,
    'languageCode': languageCode,
    'shortDurationConfirmation': shortDurationConfirmation,
    'longDurationConfirmation': longDurationConfirmation,
    'longDurationThresholdHours': longDurationThresholdHours,
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
  static const _keyCompactView = 'pref_compact_view';
  static const _keyLanguageCode = 'pref_language_code';
  // REQ-CAL-p00002: Short duration confirmation
  static const _keyShortDurationConfirmation =
      'pref_short_duration_confirmation';
  // REQ-CAL-p00003: Long duration confirmation
  static const _keyLongDurationConfirmation = 'pref_long_duration_confirmation';
  static const _keyLongDurationThresholdHours =
      'pref_long_duration_threshold_hours';

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
      compactView: prefs.getBool(_keyCompactView) ?? false,
      languageCode: prefs.getString(_keyLanguageCode) ?? 'en',
      shortDurationConfirmation:
          prefs.getBool(_keyShortDurationConfirmation) ?? true,
      longDurationConfirmation:
          prefs.getBool(_keyLongDurationConfirmation) ?? true,
      longDurationThresholdHours:
          prefs.getInt(_keyLongDurationThresholdHours) ?? 1,
    );
  }

  /// Save user preferences
  Future<void> savePreferences(UserPreferences preferences) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyDarkMode, preferences.isDarkMode);
    await prefs.setBool(_keyDyslexiaFont, preferences.dyslexiaFriendlyFont);
    await prefs.setBool(_keyLargerControls, preferences.largerTextAndControls);
    await prefs.setBool(_keyUseAnimation, preferences.useAnimation);
    await prefs.setBool(_keyCompactView, preferences.compactView);
    await prefs.setString(_keyLanguageCode, preferences.languageCode);
    await prefs.setBool(
      _keyShortDurationConfirmation,
      preferences.shortDurationConfirmation,
    );
    await prefs.setBool(
      _keyLongDurationConfirmation,
      preferences.longDurationConfirmation,
    );
    await prefs.setInt(
      _keyLongDurationThresholdHours,
      preferences.longDurationThresholdHours,
    );
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
