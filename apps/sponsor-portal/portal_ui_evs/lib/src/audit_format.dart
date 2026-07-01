import 'dart:convert';

// Implements: DIARY-GUI-audit-log-common/A — parses the /audit response body into audit
//   rows, tolerating (skipping) any non-object element so a malformed row can't crash the
//   list (the Timestamp/Action/User/Details table is built from these rows).
List<Map<String, Object?>> parseAuditRows(String responseBody) =>
    _rowsFrom(jsonDecode(responseBody));

List<Map<String, Object?>> _rowsFrom(Object? decoded) {
  if (decoded is! Map) return const <Map<String, Object?>>[];
  final rows = decoded['rows'];
  if (rows is! List) return const <Map<String, Object?>>[];
  return rows
      .whereType<Map>()
      .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
      .toList();
}

/// One page of the server-paged /audit response: the rows in hand plus the
/// server's true total (full log size, or match-set size while a `q` filter
/// is active).
typedef AuditPage = ({List<Map<String, Object?>> rows, int total});

// Implements: DIARY-GUI-audit-log-common/A — parses one page of the /audit
//   response. `total` falls back to the row count when the server omits it,
//   so an older server still renders (with page-local pagination).
AuditPage parseAuditPage(String responseBody) {
  final decoded = jsonDecode(responseBody);
  final rows = _rowsFrom(decoded);
  final total = decoded is Map ? decoded['total'] : null;
  return (rows: rows, total: total is int ? total : rows.length);
}

// Overrides only where title-casing the entry-type id reads poorly (e.g. acronyms).
const Map<String, String> _entryTypeLabels = <String, String>{
  'site_synced_from_edc': 'Site Synced From EDC',
  'participant_synced_from_edc': 'Participant Synced From EDC',
};

// Implements: DIARY-GUI-audit-log-common/F — the Action-column name. Prefers the
//   server-resolved Action-Inventory name (`action_name`, e.g. "Reactivate User
//   Account"); falls back to humanizing the raw entry-type id for any event the
//   server didn't map (e.g. site/participant events in the Sites drill-in).
String auditActionName(Map<String, Object?> row) {
  final name = (row['action_name'] as String?)?.trim();
  if (name != null && name.isNotEmpty) return name;
  return humanizeEntryType((row['entry_type'] as String?) ?? '');
}

// Implements: DIARY-GUI-audit-log-common/A — the User-column value: the actor's
//   display name when the server resolved one, else the email; empty for
//   non-user (automation/anonymous) initiators so the row renders "Automation".
String auditActorName(Map<String, Object?>? initiator) {
  if (initiator == null) return '';
  if (initiator['kind'] != 'user') return '';
  final name = (initiator['name'] as String?)?.trim();
  if (name != null && name.isNotEmpty) return name;
  return (initiator['label'] as String?) ?? '';
}

// Implements: DIARY-GUI-audit-log-study-coordinator/A — the Participant ID cell
//   value: the server-stamped `participant_id` for participant/questionnaire
//   rows; empty string when the row has no participant association.
String auditParticipantId(Map<String, Object?> row) =>
    (row['participant_id'] as String?)?.trim() ?? '';

// Implements: DIARY-GUI-audit-log-common/A — the actor's email (the initiator
//   `label`), shown under the name in the User column. Empty for non-user
//   (automation/anonymous) initiators.
String auditActorEmail(Map<String, Object?>? initiator) {
  if (initiator == null) return '';
  if (initiator['kind'] != 'user') return '';
  return (initiator['label'] as String?)?.trim() ?? '';
}

// Implements: DIARY-GUI-audit-log-common/D — the Activity-column label: the
//   Action-Inventory name plus the affected account it was performed on, by
//   email (the portal_user aggregate id). E.g. "Reactivate User Account —
//   squeeb+sc@gmail.com". Falls back to just the action name when the event
//   has no portal_user target.
String auditActivityLabel(Map<String, Object?> row) {
  final action = auditActionName(row);
  if (row['aggregate_type'] == 'portal_user') {
    final email = (row['aggregate_id'] as String?)?.trim();
    if (email != null && email.isNotEmpty) return '$action — $email';
  }
  return action;
}

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

// Implements: DIARY-GUI-audit-log-common/C+D — the Details column's human-readable
//   summary: the affected record (by display name when the server resolved one,
//   else the raw id) plus any free-text reason the Action carried.
String detailsSummary(Map<String, Object?> row) {
  // Affected account by name when known (target_name); otherwise the aggregate
  // id (an email for portal_user, the site/participant id otherwise).
  final target = (row['target_name'] as String?)?.trim();
  final id = (row['aggregate_id'] as String?) ?? '?';
  final subject = (target != null && target.isNotEmpty) ? target : id;
  final reason = (row['change_reason'] as String?)?.trim();
  if (reason == null || reason.isEmpty) return subject;
  return '$subject — Reason: "$reason"';
}
