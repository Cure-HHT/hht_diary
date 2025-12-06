// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

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
}
