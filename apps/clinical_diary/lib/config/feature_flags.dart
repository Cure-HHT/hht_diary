// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-CAL-p00001: Old Entry Modification Justification
//   REQ-CAL-p00002: Short Duration Nosebleed Confirmation
//   REQ-CAL-p00003: Long Duration Nosebleed Confirmation

import 'package:shared_preferences/shared_preferences.dart';

/// Feature flag default values and constraints.
/// These are sponsor-controlled settings that can be set at enrollment time.
/// Values are stored in SharedPreferences and can be modified in dev/qa builds.
class FeatureFlags {
  // === Default values (used when sponsor hasn't configured) ===

  /// Default: false - skip review screen, return directly to home
  static const bool defaultUseReviewScreen = false;

  /// Default: true - animations enabled, user preference toggle visible
  static const bool defaultUseAnimations = true;

  /// REQ-CAL-p00001: Default: false - old entry justification not required
  static const bool defaultRequireOldEntryJustification = false;

  /// REQ-CAL-p00002: Default: false - short duration confirmation disabled
  static const bool defaultEnableShortDurationConfirmation = false;

  /// REQ-CAL-p00003: Default: false - long duration confirmation disabled
  static const bool defaultEnableLongDurationConfirmation = false;

  /// Default threshold for long duration confirmation (in minutes).
  static const int defaultLongDurationThresholdMinutes = 60;

  // === Constraints ===

  /// Minimum configurable long duration threshold (1 hour)
  static const int minLongDurationThresholdHours = 1;

  /// Maximum configurable long duration threshold (9 hours)
  static const int maxLongDurationThresholdHours = 9;
}

/// Feature flag service for sponsor-controlled settings.
/// Values are set at enrollment time based on sponsor configuration.
/// Can be modified in dev/qa builds for testing purposes.
class FeatureFlagService {
  FeatureFlagService._();

  static final FeatureFlagService _instance = FeatureFlagService._();
  static FeatureFlagService get instance => _instance;

  // Storage keys
  static const _keyUseReviewScreen = 'ff_use_review_screen';
  static const _keyUseAnimations = 'ff_use_animations';
  static const _keyRequireOldEntryJustification =
      'ff_require_old_entry_justification';
  static const _keyEnableShortDurationConfirmation =
      'ff_enable_short_duration_confirmation';
  static const _keyEnableLongDurationConfirmation =
      'ff_enable_long_duration_confirmation';
  static const _keyLongDurationThresholdMinutes =
      'ff_long_duration_threshold_minutes';

  SharedPreferences? _prefs;
  bool _initialized = false;

  /// Initialize the service. Must be called before accessing flags.
  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // === UI Feature Flags ===

  /// When false (default), skip the review screen after setting end time
  /// and return directly to the home screen with a flash animation.
  /// When true, show the review/complete screen before returning.
  bool get useReviewScreen {
    return _prefs?.getBool(_keyUseReviewScreen) ??
        FeatureFlags.defaultUseReviewScreen;
  }

  set useReviewScreen(bool value) {
    _prefs?.setBool(_keyUseReviewScreen, value);
  }

  /// When true (default), animations are enabled and user preference is respected.
  /// When false, all animations are disabled and the preference toggle is hidden.
  /// This overrides any user preference when set to false.
  bool get useAnimations {
    return _prefs?.getBool(_keyUseAnimations) ??
        FeatureFlags.defaultUseAnimations;
  }

  set useAnimations(bool value) {
    _prefs?.setBool(_keyUseAnimations, value);
  }

  // === Validation Feature Flags ===

  /// REQ-CAL-p00001: Old Entry Modification Justification
  /// When true, editing events older than one calendar day requires
  /// selecting a justification reason before saving.
  bool get requireOldEntryJustification {
    return _prefs?.getBool(_keyRequireOldEntryJustification) ??
        FeatureFlags.defaultRequireOldEntryJustification;
  }

  set requireOldEntryJustification(bool value) {
    _prefs?.setBool(_keyRequireOldEntryJustification, value);
  }

  /// REQ-CAL-p00002: Short Duration Nosebleed Confirmation
  /// When true, prompts user to confirm duration <= 1 minute is correct.
  bool get enableShortDurationConfirmation {
    return _prefs?.getBool(_keyEnableShortDurationConfirmation) ??
        FeatureFlags.defaultEnableShortDurationConfirmation;
  }

  set enableShortDurationConfirmation(bool value) {
    _prefs?.setBool(_keyEnableShortDurationConfirmation, value);
  }

  /// REQ-CAL-p00003: Long Duration Nosebleed Confirmation
  /// When true, prompts user to confirm duration > threshold is correct.
  bool get enableLongDurationConfirmation {
    return _prefs?.getBool(_keyEnableLongDurationConfirmation) ??
        FeatureFlags.defaultEnableLongDurationConfirmation;
  }

  set enableLongDurationConfirmation(bool value) {
    _prefs?.setBool(_keyEnableLongDurationConfirmation, value);
  }

  /// Long duration threshold in minutes
  int get longDurationThresholdMinutes {
    return _prefs?.getInt(_keyLongDurationThresholdMinutes) ??
        FeatureFlags.defaultLongDurationThresholdMinutes;
  }

  set longDurationThresholdMinutes(int value) {
    _prefs?.setInt(_keyLongDurationThresholdMinutes, value);
  }

  /// Reset all feature flags to their defaults
  Future<void> resetToDefaults() async {
    await _prefs?.remove(_keyUseReviewScreen);
    await _prefs?.remove(_keyUseAnimations);
    await _prefs?.remove(_keyRequireOldEntryJustification);
    await _prefs?.remove(_keyEnableShortDurationConfirmation);
    await _prefs?.remove(_keyEnableLongDurationConfirmation);
    await _prefs?.remove(_keyLongDurationThresholdMinutes);
  }
}
