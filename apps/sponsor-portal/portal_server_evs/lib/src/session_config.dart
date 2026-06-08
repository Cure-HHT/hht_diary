import 'package:event_sourcing/event_sourcing.dart';

/// Effective portal session-timeout configuration: the idle window and the
/// pre-timeout warning lead. Sourced from the portal_settings store with env +
/// default fallback; both values clamped to the documented ranges.
class SessionConfig {
  const SessionConfig(
      {required this.idleMinutes, required this.warningSeconds});
  final int idleMinutes;
  final int warningSeconds;
  Duration get idleTimeout => Duration(minutes: idleMinutes);
  int get idleSeconds => idleMinutes * 60;
}

const int kDefaultIdleMinutes = 10;
const int kDefaultWarningSeconds = 60;
const int kMinIdleMinutes = 1;
const int kMaxIdleMinutes = 30;
const int kMinWarningSeconds = 10;

int _clampIdle(int v) => v.clamp(kMinIdleMinutes, kMaxIdleMinutes);
int _clampWarning(int v, int idleMinutes) =>
    v.clamp(kMinWarningSeconds, idleMinutes * 60);

/// Resolves the effective [SessionConfig] from the portal_settings store keys
/// `session_idle_minutes` / `session_warning_seconds`, falling back to the
/// legacy `PORTAL_SESSION_IDLE_MINUTES` env, then the defaults. Clamps both.
/// This is the single authoritative reader used by both the validator
/// (at boot) and the `/config/session` surface, so client and server agree.
// Implements: DIARY-DEV-portal-session-config/A
Future<SessionConfig> resolveSessionConfig(
  StorageBackend backend,
  Map<String, String> env,
) async {
  final rows = await backend.findViewRows('portal_settings');
  int? settingInt(String key) {
    for (final r in rows) {
      if (r['key'] == key) {
        final v = r['value'];
        if (v is int) return v;
        if (v is String) return int.tryParse(v);
      }
    }
    return null;
  }

  final legacyIdle = int.tryParse(env['PORTAL_SESSION_IDLE_MINUTES'] ?? '');
  final idle = _clampIdle(
      settingInt('session_idle_minutes') ?? legacyIdle ?? kDefaultIdleMinutes);
  // No legacy env for the warning lead — it is net-new, so store-or-default only
  // (PORTAL_SESSION_IDLE_MINUTES predates this feature; the warning never had one).
  final warning = _clampWarning(
      settingInt('session_warning_seconds') ?? kDefaultWarningSeconds, idle);
  return SessionConfig(idleMinutes: idle, warningSeconds: warning);
}

/// Idempotent boot seed of the two session-config keys from deployment env
/// (`PORTAL_SEED_SESSION_IDLE_MINUTES` / `PORTAL_SEED_SESSION_WARNING_SECONDS`).
/// Appends a `portal_setting_changed` only when a key is absent or differs.
/// Values are clamped before storing so a misconfigured env cannot persist an
/// out-of-range value; [resolveSessionConfig] re-clamps at read time, so it
/// stays authoritative. Mirrors seedRequireSecondFactor / seedSponsorConfig.
// Implements: DIARY-DEV-portal-session-config/A
Future<void> seedSessionConfig({
  required EventStore eventStore,
  required StorageBackend backend,
  required Map<String, String> env,
}) async {
  final idleRaw = int.tryParse(env['PORTAL_SEED_SESSION_IDLE_MINUTES'] ?? '');
  final warnRaw =
      int.tryParse(env['PORTAL_SEED_SESSION_WARNING_SECONDS'] ?? '');
  if (idleRaw == null && warnRaw == null) return; // nothing configured

  final rows = await backend.findViewRows('portal_settings');
  final current = <String, Object?>{
    for (final r in rows) r['key'] as String: r['value'],
  };

  Future<void> seedKey(String key, int value) async {
    Object? currentVal = current[key];
    if (currentVal is String) currentVal = int.tryParse(currentVal);
    if (current.containsKey(key) && currentVal == value) return;
    await eventStore.append(
      entryType: 'portal_setting_changed',
      aggregateType: 'portal_setting',
      aggregateId: key,
      eventType: 'portal_setting_changed',
      data: <String, Object?>{'key': key, 'value': value},
      initiator: const AutomationInitiator(service: 'session-config-seed'),
    );
  }

  // Clamp idle first; the warning clamp upper bound is idle*60.
  final idle = _clampIdle(idleRaw ?? kDefaultIdleMinutes);
  if (idleRaw != null) await seedKey('session_idle_minutes', idle);
  if (warnRaw != null) {
    await seedKey('session_warning_seconds', _clampWarning(warnRaw, idle));
  }
}
