/// Stub web-state wipe for non-web platforms. iOS/Android have no
/// equivalent of IndexedDB/localStorage that lives outside
/// flutter_secure_storage + SharedPreferences, so this is a no-op.
Future<void> wipeWebOnlyState() async {
  // Intentionally empty.
}
