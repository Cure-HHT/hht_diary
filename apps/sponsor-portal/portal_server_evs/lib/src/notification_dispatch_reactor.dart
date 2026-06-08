// Implements: DIARY-DEV-outgoing-intent-correlation/B — delivery rides the existing
//   push path (FcmChannel); the intent event is not the delivery mechanism.
// Implements: DIARY-DEV-outgoing-intent-correlation/C — the flowToken minted on the
//   intent event is carried in the FCM data payload across the non-event-sourced hop.
import 'dart:async';
import 'dart:io';

import 'package:comms/comms.dart';
// event_sourcing also exports a `DispatchResult`; hide it so the explicit
// `DispatchResult` type below resolves unambiguously to comms' FCM result.
import 'package:event_sourcing/event_sourcing.dart' hide DispatchResult;

/// Post-commit reactor that turns already-durable portal intent events
/// (questionnaire assignment + participant lifecycle) into FCM pushes. It looks
/// up the recipient's active routing token in the `participant_fcm_tokens`
/// projection, sends via [channel] directly (NOT via an outbox/notifications
/// table), and records the outcome back into the event log
/// (`notification_sent` / `notification_dispatch_failed`), emitting
/// `fcm_token_deactivated` on a dead token.
class NotificationDispatchReactor {
  NotificationDispatchReactor({
    required this.eventStore,
    required this.backend,
    required this.channel,
  });

  final EventStore eventStore;
  final StorageBackend backend;
  final Channel<FcmMessage> channel;

  /// Intent entry types this reactor reacts to, mapped to their push shape.
  /// `questionnaire_assigned` is user-visible (lock-screen alert); the
  /// participant-lifecycle transitions are silent data pushes that wake the app
  /// to refresh its enrollment/sync state.
  static const Map<String, _Intent> _intents = <String, _Intent>{
    'questionnaire_assigned':
        _Intent(userVisible: true, title: 'New questionnaire'),
    'participant_disconnected': _Intent(userVisible: false),
    'participant_marked_not_participating': _Intent(userVisible: false),
    'participant_reconnected': _Intent(userVisible: false),
    'participant_reactivated': _Intent(userVisible: false),
  };

  StreamSubscription<Update<StoredEvent>>? _sub;

  void start() {
    _sub = eventStore
        .subscribe<StoredEvent>(
      SubscriptionFilter(eventTypes: _intents.keys.toSet()),
      const Events(),
    )
        .listen((update) {
      if (update is Delta<StoredEvent>) {
        // Fire-and-forget with a catchError backstop: a reactor failure must
        // NEVER surface as an unhandled async exception that crashes the server.
        unawaited(
            handleIntent(update.value).catchError((Object e, StackTrace st) {
          stderr.writeln('NotificationDispatchReactor.handleIntent failed '
              '(continuing): $e\n$st');
        }));
      }
    }, onError: (Object e, StackTrace st) {
      stderr.writeln('NotificationDispatchReactor subscription error '
          '(continuing): $e\n$st');
    });
  }

  Future<void> handleIntent(StoredEvent event) async {
    final intent = _intents[event.entryType];
    if (intent == null) return;
    final participantId = _participantOf(event);
    if (participantId == null) return;
    final tokens = await _activeTokensFor(participantId);
    if (tokens.isEmpty) {
      await _recordFailure(event, participantId,
          fcmTokenAggregateId: '', reason: 'no_active_token');
      return;
    }
    for (final t in tokens) {
      final message = FcmMessage(
        fcmToken: t.token,
        userVisible: intent.userVisible,
        notificationTitle: intent.userVisible ? intent.title : null,
        data: <String, String>{
          'type': event.entryType,
          if (event.flowToken != null) 'flowToken': event.flowToken!,
        },
      );
      // dispatch() can THROW (transport faults: ADC/credential resolution,
      // a TimeoutException from the send timeout, socket errors) rather than
      // returning a DispatchResult terminal. Catch it so the outcome is still
      // recorded as a notification_dispatch_failed audit event instead of being
      // swallowed by the subscription's fire-and-forget backstop.
      final DispatchResult result;
      try {
        result = await channel.dispatch(message);
      } catch (e) {
        await _recordFailure(event, participantId,
            fcmTokenAggregateId: t.aggregateId, reason: 'dispatch_threw: $e');
        continue;
      }
      if (result.unregistered) {
        await _recordFailure(event, participantId,
            fcmTokenAggregateId: t.aggregateId, reason: 'UNREGISTERED');
        await _deactivateToken(t.aggregateId);
      } else if (result.success) {
        await _recordSent(event, participantId,
            fcmTokenAggregateId: t.aggregateId,
            messageId: result.messageId ?? '');
      } else {
        await _recordFailure(event, participantId,
            fcmTokenAggregateId: t.aggregateId,
            reason: result.error ?? 'unknown');
      }
    }
  }

