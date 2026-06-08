// Verifies: DIARY-BASE-sponsor-requested-settings/A+B — a `sponsor_settings`
//   batch carried in a /link response is applied through the diary's normal
//   action dispatcher (apply_sponsor_settings), recording one
//   setting_applied(source: sponsor, locked: true) per key in the `settings`
//   projection. Empty/absent batch is a no-op. Re-applying an unchanged batch
//   appends NO new events (genuine event-log idempotence); only the keys whose
//   materialized (value, locked) differ are re-applied.
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:clinical_diary/services/link_sponsor_settings.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<DiaryScopeRuntime> _boot() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'p22-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return bootstrapDiaryScope(
    backend: SembastBackend(database: db),
    deviceId: 'DEV-1',
    softwareVersion: 'clinical_diary@0.0.0-test',
    localUserId: 'P-test',
  );
}

Future<List<Map<String, Object?>>> _rows(
  DiaryScopeRuntime rt,
  String viewName,
) async {
  final out = <String, Map<String, Object?>>{};
  final sub = rt.scope.viewSource
      .watch<Map<String, Object?>>(viewName: viewName, mapper: (r) => r)
      .listen((u) {
        if (u is Snapshot<Map<String, Object?>>) {
          final v = u.value;
          if (v != null) {
            out[v['aggregateId'] as String? ?? v['key'] as String] = v;
          }
        }
      });
  await Future<void>.delayed(const Duration(milliseconds: 80));
  await sub.cancel();
  return out.values.toList();
}

/// Count `Setting`-aggregate events in the log — one is appended per applied
/// setting key. Lets the idempotence tests assert at the EVENT-LOG level, not
/// just the latest-wins materialized view.
Future<int> _settingEventCount(DiaryScopeRuntime rt) async {
  final events = await rt.bundle.eventStore.backend.findAllEvents();
  return events.where((e) => e.aggregateType == settingAggregateType).length;
}

