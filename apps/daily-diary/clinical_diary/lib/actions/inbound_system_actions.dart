// Implements: DIARY-DEV-inbound-event-on-receipt/B — on receipt of an FCM or
//   poll message the app emits a registered `fcm_message_received` event.
// Implements: DIARY-DEV-action-write-path/A — the write flows through the core
//   ActionDispatcher rather than a direct append.
//
// Diary per-app system-event Actions (diary_actions). Unlike the record-entry
// actions these are device/system-initiated (they fire before a participant is
// linked, e.g. the first token mint), so they do NOT require a UserPrincipal —
// they record the occurrence under whatever principal is in context.
//
// `RecordFcmMessageReceived` makes inbound delivery a first-class, auditable
// event and ECHOES the portal-minted flowToken (surface P5) so the portal can
// stitch `assigned -> delivered -> received`. `RegisterFcmToken` records the
// device-routing token mint/refresh (`fcm_token_registered`). Both aggregate per
// device-event id (a fresh occurrence each time), supplied by the caller.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';

/// Parsed input for [RecordFcmMessageReceivedAction]: the receipt payload plus
/// the aggregate id for this occurrence (a fresh per-receipt id).
class FcmMessageReceivedInput {
  const FcmMessageReceivedInput({
    required this.aggregateId,
    required this.payload,
  });

  final String aggregateId;
  final FcmMessageReceivedPayload payload;
}

/// Records an inbound FCM/poll message receipt as a finalized
/// `fcm_message_received` event. Returns the occurrence aggregate id.
class RecordFcmMessageReceivedAction
    extends Action<FcmMessageReceivedInput, String> {
  const RecordFcmMessageReceivedAction();

  @override
  String get name => 'record_fcm_message_received';

  @override
  String get description =>
      'App records receipt of an inbound FCM/poll message (audit + flowToken echo).';

  @override
  Set<Permission> get permissions => const <Permission>{};

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  FcmMessageReceivedInput parseInput(Map<String, Object?> raw) {
    final aggregateId = raw['aggregateId'];
    if (aggregateId is! String || aggregateId.isEmpty) {
      throw const FormatException('aggregateId is required');
    }
    final FcmMessageReceivedPayload payload;
    try {
      payload = FcmMessageReceivedPayload.fromJson(raw);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('invalid fcm_message_received payload: $e');
    }
    return FcmMessageReceivedInput(aggregateId: aggregateId, payload: payload);
  }

  @override
  void validate(FcmMessageReceivedInput input) {
    if (DateTime.tryParse(input.payload.receivedAt) == null) {
      throw ArgumentError.value(
        input.payload.receivedAt,
        'receivedAt',
        'must be an ISO 8601 timestamp',
      );
    }
  }

  @override
  Future<ExecutionResult<String>> execute(
    FcmMessageReceivedInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<String>(
      result: input.aggregateId,
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'InboundMessage',
          aggregateId: input.aggregateId,
          entryType: 'fcm_message_received',
          eventType: 'finalized',
          data: input.payload.toJson(),
        ),
      ],
    );
  }
}

/// Parsed input for [RegisterFcmTokenAction]: the token payload plus the
/// aggregate id for this registration occurrence.
class FcmTokenRegisteredInput {
  const FcmTokenRegisteredInput({
    required this.aggregateId,
    required this.payload,
  });

  final String aggregateId;
  final FcmTokenRegisteredPayload payload;
}

/// Records an FCM token mint/refresh as a finalized `fcm_token_registered`
/// event. Returns the occurrence aggregate id.
// Implements: DIARY-DEV-inbound-event-on-receipt/A — the FCM receive interface
//   is retained; this records the device-routing token that backs it.
class RegisterFcmTokenAction extends Action<FcmTokenRegisteredInput, String> {
  const RegisterFcmTokenAction();

  @override
  String get name => 'register_fcm_token';

  @override
  String get description =>
      'App records an FCM registration token mint/refresh (device routing).';

  @override
  Set<Permission> get permissions => const <Permission>{};

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  FcmTokenRegisteredInput parseInput(Map<String, Object?> raw) {
    final aggregateId = raw['aggregateId'];
    if (aggregateId is! String || aggregateId.isEmpty) {
      throw const FormatException('aggregateId is required');
    }
    final FcmTokenRegisteredPayload payload;
    try {
      payload = FcmTokenRegisteredPayload.fromJson(raw);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('invalid fcm_token_registered payload: $e');
    }
    return FcmTokenRegisteredInput(aggregateId: aggregateId, payload: payload);
  }

  @override
  void validate(FcmTokenRegisteredInput input) {
    if (input.payload.token.isEmpty) {
      throw ArgumentError.value(input.payload.token, 'token', 'must be set');
    }
    if (DateTime.tryParse(input.payload.registeredAt) == null) {
      throw ArgumentError.value(
        input.payload.registeredAt,
        'registeredAt',
        'must be an ISO 8601 timestamp',
      );
    }
  }

  @override
  Future<ExecutionResult<String>> execute(
    FcmTokenRegisteredInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<String>(
      result: input.aggregateId,
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'FcmToken',
          aggregateId: input.aggregateId,
          entryType: 'fcm_token_registered',
          eventType: 'finalized',
          data: input.payload.toJson(),
        ),
      ],
    );
  }
}
