import 'dart:async';

import 'package:event_sourcing/event_sourcing.dart';

/// Subscribes to [role_assigned] and [role_unassigned] events on the
/// [user_role_scope] aggregate. On each, recomputes the affected user's tier
/// (operator if any active [SystemOperator] assignment exists, else staff) from
/// the [user_role_scopes] projection, then appends a [user_tier_changed] event
/// against the [portal_user] aggregate ONLY when the tier differs from the
/// current [user_tier_index] value (idempotent — never emits a no-op).
// Implements: DIARY-DEV-operator-tier-authz/A
class UserTierReactor {
  UserTierReactor({required this.eventStore, required this.backend});

  final EventStore eventStore;
  final StorageBackend backend;

  StreamSubscription<Update<StoredEvent>>? _sub;

  void start() {
    _sub = eventStore
        .subscribe<StoredEvent>(
      const SubscriptionFilter(
        eventTypes: {'role_assigned', 'role_unassigned'},
        aggregateTypes: {'user_role_scope'},
      ),
      const Events(),
    )
        .listen((update) {
      if (update is Delta<StoredEvent>) {
        unawaited(_handleRoleEvent(update.value));
      }
    });
  }

  // Implements: DIARY-DEV-operator-tier-authz/A
  Future<void> _handleRoleEvent(StoredEvent event) async {
    final userId = event.data['user_id'] as String?;
    if (userId == null) return;

    // Read the current role assignments for this user from the projection.
    final allScopes = await backend.findViewRows('user_role_scopes');
    final userScopes =
        allScopes.where((r) => r['user_id'] == userId).toList();

    // Compute tier: 'operator' if any active assignment has role == 'SystemOperator'.
    final newTier = userScopes.any((r) => r['role'] == 'SystemOperator')
        ? 'operator'
        : 'staff';

    // Read the current stored tier from user_tier_index (if any).
    final tierIndex = await backend.findViewRows('user_tier_index');
    final existing = tierIndex
        .where((r) => r['user_id'] == userId)
        .firstOrNull;
    final currentTier = existing?['tier'] as String?;

    // Idempotent: only emit when the tier actually changes.
    if (newTier == currentTier) return;

    await eventStore.append(
      entryType: 'user_tier_changed',
      aggregateType: 'portal_user',
      aggregateId: userId,
      eventType: 'user_tier_changed',
      data: <String, Object?>{'user_id': userId, 'tier': newTier},
      initiator: const AutomationInitiator(service: 'user-tier-reactor'),
    );
  }

  Future<void> stop() => _sub?.cancel() ?? Future<void>.value();
}
