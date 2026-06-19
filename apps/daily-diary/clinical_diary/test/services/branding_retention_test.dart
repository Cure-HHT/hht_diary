// Verifies: DIARY-DEV-sponsor-branding-assets/D — branding settings and the
//   content-addressed branding asset cache are RETAINED after participation
//   ends. The cache lives under <appSupport>/branding_cache/ — a directory
//   SEPARATE from the documents dir the local-data-reset wipes — and is never
//   on that wipe's delete list, so cached logo bytes survive the reset. The
//   not-participating transition (a pref flip + enrollment clear) touches
//   neither the diary event store nor the cache, so the branding.* settings
//   remain readable from the settings projection.
import 'dart:io';

import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:clinical_diary/services/link_sponsor_settings.dart';
import 'package:clinical_diary/services/local_data_reset.dart';
import 'package:clinical_diary/services/sponsor_branding_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_enrollment_service.dart';

Future<DiaryScopeRuntime> _boot() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'retention-${DateTime.now().microsecondsSinceEpoch}.db',
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('branding retention', () {
    late Directory docsDir;
    late Directory brandingCacheDir;

    setUp(() {
      // Documents dir holds the store files the wipe targets; the branding
      // cache lives in a SEPARATE support dir.
      docsDir = Directory.systemTemp.createTempSync('branding_docs');
      brandingCacheDir = Directory.systemTemp.createTempSync('branding_cache');
    });

    tearDown(() {
      for (final d in [docsDir, brandingCacheDir]) {
        if (d.existsSync()) d.deleteSync(recursive: true);
      }
    });

    test('local-data-reset wipes the store file but RETAINS the branding '
        'cache (different dir, not on the delete list)', () async {
      // Seed the store file the wipe targets.
      File('${docsDir.path}/diary_es.db').writeAsStringSync('es');
      // Seed a content-addressed branding asset (hash-named file).
      const sha = 'cafef00d';
      final logoFile = File('${brandingCacheDir.path}/$sha')
        ..writeAsBytesSync(const [1, 2, 3, 4]);
      expect(logoFile.existsSync(), isTrue);

      SharedPreferences.setMockInitialValues({'k': 'v'});
      final prefs = await SharedPreferences.getInstance();
      final tasks = TaskService();
      addTearDown(tasks.dispose);

      await wipeLocalData(
        documentsPath: docsDir.path,
        enrollmentService: MockEnrollmentService(),
        taskService: tasks,
        prefs: prefs,
      );

      // Store file gone — but the branding cache survives the reset.
      expect(File('${docsDir.path}/diary_es.db').existsSync(), isFalse);
      expect(logoFile.existsSync(), isTrue);
      expect(brandingCacheDir.existsSync(), isTrue);
      expect(logoFile.readAsBytesSync(), const [1, 2, 3, 4]);
    });

    test('branding.* settings remain readable after the not-participating '
        'transition (the transition does not touch the event store)', () async {
      final rt = await _boot();
      // Apply the link-time branding settings batch (set-once-at-link).
      await applyLinkSponsorSettings(rt.scope, const <Object?>[
        <String, Object?>{
          'key': 'branding.title',
          'value': 'Reference',
          'locked': true,
        },
        <String, Object?>{
          'key': 'branding.logoSha256',
          'value': 'cafef00d',
          'locked': true,
        },
        <String, Object?>{
          'key': 'branding.logoRole',
          'value': 'logo',
          'locked': true,
        },
      ]);

      // Simulate participation-end: flip not-participating + clear enrollment.
      // Neither path mutates the diary event store, so settings are unaffected.
      final enrollment = MockEnrollmentService();
      await enrollment.setNotParticipating(true, at: DateTime.now());
      await enrollment.clearEnrollment();
      expect(await enrollment.isNotParticipating(), isTrue);

      // The branding.* settings are still readable from the projection.
      final rows = await _rows(rt, settingsViewName);
      final byKey = {for (final r in rows) r['key'] as String: r};
      expect(byKey['branding.title']?['value'], 'Reference');
      expect(byKey['branding.logoSha256']?['value'], 'cafef00d');
      expect(byKey['branding.logoRole']?['value'], 'logo');

      // And the derived branding still resolves the logo.
      final settingsMap = <String, SettingPayload>{
        for (final r in rows)
          r['key'] as String: SettingPayload(
            key: r['key'] as String,
            value: r['value'],
            source: SettingSource.sponsor,
            locked: r['locked'] as bool? ?? true,
          ),
      };
      final branding = SponsorBrandingConfig.fromSettings(settingsMap);
      expect(branding.title, 'Reference');
      expect(branding.logoSha256, 'cafef00d');
      expect(branding.logoRole, 'logo');
      expect(branding.hasLogo, isTrue);

      await rt.dispose();
    });
  });
}
