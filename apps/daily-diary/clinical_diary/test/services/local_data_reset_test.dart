// Verifies: DIARY-BASE-local-data-reset/A — wipeLocalData deletes both store
//   files, clears enrollment + tasks, and wipes SharedPreferences so the app
//   returns to first-launch state.
import 'dart:io';

import 'package:clinical_diary/services/local_data_reset.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_enrollment_service.dart';

/// EnrollmentService spy recording whether the factory-reset secure wipe ran.
class _SpyEnrollmentService extends MockEnrollmentService {
  bool factoryResetCalled = false;

  @override
  Future<void> clearSecureStorageForFactoryReset() async {
    factoryResetCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('wipeLocalData', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('local_reset_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'deletes both store files, clears enrollment/tasks, and clears prefs',
      () async {
        // Seed fake store files in the temp documents dir.
        final esFile = File('${tempDir.path}/diary_es.db')
          ..writeAsStringSync('es-store');
        final legacyFile = File('${tempDir.path}/diary.db')
          ..writeAsStringSync('legacy-store');
        expect(esFile.existsSync(), isTrue);
        expect(legacyFile.existsSync(), isTrue);

        // Seed prefs (incl. a device id) so we can assert they are wiped.
        SharedPreferences.setMockInitialValues({
          'clinical_diary.device_id': 'device-abc',
          'some_other_pref': true,
        });
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('clinical_diary.device_id'), 'device-abc');

        final enrollment = _SpyEnrollmentService();
        final tasks = TaskService();
        addTearDown(tasks.dispose);

        await wipeLocalData(
          documentsPath: tempDir.path,
          enrollmentService: enrollment,
          taskService: tasks,
          prefs: prefs,
        );

        // Both store files deleted.
        expect(esFile.existsSync(), isFalse);
        expect(legacyFile.existsSync(), isFalse);

        // Enrollment cleared.
        expect(enrollment.factoryResetCalled, isTrue);

        // Prefs fully wiped (device id + other prefs gone).
        expect(prefs.getString('clinical_diary.device_id'), isNull);
        expect(prefs.getBool('some_other_pref'), isNull);
        expect(prefs.getKeys(), isEmpty);
      },
    );

    test('tolerates missing store files (no throw)', () async {
      // No store files seeded — wipe must still complete.
      SharedPreferences.setMockInitialValues({'k': 'v'});
      final prefs = await SharedPreferences.getInstance();
      final enrollment = _SpyEnrollmentService();
      final tasks = TaskService();
      addTearDown(tasks.dispose);

      await wipeLocalData(
        documentsPath: tempDir.path,
        enrollmentService: enrollment,
        taskService: tasks,
        prefs: prefs,
      );

      expect(enrollment.factoryResetCalled, isTrue);
      expect(prefs.getKeys(), isEmpty);
    });
  });
}
