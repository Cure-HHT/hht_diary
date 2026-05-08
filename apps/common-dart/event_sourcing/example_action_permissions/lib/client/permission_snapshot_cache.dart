// lib/client/permission_snapshot_cache.dart
//
// Client-side cache of the principal snapshot delivered by /session/start.
// A `ChangeNotifier` so the dual-pane UI rebuilds reactively on userId
// switch. The cache is the perimeter of "what the client thinks it can
// do" — gating action buttons against this set is purely a UI courtesy;
// the dispatcher's authorize stage is the real perimeter.

import 'package:flutter/foundation.dart';

class PermissionSnapshotCache extends ChangeNotifier {
  String? _userId;
  String _principalRole = 'Anon';
  String? _principalUserId;
  String? _principalActiveSite;
  Set<String> _permissions = const <String>{};

  String? get userId => _userId;
  String get principalRole => _principalRole;
  String? get principalUserId => _principalUserId;
  String? get principalActiveSite => _principalActiveSite;
  Set<String> get permissions => _permissions;

  /// Replace the entire snapshot. Notifies listeners.
  void update({
    required String? userId,
    required String principalRole,
    required String? principalUserId,
    required String? principalActiveSite,
    required Set<String> permissions,
  }) {
    _userId = userId;
    _principalRole = principalRole;
    _principalUserId = principalUserId;
    _principalActiveSite = principalActiveSite;
    _permissions = Set<String>.unmodifiable(permissions);
    notifyListeners();
  }

  bool holds(String permissionName) => _permissions.contains(permissionName);
}
