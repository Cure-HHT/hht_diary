/// A single option in a response scale (e.g., 0="No problem", 4="As bad as possible").
///
/// Each question category defines its own response scale with values from 0-4.
// Implements: DIARY-PRD-questionnaire-nose-hht/A — NOSE HHT response-scale content model
// Implements: DIARY-PRD-questionnaire-hht-qol/A — HHT-QoL response-scale content model
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

  /// Human-readable label displayed to the participant
  final String label;
}
