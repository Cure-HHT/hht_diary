// lib/src/permissions/role_permission_grants_materializer.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00174-C (permission_granted -> upsert view row),
//   REQ-d00174-D (permission_revoked -> delete view row),
//   REQ-d00174-E (appliesTo filters by aggregateType).

import 'package:event_sourcing/event_sourcing.dart';

class RolePermissionGrantsMaterializer extends Materializer {
  const RolePermissionGrantsMaterializer();

  @override
  String get viewName => 'role_permission_grants';

  @override
  bool appliesTo(StoredEvent event) =>
      event.aggregateType == 'role_permission_grant';

  // The matrix has no schema-versioning story — the row payload shape is
  // fixed (role/permissionName/scope) and entryTypeVersion is pinned at 1.
  // identityPromoter passes event.data through unchanged.
  @override
  EntryPromoter get promoter => identityPromoter;

  @override
  Future<void> applyInTxn(
    Txn txn,
    StorageBackend backend, {
    required StoredEvent event,
    required Map<String, Object?> promotedData,
    required EntryTypeDefinition def,
    required List<StoredEvent> aggregateHistory,
  }) async {
    switch (event.eventType) {
      case 'permission_granted':
        final p = PermissionGrantedPayload.fromJson(promotedData);
        await backend.upsertViewRowInTxn(
          txn,
          viewName,
          event.aggregateId,
          <String, Object?>{
            'role': p.role,
            'permissionName': p.permissionName,
            'scope': p.scope.name,
          },
        );
        return;
      case 'permission_revoked':
        await backend.deleteViewRowInTxn(txn, viewName, event.aggregateId);
        return;
      default:
        // Unknown event type for this aggregate — defensive no-op.
        return;
    }
  }
}
