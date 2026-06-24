// Implements: REQ-d00115, REQ-d00116, REQ-d00128 — clinical_diary entry type
//   set: three static nosebleed variants plus one survey type per
//   questionnaire definition in questionnaires.json. New questionnaires are
//   added by editing the JSON only.
// Implements: REQ-d00165-A — non-materializing audit entry type for inbound
//   tombstone instructions that could not be applied locally.

import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/services.dart';

/// Path to the questionnaire definitions asset (bundled by trial_data_types).
const _questionnairesAssetPath =
    'packages/trial_data_types/assets/data/questionnaires.json';

/// Load JUST the survey (`<id>_survey`) entry type definitions — one per
/// questionnaire in questionnaires.json.
///
/// The native event-sourcing scope (`bootstrapDiaryScope`) already registers
/// the nosebleed (diary-originated) types internally; the survey types are
/// dynamic (data-driven from the JSON) so they must be passed in via
/// `extraEntryTypes`. The clinical-field renderer is resolved from
/// `questionnaires.json` directly by the questionnaire flow, so the entry-type
/// definition only carries the substrate metadata (id / registeredVersion /
/// name) the event store needs to classify a submitted `<id>_survey` event.
Future<List<EntryTypeDefinition>> loadSurveyEntryTypes({
  Future<String> Function()? jsonLoader,
}) async {
  final loader =
      jsonLoader ?? () => rootBundle.loadString(_questionnairesAssetPath);
  final jsonString = await loader();
  return _parseSurveyEntryTypes(jsonString);
}

/// Parse the raw questionnaires JSON string and return one [EntryTypeDefinition]
/// per questionnaire entry.
List<EntryTypeDefinition> _parseSurveyEntryTypes(String jsonString) {
  final data = jsonDecode(jsonString) as Map<String, dynamic>;
  final questionnaires = data['questionnaires'] as List<dynamic>;
  return questionnaires.map((raw) {
    final q = raw as Map<String, dynamic>;
    final id = q['id'] as String;
    final name = q['name'] as String;
    return EntryTypeDefinition(
      id: '${id}_survey',
      registeredVersion: 1,
      name: name,
    );
  }).toList();
}
