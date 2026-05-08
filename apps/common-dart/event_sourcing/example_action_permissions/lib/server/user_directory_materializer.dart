// IMPLEMENTS REQUIREMENTS:
//   REQ-d00174 (Materializer-in-transaction pattern) — applies user_provisioned
//   events to the in-memory UserDirectory; runs inside the events.transaction
//   block as part of EventStore commit (when wired through Materializer
//   protocol from event_sourcing in Task 14).
//
// applyDirect() is the bare projection used by tests and the seed applier.

import 'package:action_permissions_demo/server/user_directory.dart';

class UserDirectoryMaterializer {
  UserDirectoryMaterializer({required this.directory});

  final UserDirectory directory;

  /// Applies a user_provisioned event payload to the directory.
  /// Re-applying with the same payload is a no-op; re-applying with a
  /// different role/site for the same userId overwrites.
  void applyDirect(Map<String, Object?> payload) {
    final userId = payload['userId']! as String;
    final role = payload['role']! as String;
    final activeSite = payload['activeSite'] as String?;
    directory.upsert(userId: userId, role: role, activeSite: activeSite);
  }
}
