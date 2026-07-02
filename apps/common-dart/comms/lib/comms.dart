// Public API barrel for the comms package. Consumers import
// `package:comms/comms.dart` and depend only on the symbols re-exported
// here — internals under `lib/src/` are not part of the API contract.

export 'src/channel.dart';
export 'src/channels/fcm/adc_client.dart';
export 'src/channels/fcm/fcm_channel.dart';
export 'src/channels/fcm/fcm_message.dart';
export 'src/compliance/payload_guard.dart';
export 'src/dispatch_result.dart';
export 'src/notifications/client/envelope_fetcher.dart';
export 'src/notifications/envelope.dart';
export 'src/notifications/envelope_status.dart';
export 'src/notifications/notification_type.dart';
export 'src/notifications/outbox_writer.dart';
export 'src/notifications/repository.dart';
export 'src/notifications/server/envelope_fetch_handler.dart';
export 'src/notifications/server/envelope_since_handler.dart';
export 'src/push_channel.dart';
