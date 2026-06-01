/// In-process per-session last-seen map for idle-timeout tracking. Internal to
/// the validator; swappable to WS-message-level activity later.
// Implements: DIARY-DEV-portal-session-lifecycle/A
class SessionStore {
  final Map<String, DateTime> _lastSeen = <String, DateTime>{};

  void touch(String sid, DateTime now) => _lastSeen[sid] = now;
  DateTime? lastSeen(String sid) => _lastSeen[sid];
  void forget(String sid) => _lastSeen.remove(sid);
}
