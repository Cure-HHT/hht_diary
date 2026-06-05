// Verifies: DIARY-DEV-portal-settings-store/B
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

Future<EventStore> _open(String dbName) async {
  final db = await databaseFactoryMemory.openDatabase(dbName);
  return openPortalEventStore(backend: SembastBackend(database: db));
}

void main() {
  test('portal_settings folds latest value per key', () async {
    final store = await _open('ps-1');
    await store.append(
      entryType: 'portal_setting_changed',
      aggregateType: 'portal_setting',
      aggregateId: 'require_second_factor',
      eventType: 'portal_setting_changed',
      data: const {'key': 'require_second_factor', 'value': false},
      initiator: const AutomationInitiator(service: 'test'),
    );

    final rows = await store.backend.findViewRows('portal_settings');
    expect(rows, hasLength(1));
    expect(rows.single['key'], 'require_second_factor');
    expect(rows.single['value'], isFalse);
  });

  test('portal_settings overwrites with latest value on re-change', () async {
    final store = await _open('ps-2');
    await store.append(
      entryType: 'portal_setting_changed',
      aggregateType: 'portal_setting',
      aggregateId: 'require_second_factor',
      eventType: 'portal_setting_changed',
      data: const {'key': 'require_second_factor', 'value': false},
      initiator: const AutomationInitiator(service: 'test'),
    );
    await store.append(
      entryType: 'portal_setting_changed',
      aggregateType: 'portal_setting',
      aggregateId: 'require_second_factor',
      eventType: 'portal_setting_changed',
      data: const {'key': 'require_second_factor', 'value': true},
      initiator: const AutomationInitiator(service: 'test'),
    );

    final rows = await store.backend.findViewRows('portal_settings');
    expect(rows, hasLength(1));
    expect(rows.single['value'], isTrue);
  });
}
