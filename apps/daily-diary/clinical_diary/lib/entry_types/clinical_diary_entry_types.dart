// Implements: REQ-d00115, REQ-d00116, REQ-d00128 — clinical_diary entry type
//   set: three static nosebleed variants plus one survey type per
//   questionnaire definition in questionnaires.json. New questionnaires are
//   added by editing the JSON only.
// Implements: REQ-d00158-A — non-materializing audit entry type for inbound
//   tombstone instructions that could not be applied locally.

import 'dart:convert';

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter/services.dart';

/// Path to the questionnaire definitions asset (bundled by trial_data_types).
const _questionnairesAssetPath =
    'packages/trial_data_types/assets/data/questionnaires.json';

/// Audit-only entry type recorded when `portalInboundPoll` receives a
/// tombstone instruction it cannot apply locally (e.g. the server tombstones
/// an entry of a type this build does not yet know about, or storage refuses
/// the write). Materialize is `false` so the failure does not pollute the
/// diary view; the row exists only to stamp an immutable event-log fact that
/// will ship to the diary server through the standard FIFO drain.
///
/// Implements: REQ-d00158-A — see dev-event-sourcing-mobile.md.
const String kInboundTombstoneRecordFailedEntryType =
    'inbound_tombstone_record_failed';

const EntryTypeDefinition _inboundTombstoneRecordFailedType =
    EntryTypeDefinition(
      id: kInboundTombstoneRecordFailedEntryType,
      registeredVersion: 1,
      name: 'Inbound Tombstone Record Failed',
      widgetId: '_audit',
      widgetConfig: <String, Object?>{},
      materialize: false,
    );

/// The three static nosebleed entry types.
///
/// These are fixed regardless of the questionnaire JSON content.
const List<EntryTypeDefinition> _nosebleedTypes = [
  EntryTypeDefinition(
    id: 'epistaxis_event',
    registeredVersion: 1,
    name: 'Nosebleed',
    widgetId: 'epistaxis_form_v1',
    widgetConfig: <String, Object?>{},
    effectiveDatePath: 'startTime',
  ),
  EntryTypeDefinition(
    id: 'no_epistaxis_event',
    registeredVersion: 1,
    name: 'No Nosebleeds',
    widgetId: 'epistaxis_form_v1',
    widgetConfig: <String, Object?>{'variant': 'no_epistaxis'},
    effectiveDatePath: 'date',
  ),
  EntryTypeDefinition(
    id: 'unknown_day_event',
    registeredVersion: 1,
    name: 'Unknown Day',
    widgetId: 'epistaxis_form_v1',
    widgetConfig: <String, Object?>{'variant': 'unknown_day'},
    effectiveDatePath: 'date',
  ),
];

/// Load all clinical diary entry type definitions.
///
/// Returns the union of:
///   - Three static nosebleed types (epistaxis_event, no_epistaxis_event,
///     unknown_day_event).
///   - One survey entry type per questionnaire definition in
///     questionnaires.json.  Adding a new questionnaire to the JSON
///     automatically yields a new entry type with no Dart change.
///   - The audit entry type [kInboundTombstoneRecordFailedEntryType]
///     (REQ-d00158-A).
///
/// The optional `jsonLoader` parameter overrides the JSON source; it defaults
/// to loading from the asset bundle via `rootBundle.loadString`.  Inject a
/// different loader in tests to avoid depending on the asset bundle.
Future<List<EntryTypeDefinition>> loadClinicalDiaryEntryTypes({
  Future<String> Function()? jsonLoader,
}) async {
  final loader =
      jsonLoader ?? () => rootBundle.loadString(_questionnairesAssetPath);
  final jsonString = await loader();
  final surveyTypes = _parseSurveyEntryTypes(jsonString);
  return [
    ..._nosebleedTypes,
    ...surveyTypes,
    _inboundTombstoneRecordFailedType,
  ];
}

/// Parse the raw questionnaires JSON string and return one [EntryTypeDefinition]
/// per questionnaire entry, using the full raw JSON map as `widgetConfig`.
List<EntryTypeDefinition> _parseSurveyEntryTypes(String jsonString) {
  final data = jsonDecode(jsonString) as Map<String, dynamic>;
  final questionnaires = data['questionnaires'] as List<dynamic>;
  return questionnaires.map((raw) {
    final q = raw as Map<String, dynamic>;
    final id = q['id'] as String;
    final name = q['name'] as String;
    // Pass the entire questionnaire definition as widgetConfig so the
    // survey_renderer_v1 widget has full access to categories, questions, etc.
    final widgetConfig = Map<String, Object?>.from(q);
    return EntryTypeDefinition(
      id: '${id}_survey',
      registeredVersion: 1,
      name: name,
      widgetId: 'survey_renderer_v1',
      widgetConfig: widgetConfig,
      // effectiveDatePath intentionally omitted: falls back to client_timestamp.
    );
  }).toList();
}
