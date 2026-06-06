// Verifies: DIARY-BASE-sponsor-requested-settings/A+B — a `sponsor_settings`
//   batch carried in a /link response is applied through the diary's normal
//   action dispatcher (apply_sponsor_settings), recording one
//   setting_applied(source: sponsor, locked: true) per key in the `settings`
//   projection. Empty/absent batch is a no-op.
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

  test('re-applying the same batch is idempotent (latest-wins)', () async {
    final rt = await _boot();
    const batch = <Object?>[
      <String, Object?>{
        'key': 'branding.title',
        'value': 'Reference',
        'locked': true,
      },
    ];
    await applyLinkSponsorSettings(rt.scope, batch);
    await applyLinkSponsorSettings(rt.scope, batch);

    final rows = await _rows(rt, settingsViewName);
    final title = rows.where((r) => r['key'] == 'branding.title').toList();
    expect(title, hasLength(1));
    expect(title.single['value'], 'Reference');
    await rt.dispose();
  });
}