void main() {
  test('a link sponsor_settings batch is applied via apply_sponsor_settings '
      '(source sponsor + locked true)', () async {
    final rt = await _boot();
    final keys = await applyLinkSponsorSettings(rt.scope, <Object?>[
      <String, Object?>{
        'key': 'branding.title',
        'value': 'Reference',
        'locked': true,
      },
      <String, Object?>{
        'key': 'branding.logoRole',
        'value': 'logo',
        'locked': true,
      },
    ]);
    expect(keys, containsAll(<String>['branding.title', 'branding.logoRole']));

    final rows = await _rows(rt, settingsViewName);
    final title = rows.firstWhere((r) => r['key'] == 'branding.title');
    expect(title['value'], 'Reference');
    expect(title['source'], 'sponsor');
    expect(title['locked'], isTrue);

    final role = rows.firstWhere((r) => r['key'] == 'branding.logoRole');
    expect(role['value'], 'logo');
    expect(role['source'], 'sponsor');
    expect(role['locked'], isTrue);

    await rt.dispose();
  });

  test('an empty batch is a no-op (no settings written)', () async {
    final rt = await _boot();
    final keys = await applyLinkSponsorSettings(rt.scope, const <Object?>[]);
    expect(keys, isEmpty);
    final rows = await _rows(rt, settingsViewName);
    expect(rows, isEmpty);
    await rt.dispose();
  });

  test('a null batch is a no-op', () async {
    final rt = await _boot();
    final keys = await applyLinkSponsorSettings(rt.scope, null);
    expect(keys, isEmpty);
    final rows = await _rows(rt, settingsViewName);
    expect(rows, isEmpty);
    await rt.dispose();
  });

  test('re-applying the SAME batch appends NO new events (event-log '
      'idempotence, not just latest-wins)', () async {
    final rt = await _boot();
    const batch = <Object?>[
      <String, Object?>{
        'key': 'branding.title',
        'value': 'Reference',
        'locked': true,
      },
      <String, Object?>{
        'key': 'branding.logoRole',
        'value': 'logo',
        'locked': true,
      },
    ];

    // First apply: all keys land — one Setting event per key.
    final firstKeys = await applyLinkSponsorSettings(rt.scope, batch);
    expect(firstKeys, hasLength(2));
    final afterFirst = await _settingEventCount(rt);
    expect(afterFirst, 2);

    // Second apply of the IDENTICAL batch: nothing differs, so no dispatch and
    // ZERO new Setting events appended (the log does not grow on cold restart).
    final secondKeys = await applyLinkSponsorSettings(rt.scope, batch);
    expect(secondKeys, isEmpty);
    final afterSecond = await _settingEventCount(rt);
    expect(afterSecond, afterFirst);

    // Materialized view is still exactly one row per key.
    final rows = await _rows(rt, settingsViewName);
    expect(
      rows.where((r) => r['key'] == 'branding.title').toList(),
      hasLength(1),
    );
    expect(
      rows.where((r) => r['key'] == 'branding.logoRole').toList(),
      hasLength(1),
    );
    await rt.dispose();
  });

  test('a genuinely changed value re-applies ONLY the changed key', () async {
    final rt = await _boot();
    await applyLinkSponsorSettings(rt.scope, <Object?>[
      <String, Object?>{
        'key': 'branding.title',
        'value': 'Reference',
        'locked': true,
      },
      <String, Object?>{
        'key': 'branding.logoSha256',
        'value': 'sha-old',
        'locked': true,
      },
    ]);
    final afterFirst = await _settingEventCount(rt);
    expect(afterFirst, 2);

    // Re-link with a NEW logo sha256 but an unchanged title: only the changed
    // key is dispatched -> exactly one new Setting event.
    final changedKeys = await applyLinkSponsorSettings(rt.scope, <Object?>[
      <String, Object?>{
        'key': 'branding.title',
        'value': 'Reference',
        'locked': true,
      },
      <String, Object?>{
        'key': 'branding.logoSha256',
        'value': 'sha-new',
        'locked': true,
      },
    ]);
    expect(changedKeys, <String>['branding.logoSha256']);
    final afterChange = await _settingEventCount(rt);
    expect(afterChange, afterFirst + 1);

    final rows = await _rows(rt, settingsViewName);
    final sha = rows.firstWhere((r) => r['key'] == 'branding.logoSha256');
    expect(sha['value'], 'sha-new');
    final title = rows.firstWhere((r) => r['key'] == 'branding.title');
    expect(title['value'], 'Reference');
    await rt.dispose();
  });

  test(
    'a key newly added on re-link is applied; unchanged keys are not',
    () async {
      final rt = await _boot();
      await applyLinkSponsorSettings(rt.scope, <Object?>[
        <String, Object?>{
          'key': 'branding.title',
          'value': 'Reference',
          'locked': true,
        },
      ]);
      final afterFirst = await _settingEventCount(rt);
      expect(afterFirst, 1);

      final keys = await applyLinkSponsorSettings(rt.scope, <Object?>[
        <String, Object?>{
          'key': 'branding.title',
          'value': 'Reference',
          'locked': true,
        },
        <String, Object?>{
          'key': 'branding.logoRole',
          'value': 'logo',
          'locked': true,
        },
      ]);
      expect(keys, <String>['branding.logoRole']);
      expect(await _settingEventCount(rt), afterFirst + 1);
      await rt.dispose();
    },
  );

  test('unlockSponsorSettings reverts ui.* allow-sets to default and keeps '
      'clinical values, all unlocked', () async {
    // Verifies: DIARY-BASE-sponsor-requested-settings/E
    // Verifies: DIARY-DEV-deployment-config-defaults/F
    final rt = await _boot();
    await applyLinkSponsorSettings(rt.scope, <Object?>[
      <String, Object?>{
        'key': 'ui.availableLanguages',
        'value': <String>['en', 'es'],
        'locked': true,
      },
      <String, Object?>{
        'key': 'clinical.shortDurationConfirm',
        'value': true,
        'locked': true,
      },
    ]);

    final unlocked = await unlockSponsorSettings(rt.scope);
    expect(unlocked.toSet(), {
      'ui.availableLanguages',
      'clinical.shortDurationConfirm',
    });

    final rows = await _rows(rt, settingsViewName);
    final byKey = {for (final r in rows) r['key'] as String: r};
    expect(byKey['ui.availableLanguages']!['value'], isNull); // reverted
    expect(byKey['ui.availableLanguages']!['locked'], false);
    expect(byKey['clinical.shortDurationConfirm']!['value'], true); // kept
    expect(byKey['clinical.shortDurationConfirm']!['locked'], false);

    // Idempotent: nothing is locked now, so a re-run is a no-op.
    expect(await unlockSponsorSettings(rt.scope), isEmpty);
    await rt.dispose();
  });
}
