// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content

/// A single option in a response scale (e.g., 0="No problem", 4="As bad as possible").
///
/// Each question category defines its own response scale with
/// values from 0-4 per REQ-p01067-B / REQ-p01068-B.
class ResponseScaleOption {
  const ResponseScaleOption({required this.value, required this.label});

  factory ResponseScaleOption.fromJson(Map<String, dynamic> json) {
    return ResponseScaleOption(
      value: json['value'] as int,
      label: json['label'] as String,
    );
  }

  /// Numeric value (0-4) for scoring
  final int value;

  /// Human-readable label displayed to the patient
  final String label;
}
