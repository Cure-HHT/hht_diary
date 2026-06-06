// Verifies: DIARY-DEV-sponsor-config-source/A+E
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/src/sponsor_config_seed.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  late EventStore eventStore;
  late StorageBackend backend;

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('seed.db');
    backend = SembastBackend(database: db);
    eventStore = await openPortalEventStore(backend: backend);
  });

  Future<List<Map<String, Object?>>> settingsRows() =>
      backend.findViewRows('portal_settings');

  test('seeds clinical + ui keys from env, idempotent on re-run', () async {
    final env = {
      'PORTAL_SEED_CLINICAL_SHORT_DURATION_CONFIRM': 'true',
      'PORTAL_SEED_CLINICAL_JUSTIFICATION_THRESHOLD_HOURS': '24',
      'PORTAL_SEED_UI_AVAILABLE_LANGUAGES': 'en,es,fr',
      'PORTAL_SEED_UI_DEFAULT_LANGUAGE': 'en',
    };
    await seedSponsorConfig(eventStore: eventStore, backend: backend, env: env);
    final rows1 = await settingsRows();
    expect(
      rows1.firstWhere(
          (r) => r['key'] == 'clinical.shortDurationConfirm')['value'],
      isTrue,
    );
    expect(
      rows1.firstWhere((r) => r['key'] == 'ui.availableLanguages')['value'],
      ['en', 'es', 'fr'],
    );

    await seedSponsorConfig(eventStore: eventStore, backend: backend, env: env);
    final rows2 = await settingsRows();
    expect(rows2.length, rows1.length); // no duplicate rows on re-run
  });

  test('fail-fast: allow-set contains an unsupported value', () async {
    // Verifies: DIARY-DEV-sponsor-config-source/E
    final env = {
      'PORTAL_SEED_UI_AVAILABLE_LANGUAGES':
          'en,xx', // xx is not a platform lang
      'PORTAL_SEED_UI_DEFAULT_LANGUAGE': 'en',
    };
    expect(
      () =>
          seedSponsorConfig(eventStore: eventStore, backend: backend, env: env),
      throwsA(isA<StateError>()),
    );
  });

  test('fail-fast: restricted languages without valid default', () async {
    final env = {
      'PORTAL_SEED_UI_AVAILABLE_LANGUAGES': 'en,es', // de/fr excluded
      // no PORTAL_SEED_UI_DEFAULT_LANGUAGE
    };
    expect(
      () =>
          seedSponsorConfig(eventStore: eventStore, backend: backend, env: env),
      throwsA(isA<StateError>()),
    );
  });
}
