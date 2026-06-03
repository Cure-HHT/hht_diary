import 'dart:convert';

// Implements: DIARY-GUI-audit-log-common/A — parses the /audit response body into audit
//   rows, tolerating (skipping) any non-object element so a malformed row can't crash the
//   list (the Timestamp/Action/User/Details table is built from these rows).
List<Map<String, Object?>> parseAuditRows(String responseBody) {
  final decoded = jsonDecode(responseBody);
  if (decoded is! Map) return const <Map<String, Object?>>[];
  final rows = decoded['rows'];
  if (rows is! List) return const <Map<String, Object?>>[];
  return rows
      .whereType<Map>()
      .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
      .toList();
}

// Overrides only where title-casing the entry-type id reads poorly (e.g. acronyms).
const Map<String, String> _entryTypeLabels = <String, String>{
  'site_synced_from_edc': 'Site Synced From EDC',
  'participant_synced_from_edc': 'Participant Synced From EDC',
};

// Implements: DIARY-GUI-audit-log-common/F — renders the Action name shown in the Action
//   column (human-readable form of the entry-type id).
String humanizeEntryType(String entryType) {
  if (entryType.isEmpty) return '(unknown)';
  final override = _entryTypeLabels[entryType];
  if (override != null) return override;
  return entryType
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

// Implements: DIARY-GUI-audit-log-common/A — produces the User column value identifying
//   who initiated the entry.
String initiatorLabel(Map<String, Object?>? initiator) {
  if (initiator == null) return '(unknown)';
  final label = (initiator['label'] as String?) ?? '';
  return switch (initiator['kind']) {
    'user' => 'user:$label',
    'automation' => 'auto:$label',
    'anonymous' => 'anon',
    _ => '(unknown)',
  };
}

// Implements: DIARY-GUI-audit-log-common/D — produces the Details column's human-readable
//   summary of the Action (affected record plus any change reason / free-text parameter).
String detailsSummary(Map<String, Object?> row) {
  final t = (row['aggregate_type'] as String?) ?? '?';
  final id = (row['aggregate_id'] as String?) ?? '?';
  final reason = row['change_reason'] as String?;
  final base = '$t $id';
  return (reason == null || reason.isEmpty) ? base : '$base — $reason';
}
