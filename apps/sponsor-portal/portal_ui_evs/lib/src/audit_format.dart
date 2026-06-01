// Implements: DIARY-GUI-audit-log-common — humanizes the Action column, labels the User
//   column, and summarizes the Details column for audit rows.

// Overrides only where title-casing the entry-type id reads poorly (e.g. acronyms).
const Map<String, String> _entryTypeLabels = <String, String>{
  'site_synced_from_edc': 'Site Synced From EDC',
  'participant_synced_from_edc': 'Participant Synced From EDC',
};

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

String detailsSummary(Map<String, Object?> row) {
  final t = (row['aggregate_type'] as String?) ?? '?';
  final id = (row['aggregate_id'] as String?) ?? '?';
  final reason = row['change_reason'] as String?;
  final base = '$t $id';
  return (reason == null || reason.isEmpty) ? base : '$base — $reason';
}
