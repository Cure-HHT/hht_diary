// UI-only intensity enum used by the recording, picker, and list-item widgets.
// The enum maps the `intensity` answer string stored in DiaryEntry data to a
// localized display label and a static asset path.  It is NOT part of any
// data shape; the canonical value is the string under
// `entry.currentAnswers['intensity']`.
//
// Implements: REQ-p01069-A — intuitive intensity rendering for recording UI.

/// Intensity levels for nosebleed events (UI-only).
enum NosebleedIntensity {
  spotting,
  dripping,
  drippingQuickly,
  steadyStream,
  pouring,
  gushing;

  String get displayName {
    switch (this) {
      case NosebleedIntensity.spotting:
        return 'Spotting';
      case NosebleedIntensity.dripping:
        return 'Dripping';
      case NosebleedIntensity.drippingQuickly:
        return 'Dripping quickly';
      case NosebleedIntensity.steadyStream:
        return 'Steady stream';
      case NosebleedIntensity.pouring:
        return 'Pouring';
      case NosebleedIntensity.gushing:
        return 'Gushing';
    }
  }

  /// Parse an intensity from the stored `entry.currentAnswers['intensity']`
  /// string. Accepts both enum-name form (`steadyStream`) and human-readable
  /// form (`Steady stream`). Returns `null` for `null`, empty, or unknown
  /// strings.
  static NosebleedIntensity? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    return NosebleedIntensity.values.cast<NosebleedIntensity?>().firstWhere(
      (e) => e?.displayName == value || e?.name == value,
      orElse: () => null,
    );
  }
}
