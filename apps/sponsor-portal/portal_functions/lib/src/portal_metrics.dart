// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047: Performance Monitoring — custom application metrics
//
// Portal-server specific OTel metrics.
// Shared HTTP and DB metrics live in otel_common.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' show OTel;

final _meter = OTel.meter('portal');

// IMPLEMENTS: REQ-o00047
final authAttemptsCounter = _meter.createCounter<int>(
  name: 'auth_attempts_total',
  unit: '{attempt}',
  description: 'Total portal auth attempts by result',
);

// IMPLEMENTS: REQ-o00047
final fcmNotificationsCounter = _meter.createCounter<int>(
  name: 'fcm_notifications_total',
  unit: '{notification}',
  description: 'Total FCM notifications sent by type and status',
);

// IMPLEMENTS: REQ-o00047
final questionnaireOpsCounter = _meter.createCounter<int>(
  name: 'questionnaire_operations_total',
  unit: '{operation}',
  description:
      'Total questionnaire operations by type (send/delete/unlock/finalize)',
);

/// Record an auth attempt result.
void authAttempt({required String result, String? reason}) {
  authAttemptsCounter.addWithMap(1, {
    'result': result,
    if (reason != null) 'reason': reason,
  });
}

/// Record an FCM notification send.
void fcmNotificationSent({
  required String messageType,
  required String status,
}) {
  fcmNotificationsCounter.addWithMap(1, {
    'message_type': messageType,
    'status': status,
  });
}

/// Record a questionnaire operation.
void questionnaireOp({required String operation, required String status}) {
  questionnaireOpsCounter.addWithMap(1, {
    'operation': operation,
    'status': status,
  });
}
