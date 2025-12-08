// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-CAL-p00001: Old Entry Modification Justification
//   REQ-CAL-p00002: Short Duration Nosebleed Confirmation
//   REQ-CAL-p00003: Long Duration Nosebleed Confirmation

/// Feature flags for controlling app behavior.
/// These are compile-time constants that can be changed during development.
class FeatureFlags {
  /// When false (default), skip the review screen after setting end time
  /// and return directly to the home screen with a flash animation.
  /// When true, show the review/complete screen before returning.
  static const bool useReviewScreen = false;

  /// When true (default), animations are enabled and user preference is respected.
  /// When false, all animations are disabled and the preference toggle is hidden.
  /// This overrides any user preference when set to false.
  static const bool useAnimations = true;

  // === Terremoto Sponsor Validation Features (REQ-CAL) ===

  /// REQ-CAL-p00001: Old Entry Modification Justification
  /// When true, editing events older than one calendar day requires
  /// selecting a justification reason before saving.
  /// Enabled: Always during Sponsor Trial
  static const bool requireOldEntryJustification = true;

  /// REQ-CAL-p00002: Short Duration Nosebleed Confirmation
  /// When true, prompts user to confirm duration <= 1 minute is correct.
  /// Can be disabled in User Preferences unless forced by Active Trial Policy.
  static const bool enableShortDurationConfirmation = true;

  /// REQ-CAL-p00003: Long Duration Nosebleed Confirmation
  /// When true, prompts user to confirm duration > threshold is correct.
  /// Threshold configurable 1-9 hours. Can be disabled in User Preferences
  /// unless forced by Active Trial Policy.
  static const bool enableLongDurationConfirmation = true;

  /// Default threshold for long duration confirmation (in minutes).
  /// User can configure between 60 (1 hour) and 540 (9 hours) in preferences.
  static const int defaultLongDurationThresholdMinutes = 60;

  /// Minimum configurable long duration threshold (1 hour)
  static const int minLongDurationThresholdHours = 1;

  /// Maximum configurable long duration threshold (9 hours)
  static const int maxLongDurationThresholdHours = 9;
}
