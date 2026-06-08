// Verifies: DIARY-DEV-portal-session-config/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/src/session_config.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  late EventStore eventStore;
  late StorageBackend backend;

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('sesscfg.db');
    backend = SembastBackend(database: db);
    eventStore = await openPortalEventStore(backend: backend);
  });

  Future<void> putSetting(String key, Object? value) => eventStore.append(
        entryType: 'portal_setting_changed',
        aggregateType: 'portal_setting',
        aggregateId: key,
        eventType: 'portal_setting_changed',
        data: {'key': key, 'value': value},
        initiator: const AutomationInitiator(service: 'test'),
      );

  group('resolveSessionConfig', () {
    test('defaults when store + env are empty', () async {
      final cfg = await resolveSessionConfig(backend, const {});
      expect(cfg.idleMinutes, 10);
      expect(cfg.warningSeconds, 60);
      expect(cfg.idleTimeout, const Duration(minutes: 10));
      expect(cfg.idleSeconds, 600);
    });

    test('legacy env overrides default; store overrides legacy env', () async {
      final viaEnv = await resolveSessionConfig(
          backend, const {'PORTAL_SESSION_IDLE_MINUTES': '15'});
      expect(viaEnv.idleMinutes, 15);

      await putSetting('session_idle_minutes', 20);
      final viaStore = await resolveSessionConfig(
          backend, const {'PORTAL_SESSION_IDLE_MINUTES': '15'});
      expect(viaStore.idleMinutes, 20, reason: 'store wins over legacy env');
    });

    test('clamps idle to 1..30 and warning to 10..idle*60', () async {
      await putSetting('session_idle_minutes', 99); // -> 30
      await putSetting('session_warning_seconds', 9999); // -> 30*60
      final hi = await resolveSessionConfig(backend, const {});
      expect(hi.idleMinutes, 30);
      expect(hi.warningSeconds, 1800);

      await putSetting('session_idle_minutes', 0); // -> 1
      await putSetting('session_warning_seconds', 1); // -> 10
      final lo = await resolveSessionConfig(backend, const {});
      expect(lo.idleMinutes, 1);
      expect(lo.warningSeconds, 10);
    });

    test('tolerates string-typed setting values', () async {
      await putSetting('session_idle_minutes', '12');
      final cfg = await resolveSessionConfig(backend, const {});
      expect(cfg.idleMinutes, 12);
    });

    test('warning upper bound uses the resolved idle from legacy env',
        () async {
      // Idle comes only from the legacy env (2 min); default warning 60s is
      // within 2*60=120s, so it survives unclamped.
      final cfg = await resolveSessionConfig(
          backend, const {'PORTAL_SESSION_IDLE_MINUTES': '2'});
      expect(cfg.idleMinutes, 2);
      expect(cfg.warningSeconds, 60);
      expect(cfg.idleSeconds, 120);
    });
  });

  group('seedSessionConfig', () {
    Future<List<Map<String, Object?>>> settings() =>
        backend.findViewRows('portal_settings');

    test('no-op when neither seed env var is set', () async {
      await seedSessionConfig(
          eventStore: eventStore, backend: backend, env: const {});
      expect(await settings(), isEmpty);
    });

    test('seeds both keys from env, idempotent on re-run', () async {
      const env = {
        'PORTAL_SEED_SESSION_IDLE_MINUTES': '10',
        'PORTAL_SEED_SESSION_WARNING_SECONDS': '60',
      };
      await seedSessionConfig(
          eventStore: eventStore, backend: backend, env: env);
      final rows1 = await settings();
      expect(
          rows1.firstWhere((r) => r['key'] == 'session_idle_minutes')['value'],
          10);
      expect(
          rows1.firstWhere(
              (r) => r['key'] == 'session_warning_seconds')['value'],
          60);

      await seedSessionConfig(
          eventStore: eventStore, backend: backend, env: env);
      final rows2 = await settings();
      expect(rows2.length, rows1.length, reason: 'no duplicate rows on re-run');
    });

    test('clamps an out-of-range seed before storing', () async {
      const env = {'PORTAL_SEED_SESSION_IDLE_MINUTES': '99'};
      await seedSessionConfig(
          eventStore: eventStore, backend: backend, env: env);
      final rows = await settings();
      expect(
          rows.firstWhere((r) => r['key'] == 'session_idle_minutes')['value'],
          30);
    });

    test('seeds only the warning key when only its env var is set', () async {
      const env = {'PORTAL_SEED_SESSION_WARNING_SECONDS': '30'};
      await seedSessionConfig(
          eventStore: eventStore, backend: backend, env: env);
      final rows = await settings();
      expect(rows.any((r) => r['key'] == 'session_idle_minutes'), isFalse,
          reason: 'idle env not set -> idle key not seeded');
      expect(
          rows.firstWhere(
              (r) => r['key'] == 'session_warning_seconds')['value'],
          30,
          reason:
              'warning clamped against default idle (10min=600s), 30 < 600');
    });
  });
}
