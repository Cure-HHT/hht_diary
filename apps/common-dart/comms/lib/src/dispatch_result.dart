// IMPLEMENTS REQUIREMENTS:
//   REQ-d00193: FCM Dispatch via cure-hht-admin Project (assertions C, D, H)
//
// Channel-agnostic dispatch outcome. Three terminal states the
// `OutboxWriter` reacts to:
//   - success(messageId): channel accepted the message, persisted id
//     returned to the caller
//   - failure(error): retryable or unknown error
//   - unregisteredToken(): FCM-only — token is permanently invalid
//     (HTTP 404 / UNREGISTERED). Caller deactivates the row in
//     `patient_fcm_tokens` so subsequent sends do not re-route to a
//     different patient on the same device.

class DispatchResult {
  /// Channel accepted the message.
  const DispatchResult.success(String this.messageId)
    : success = true,
      error = null,
      unregistered = false;

  /// Channel rejected the message — retryable or unknown.
  const DispatchResult.failure(String this.error)
    : success = false,
      messageId = null,
      unregistered = false;

  /// FCM-specific terminal: token is permanently invalid. The caller
  /// MUST treat the row in `patient_fcm_tokens` as dead.
  const DispatchResult.unregisteredToken()
    : success = false,
      messageId = null,
      error = 'UNREGISTERED',
      unregistered = true;

  final bool success;
  final String? messageId;
  final String? error;

  /// True only for the FCM 404 / UNREGISTERED terminal. Distinct from
  /// `success == false && error == 'UNREGISTERED'` so a future channel
  /// using that error string can't accidentally trigger token cleanup.
  final bool unregistered;

  /// Tag value for the `comms.<channel>.dispatch` metric — exactly one
  /// of `'success'`, `'failed'`, `'unregistered'`. See REQ-d00193-H.
  String get outcome {
    if (unregistered) return 'unregistered';
    if (success) return 'success';
    return 'failed';
  }
}
