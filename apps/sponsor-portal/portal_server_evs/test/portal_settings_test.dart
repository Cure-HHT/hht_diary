// Verifies: DIARY-DEV-portal-second-factor-toggle/B
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:portal_server_evs/src/portal_settings.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  test('defaults to require=true when no setting exists (fail-safe)', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('settings1.db');
    final backend = SembastBackend(database: db);
    await openPortalEventStore(backend: backend);

    expect(await requireSecondFactor(backend), isTrue);
  });

  test('returns false when require_second_factor is set false', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('settings2.db');
    final backend = SembastBackend(database: db);
    final store = await openPortalEventStore(backend: backend);

    await store.append(
      entryType: 'portal_setting_changed',
      aggregateType: 'portal_setting',
      aggregateId: 'require_second_factor',
      eventType: 'portal_setting_changed',
      data: const {'key': 'require_second_factor', 'value': false},
      initiator: const AutomationInitiator(service: 'test'),
    );

    expect(await requireSecondFactor(backend), isFalse);
  });
}
