// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047: Performance Monitoring — custom application metrics
//   REQ-p00004: Immutable Audit Trail via Event Sourcing
//
// Diary-server specific OTel metrics.
// Shared HTTP and DB metrics live in otel_common.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' show OTel;

final _meter = OTel.meter('diary');

// IMPLEMENTS: REQ-o00047
final activeSessionsGauge = _meter.createGauge<int>(
  name: 'active_sessions_count',
  unit: '{session}',
  description: 'Current active sessions (concurrent requests)',
);

// IMPLEMENTS: REQ-o00047
final auditEventsCounter = _meter.createCounter<int>(
  name: 'audit_events_written_total',
  unit: '{event}',
  description: 'Total audit events written to record_audit (FDA compliance)',
);

int _activeSessions = 0;

/// Increment active session count. Call at request start.
void sessionStarted() {
  _activeSessions++;
  activeSessionsGauge.record(_activeSessions);
}

/// Decrement active session count. Call at request end.
void sessionEnded() {
  _activeSessions--;
  activeSessionsGauge.record(_activeSessions);
}

/// Record an audit event write. Call after successful INSERT to record_audit.
void auditEventWritten({String? operation}) {
  if (operation != null) {
    auditEventsCounter.addWithMap(1, {'operation': operation});
  } else {
    auditEventsCounter.add(1);
  }
}
