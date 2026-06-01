import 'dart:async';

import 'package:event_sourcing/event_sourcing.dart';

/// Subscribes to security events that must immediately end a user's sessions
/// (deactivation, session revocation, role/site assignment change) and appends
/// `session_terminated` for each of that user's live sessions. Enforcement of
/// the termination is by the SessionTokenValidator denying the next request;
/// the reaction server additionally force-closes live WS on role_unassigned.
// Implements: DIARY-DEV-portal-session-lifecycle/B
class SessionCascadeReactor {
  SessionCascadeReactor({required this.eventStore, required this.backend});

  final EventStore eventStore;
  final StorageBackend backend;

  StreamSubscription<Update<StoredEvent>>? _sub;

  void start() {
    _sub = eventStore
        .subscribe<StoredEvent>(
      const SubscriptionFilter(eventTypes: {
        'user_deactivated',
        'user_sessions_revoked',
        'role_assigned',
        'role_unassigned',
      }),
      const Events(),
    )
        .listen((update) {
      if (update is Delta<StoredEvent>) {
        unawaited(handleSecurityEvent(update.value));
      }
    });
  }

  Future<void> handleSecurityEvent(StoredEvent event) async {
    final userId = _affectedUser(event);
    if (userId == null) return;
    final sessions = await backend.findViewRows('sessions_index');
    // Collect session ids first to avoid modifying the store while iterating.
    final sids = <String>[
      for (final row in sessions)
        if (row['user_id'] == userId && row['aggregateId'] is String)
          row['aggregateId']! as String,
    ];
    for (final sid in sids) {
      await eventStore.append(
        entryType: 'session_terminated',
        aggregateType: 'session',
        aggregateId: sid,
        eventType: 'session_terminated',
        data: <String, Object?>{'reason': 'cascade:${event.eventType}'},
        initiator: const AutomationInitiator(service: 'session-cascade'),
      );
    }
  }

  /// portal_user events carry the user as aggregateId; user_role_scope events
  /// carry it in data['user_id'].
  String? _affectedUser(StoredEvent event) {
    if (event.aggregateType == 'portal_user') return event.aggregateId;
    return event.data['user_id'] as String?;
  }

  Future<void> stop() => _sub?.cancel() ?? Future<void>.value();
}
