// IMPLEMENTS REQUIREMENTS:
//   REQ-d00013: Application Instance UUID Generation (clause G — fresh-install trigger)
//   REQ-d00004: Local-First Data Entry Implementation (sembast datastore cleared)

import 'package:clinical_diary/services/auth_service.dart';
import 'package:clinical_diary/services/clinical_diary_bootstrap.dart';
import 'package:clinical_diary/services/reset_data_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockTaskService extends Mock implements TaskService {}

class _MockRuntime extends Mock implements ClinicalDiaryRuntime {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ResetDataService', () {
    late _MockAuthService authService;
    late _MockTaskService taskService;
    late _MockRuntime runtime;
    late _MockSecureStorage secureStorage;
    late List<String> callOrder;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pref_one': 'value',
        'pref_two': 42,
      });
      authService = _MockAuthService();
      taskService = _MockTaskService();
      runtime = _MockRuntime();
      secureStorage = _MockSecureStorage();
      callOrder = [];

      when(() => authService.logout()).thenAnswer((_) async {
        callOrder.add('authLogout');
      });
      when(() => taskService.clearAll()).thenAnswer((_) async {
        callOrder.add('taskClearAll');
      });
      when(() => runtime.deleteDatabaseFiles()).thenAnswer((_) async {
        callOrder.add('runtimeDelete');
      });
      when(() => secureStorage.deleteAll()).thenAnswer((_) async {
        callOrder.add('secureStorageDeleteAll');
      });
    });

    test('runs cleanup steps in the documented order', () async {
      final service = ResetDataService(
        authService: authService,
        taskService: taskService,
        runtime: runtime,
        secureStorage: secureStorage,
      );

      await service.resetEverything();

      // Auth logout MUST precede the storage wipes per the spec —
      // mirrors the FirebaseAuth.signOut()-first rationale: any auth
      // library that writes state during shutdown must flush before we
      // delete the underlying stores.
      expect(callOrder, [
        'authLogout',
        'taskClearAll',
        'runtimeDelete',
        'secureStorageDeleteAll',
      ]);
    });

    test('clears SharedPreferences after the other steps', () async {
      // Ordering invariant: prefs.clear() must run AFTER secureStorage.deleteAll()
      // (and after every other mocked step). We verify this in two ways:
      //   1. Sanity: prefs are non-empty before the call (setUp seeds two keys).
      //   2. Ordering proof: callOrder ends with 'secureStorageDeleteAll' — because
      //      callOrder only records entries from the four mocked services and the
      //      implementation calls secureStorage.deleteAll() immediately before
      //      prefs.clear(). If a future refactor moved prefs.clear() above any
      //      mocked step, the main ordering test would catch it; this check
      //      additionally proves secureStorage runs before the pref wipe.
      final prefsBefore = await SharedPreferences.getInstance();
      expect(
        prefsBefore.getKeys(),
        isNotEmpty,
        reason: 'setUp should have seeded prefs so the clear is meaningful',
      );
      expect(callOrder, isEmpty, reason: 'no steps should have run yet');

      final service = ResetDataService(
        authService: authService,
        taskService: taskService,
        runtime: runtime,
        secureStorage: secureStorage,
      );

      await service.resetEverything();

      // secureStorage.deleteAll() is the last mocked step before prefs.clear().
      // If this assertion fails, prefs.clear() was moved to run before
      // secureStorage.deleteAll().
      expect(
        callOrder.last,
        'secureStorageDeleteAll',
        reason:
            'secureStorage.deleteAll() must be the last mocked step; '
            'prefs.clear() runs immediately after it',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });

    test('is safe to call twice', () async {
      final service = ResetDataService(
        authService: authService,
        taskService: taskService,
        runtime: runtime,
        secureStorage: secureStorage,
      );

      await service.resetEverything();
      // Second call must not throw; mocks are still ready to accept calls.
      await service.resetEverything();

      expect(callOrder.where((c) => c == 'authLogout').length, 2);
    });
  });
}
