// IMPLEMENTS REQUIREMENTS:
//   REQ-d00171 (Denial Events): typed denial-event factories that the
//   dispatcher uses to construct EventDraft instances for each denial
//   stage. Sanitization (REQ-d00171-C) strips stack traces, file paths,
//   and likely-input-echoes before the message lands in the audit log.

import 'package:event_sourcing/src/actions/permission.dart';
import 'package:event_sourcing/src/event_draft.dart';

const String _aggregateType = 'action_attempt';
const String _entryType = 'action_denial';

/// Strip stack-trace lines, file paths, and absolute path hints from an
/// error message before persisting it to the unified event log. Pure
/// function for testability.
//
// Implements: REQ-d00171-C — sanitization rules.
String sanitizeErrorMessage(Object error) {
  final raw = error.toString();
  // Remove stack-trace lines: `#N <whitespace> ... (file:///... or path)`.
  final noStack = raw.replaceAll(
    RegExp(r'\n?#\d+\s+[^\n]*', multiLine: true),
    '',
  );
  // Strip file URIs.
  final noFileUris = noStack.replaceAll(RegExp(r'file://[^\s)]*'), '<path>');
  // Strip absolute Unix paths preceded by whitespace or start-of-line.
  final noUnixPaths = noFileUris.replaceAll(
    RegExp(r'(?:^|\s)/[A-Za-z0-9_./-]+'),
    ' <path>',
  );
  // Strip Windows-style absolute paths.
  final noWinPaths = noUnixPaths.replaceAll(
    RegExp(r'\b[A-Za-z]:\\[^\s)]*'),
    '<path>',
  );
  return noWinPaths.trim();
}

/// Stage 1 (lookup) failure: actionName not in registry.
EventDraft denialUnknownAction({
  required String invocationId,
  required String requestedName,
  Map<String, dynamic>? actionInvocationMetadata,
}) => EventDraft(
  aggregateId: invocationId,
  aggregateType: _aggregateType,
  entryType: _entryType,
  eventType: 'unknown_action',
  data: <String, dynamic>{'requested_name': requestedName},
  metadata: actionInvocationMetadata,
);

/// Stage 3 (parse) failure: parseInput threw.
EventDraft denialParseDenied({
  required String invocationId,
  required String actionName,
  required Object error,
  Map<String, dynamic>? actionInvocationMetadata,
}) => EventDraft(
  aggregateId: invocationId,
  aggregateType: _aggregateType,
  entryType: _entryType,
  eventType: 'parse_denied',
  data: <String, dynamic>{
    'action_name': actionName,
    'error_class': error.runtimeType.toString(),
    'error_message_sanitized': sanitizeErrorMessage(error),
  },
  metadata: actionInvocationMetadata,
);

/// Stage 5 (validate) failure: validate threw.
EventDraft denialValidationDenied({
  required String invocationId,
  required String actionName,
  required Object error,
  String? fieldPath,
  Map<String, dynamic>? actionInvocationMetadata,
}) => EventDraft(
  aggregateId: invocationId,
  aggregateType: _aggregateType,
  entryType: _entryType,
  eventType: 'validation_denied',
  data: <String, dynamic>{
    'action_name': actionName,
    'error_class': error.runtimeType.toString(),
    'error_message_sanitized': sanitizeErrorMessage(error),
    // ignore: use_null_aware_elements — literal string key; ?key: value would warn "key can't be null"
    if (fieldPath != null) 'field_path': fieldPath,
  },
  metadata: actionInvocationMetadata,
);

/// Stage 6 (authorize) failure: a declared permission was denied.
EventDraft denialAuthorizationDenied({
  required String invocationId,
  required String actionName,
  required Permission permission,
  String? principalActiveRole,
  Map<String, dynamic>? actionInvocationMetadata,
}) => EventDraft(
  aggregateId: invocationId,
  aggregateType: _aggregateType,
  entryType: _entryType,
  eventType: 'authorization_denied',
  data: <String, dynamic>{
    'action_name': actionName,
    'permission_denied': permission.name,
    // ignore: use_null_aware_elements — literal string key; ?key: value would warn "key can't be null"
    if (principalActiveRole != null)
      'principal_active_role': principalActiveRole,
  },
  metadata: actionInvocationMetadata,
);

/// Stage 7 (execute) failure or Stage 8 (persist) failure.
EventDraft denialExecutionFailed({
  required String invocationId,
  required String actionName,
  required Object error,
  Map<String, dynamic>? actionInvocationMetadata,
}) => EventDraft(
  aggregateId: invocationId,
  aggregateType: _aggregateType,
  entryType: _entryType,
  eventType: 'execution_failed',
  data: <String, dynamic>{
    'action_name': actionName,
    'error_class': error.runtimeType.toString(),
    'error_message_sanitized': sanitizeErrorMessage(error),
  },
  metadata: actionInvocationMetadata,
);
