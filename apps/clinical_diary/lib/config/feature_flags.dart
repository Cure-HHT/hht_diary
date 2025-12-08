// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-CAL-p00001: Old Entry Modification Justification
//   REQ-CAL-p00002: Short Duration Nosebleed Confirmation
//   REQ-CAL-p00003: Long Duration Nosebleed Confirmation

import 'package:shared_preferences/shared_preferences.dart';

/// Feature flags for controlling app behavior.
/// Compile-time defaults can be overridden at runtime for dev/qa testing.
class FeatureFlags {
  // === Compile-time default values ===

  /// When false (default), skip the review screen after setting end time
  /// and return directly to the home screen with a flash animation.
  /// When true, show the review/complete screen before returning.
  static const bool useReviewScreen = false;

  /// When true (default), animations are enabled and user preference is respected.
  /// When false, all animations are disabled and the preference toggle is hidden.
  /// This overrides any user preference when set to false.
  static const bool useAnimations = true;

  // === Terremoto Sponsor Validation Features (REQ-CAL) ===
  // These are sponsor-controlled settings, not user preferences.
  // Runtime overrides available in dev/qa builds only.

  /// REQ-CAL-p00001: Old Entry Modification Justification
  /// When true, editing events older than one calendar day requires
  /// selecting a justification reason before saving.
  static const bool defaultRequireOldEntryJustification = true;

  /// REQ-CAL-p00002: Short Duration Nosebleed Confirmation
  /// When true, prompts user to confirm duration <= 1 minute is correct.
  static const bool defaultEnableShortDurationConfirmation = true;

  /// REQ-CAL-p00003: Long Duration Nosebleed Confirmation
  /// When true, prompts user to confirm duration > threshold is correct.
  static const bool defaultEnableLongDurationConfirmation = true;

  /// Default threshold for long duration confirmation (in minutes).
  static const int defaultLongDurationThresholdMinutes = 60;

  /// Minimum configurable long duration threshold (1 hour)
  static const int minLongDurationThresholdHours = 1;

  /// Maximum configurable long duration threshold (9 hours)
  static const int maxLongDurationThresholdHours = 9;
}

/// Runtime feature flag service for dev/qa testing.
/// Allows overriding compile-time defaults for testing purposes.
class FeatureFlagService {
  FeatureFlagService._();

  static final FeatureFlagService _instance = FeatureFlagService._();
  static FeatureFlagService get instance => _instance;

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

  /// REQ-CAL-p00001: Old Entry Modification Justification
  bool get requireOldEntryJustification {
    return _prefs?.getBool(_keyRequireOldEntryJustification) ??
        FeatureFlags.defaultRequireOldEntryJustification;
  }

  set requireOldEntryJustification(bool value) {
    _prefs?.setBool(_keyRequireOldEntryJustification, value);
  }

  /// REQ-CAL-p00002: Short Duration Nosebleed Confirmation
  bool get enableShortDurationConfirmation {
    return _prefs?.getBool(_keyEnableShortDurationConfirmation) ??
        FeatureFlags.defaultEnableShortDurationConfirmation;
  }

  set enableShortDurationConfirmation(bool value) {
    _prefs?.setBool(_keyEnableShortDurationConfirmation, value);
  }

  /// REQ-CAL-p00003: Long Duration Nosebleed Confirmation
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

  /// Reset all feature flags to their compile-time defaults
  Future<void> resetToDefaults() async {
    await _prefs?.remove(_keyRequireOldEntryJustification);
    await _prefs?.remove(_keyEnableShortDurationConfirmation);
    await _prefs?.remove(_keyEnableLongDurationConfirmation);
    await _prefs?.remove(_keyLongDurationThresholdMinutes);
  }
}
