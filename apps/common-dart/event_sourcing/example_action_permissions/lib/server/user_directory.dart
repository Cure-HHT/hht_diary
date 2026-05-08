// IMPLEMENTS REQUIREMENTS:
//   REQ-d00168 (Dispatcher Pipeline) — host-side resolver before pipeline
//   entry.
//
// Server-side userId -> Principal resolver. Seed comes from tool/users.yaml at
// boot via UserDirectorySeedApplier; runtime mutations come from
// ProvisionUserAction via UserDirectoryMaterializer. Anonymous for any
// unrecognized or null userId.

import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:event_sourcing/event_sourcing.dart' show Principal;

class UserDirectory {
  UserDirectory();

  final Map<String, _Entry> _entries = <String, _Entry>{};

  Principal resolve(String? userId) {
    if (userId == null) return const Principal.anonymous();
    final entry = _entries[userId];
    if (entry == null) return const Principal.anonymous();
    return Principal.user(
      userId: userId,
      roles: <String>{entry.role},
      activeRole: entry.role,
      activeSite: entry.activeSite,
    );
  }

  void upsert({
    required String userId,
    required String role,
    required String? activeSite,
  }) {
    _entries[userId] = _Entry(role: role, activeSite: activeSite);
  }

  bool contains(String userId) => _entries.containsKey(userId);

  List<UserDirectoryEntry> listEntries() {
    final ids = _entries.keys.toList()..sort();
    return ids
        .map(
          (id) => UserDirectoryEntry(
            userId: id,
            role: _entries[id]!.role,
            activeSite: _entries[id]!.activeSite,
          ),
        )
        .toList();
  }
}

final class _Entry {
  const _Entry({required this.role, required this.activeSite});

  final String role;
  final String? activeSite;
}
