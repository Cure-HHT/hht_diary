// IMPLEMENTS REQUIREMENTS:
//   REQ-d00167: FCM Dispatch via cure-hht-admin Project
//   REQ-d00168: PHI-Safe FCM Payload
//   REQ-d00169: Mobile Notifications Polling
//   REQ-d00170: Notification Behaviour
//
// Public API barrel for the comms package. Consumers import
// `package:comms/comms.dart` and depend only on the symbols re-exported
// here — internals under `lib/src/` are not part of the API contract.

export 'src/channel.dart';
export 'src/compliance/payload_guard.dart';
export 'src/dispatch_result.dart';
