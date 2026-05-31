// Verifies: DIARY-BASE-sponsor-requested-settings/B+F
//
// End-to-end fold of settingsProjection over a real in-memory EventStore: one
// row per setting key, latest event wins, lock transitions are reflected.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

Future<EventStore> _open() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'dsm-set-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  final entryTypes = EntryTypeRegistry()
    ..register(
      const EntryTypeDefinition(
        id: 'setting_applied',
        registeredVersion: 1,
        name: 'Setting Applied',
      ),
    );
  final projections = ProjectionRegistry()..register(settingsProjection);
  return EventStore.open(
    storage: backend,
    entryTypes: entryTypes,
    source: const Source(
      hopId: 'mobile',
      identifier: 'test',
      softwareVersion: '0.0.0-test',
    ),
    securityContexts: SembastSecurityContextStore(backend: backend),
    projections: projections,
  );
}

Future<void> _apply(EventStore store, SettingPayload p) => store.append(
  entryType: 'setting_applied',
  aggregateType: settingAggregateType,
  aggregateId: p.key,
  eventType: 'finalized',
  data: p.toJson(),
  initiator: const UserInitiator('u1'),
);

Future<Map<String, SettingPayload>> _drain(EventStore store) async {
  final rows = <String, Map<String, Object?>>{};
  final sub = store
      .subscribe<Map<String, Object?>>(
        const SubscriptionFilter(aggregateTypes: {settingAggregateType}),
        AggregateMode<Map<String, Object?>>(
          viewName: settingsViewName,
          mapper: (row) => row,
        ),
      )
      .listen((u) {
        if (u is Snapshot<Map<String, Object?>>) {
          final v = u.value;
          if (v != null) rows[v['key']! as String] = v;
        }
      });
  await Future<void>.delayed(const Duration(milliseconds: 60));
  await sub.cancel();
  return rows.map((k, v) => MapEntry(k, SettingPayload.fromJson(v)));
}

void main() {
  test('folds latest-per-key; lock transition reflected', () async {
    final store = await _open();
    // Sponsor applies (locked), then the same key is unlocked keeping value.
    await _apply(
      store,
      const SettingPayload(
        key: 'clinical.lockThresholdHours',
        value: 48,
        source: SettingSource.sponsor,
        locked: true,
      ),
    );
    await _apply(
      store,
      const SettingPayload(
        key: 'pref.darkMode',
        value: false,
        source: SettingSource.user,
        locked: false,
      ),
    );
    await _apply(
      store,
      const SettingPayload(
        key: 'clinical.lockThresholdHours',
        value: 48,
        source: SettingSource.sponsor,
        locked: false, // unlock keeps value
      ),
    );

    final settings = await _drain(store);
    expect(
      settings.keys,
      containsAll(<String>['clinical.lockThresholdHours', 'pref.darkMode']),
    );
    expect(
      settings['clinical.lockThresholdHours']!.locked,
      isFalse,
    ); // latest wins
    expect(settings['clinical.lockThresholdHours']!.value, 48);
    expect(settings['pref.darkMode']!.source, SettingSource.user);
    await store.close();
  });
}
