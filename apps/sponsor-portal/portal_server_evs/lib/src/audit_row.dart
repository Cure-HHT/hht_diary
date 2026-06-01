// Implements: DIARY-DEV-audit-log-read/A — maps a StoredEvent to an audit-trail row
//   surfacing who (initiator), what (entry type), when (timestamp), details (payload + change reason).
// Implements: DIARY-DEV-audit-log-read/B — auditAccessAllowed gates on the audit-view permission.
import 'package:event_sourcing/event_sourcing.dart';

/// Permission name that gates read access to the audit trail.
const String auditViewPermission = 'portal.audit.view';

/// Whether the given permission set grants audit-trail read access.
bool auditAccessAllowed(Iterable<String> permissionNames) =>
    permissionNames.contains(auditViewPermission);

/// Maps a [StoredEvent] to a JSON-serialisable audit-trail row capturing
/// who (initiator), what (entry/event/aggregate), when (timestamp), and the
/// details (payload + change reason).
Map<String, Object?> auditRowJson(StoredEvent e) => <String, Object?>{
      'event_id': e.eventId,
      'sequence': e.sequenceNumber,
      'timestamp': e.clientTimestamp.toUtc().toIso8601String(),
      'entry_type': e.entryType,
      'event_type': e.eventType,
      'aggregate_type': e.aggregateType,
      'aggregate_id': e.aggregateId,
      'initiator': _initiatorJson(e.initiator),
      'flow_token': e.flowToken,
      'change_reason': e.metadata['change_reason'],
      'data': e.data,
    };

Map<String, Object?> _initiatorJson(Initiator i) => switch (i) {
      UserInitiator(:final userId) => {'kind': 'user', 'label': userId},
      AutomationInitiator(:final service) => {
          'kind': 'automation',
          'label': service,
        },
      AnonymousInitiator() => {'kind': 'anonymous', 'label': 'anon'},
    };