  /// Participant-aggregate events carry the participant as aggregateId;
  /// questionnaire-aggregate events carry it in data['participant_id'].
  String? _participantOf(StoredEvent event) {
    if (event.aggregateType == 'participant') return event.aggregateId;
    return event.data['participant_id'] as String?;
  }

  // Select the participant's active routing token(s) from the
  //   participant_fcm_tokens projection. Rows are keyed
  //   "{participantId}:fcm:{platform}"; filter by the participant prefix.
  Future<List<_ActiveToken>> _activeTokensFor(String participantId) async {
    final rows = await backend.findViewRows('participant_fcm_tokens');
    final prefix = '$participantId:';
    return <_ActiveToken>[
      for (final row in rows)
        if ((row['aggregateId'] as String?)?.startsWith(prefix) ?? false)
          if (row['token'] is String)
            _ActiveToken(
              aggregateId: row['aggregateId']! as String,
              token: row['token']! as String,
            ),
    ];
  }

  Future<void> _recordSent(StoredEvent intent, String participantId,
      {required String fcmTokenAggregateId, required String messageId}) async {
    await eventStore.append(
      entryType: 'notification_sent',
      aggregateType: 'Notification',
      aggregateId: intent.flowToken ?? intent.eventId,
      eventType: 'notification_sent',
      flowToken: intent.flowToken,
      data: <String, Object?>{
        'participant_id': participantId,
        'channel': 'fcm',
        'fcm_token_aggregate_id': fcmTokenAggregateId,
        'intent_entry_type': intent.entryType,
        'message_id': messageId,
      },
      initiator: const AutomationInitiator(service: 'notification-dispatch'),
    );
  }

  Future<void> _recordFailure(StoredEvent intent, String participantId,
      {required String fcmTokenAggregateId, required String reason}) async {
    await eventStore.append(
      entryType: 'notification_dispatch_failed',
      aggregateType: 'Notification',
      aggregateId: intent.flowToken ?? intent.eventId,
      eventType: 'notification_dispatch_failed',
      flowToken: intent.flowToken,
      data: <String, Object?>{
        'participant_id': participantId,
        'channel': 'fcm',
        'fcm_token_aggregate_id': fcmTokenAggregateId,
        'intent_entry_type': intent.entryType,
        'reason': reason,
      },
      initiator: const AutomationInitiator(service: 'notification-dispatch'),
    );
  }

  // Emit a deactivation tombstone so the participant_fcm_tokens projection
  //   drops the dead token. The projection gates removal on eventType
  //   ('tombstone'); the semantic name stays in entryType
  //   ('fcm_token_deactivated').
  Future<void> _deactivateToken(String tokenAggregateId) async {
    await eventStore.append(
      entryType: 'fcm_token_deactivated',
      aggregateType: 'FcmToken',
      aggregateId: tokenAggregateId,
      eventType: 'tombstone',
      data: const <String, Object?>{'reason': 'UNREGISTERED'},
      initiator: const AutomationInitiator(service: 'notification-dispatch'),
    );
  }

  Future<void> stop() => _sub?.cancel() ?? Future<void>.value();
}

class _Intent {
  const _Intent({required this.userVisible, this.title});
  final bool userVisible;
  final String? title;
}

class _ActiveToken {
  const _ActiveToken({required this.aggregateId, required this.token});
  final String aggregateId;
  final String token;
}
