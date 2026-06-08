// Single-source list of the questionnaire Types enabled for this portal.
//
// The concrete clinical type ids (`nose_hht`, `qol`) and their display names
// live here in the sponsor-facing consumer UI — this is the application, not
// the neutral event_sourcing library, so it is the right home for them.
//
// Enabled-types are a const for now. Config-driven enablement (per-sponsor
// portal_settings selecting which types are active) is a forward seam: when it
// lands, [kEnabledQuestionnaireTypes] becomes a reactive read of that setting
// rather than a compile-time constant, and the Manage Questionnaires modal
// (which renders one card per enabled type) picks the change up unchanged.
//
// Implements: DIARY-BASE-questionnaire-manage-modal/B — one card per enabled
//   Questionnaire Type for the participant.

import 'package:meta/meta.dart';

/// An enabled questionnaire Type: its stable [id] (the value stored on a
/// `questionnaire_instance` row's `type` column) and its human-readable
/// [displayName] (the card header).
@immutable
class QuestionnaireType {
  const QuestionnaireType({required this.id, required this.displayName});

  /// Stable type id, e.g. `'nose_hht'`. Matches `questionnaire_instance.type`.
  final String id;

  /// Display name shown on the card header, e.g. `'NOSE HHT'`.
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is QuestionnaireType &&
      other.id == id &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, displayName);
}

/// The questionnaire Types enabled for this portal, in display order.
///
/// Const for now (see file header); config-driven enablement is a forward seam.
const List<QuestionnaireType> kEnabledQuestionnaireTypes = <QuestionnaireType>[
  QuestionnaireType(id: 'nose_hht', displayName: 'NOSE HHT'),
  QuestionnaireType(id: 'qol', displayName: 'HHT-QoL'),
];
