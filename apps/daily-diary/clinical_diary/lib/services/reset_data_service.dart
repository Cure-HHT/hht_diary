// IMPLEMENTS REQUIREMENTS:
//   REQ-d00013: Application Instance UUID Generation (clause G — fresh-install trigger)
//   REQ-d00004: Local-First Data Entry Implementation (sembast datastore cleared)

import 'package:clinical_diary/services/auth_service.dart';
import 'package:clinical_diary/services/clinical_diary_bootstrap.dart';
// Conditional import: stub on mobile/desktop, real wipe on web.
// dart.library.js_interop is the modern discriminator for package:web
// (mirrors the pattern in lib/utils/web_update_helper.dart).
import 'package:clinical_diary/services/reset_data_service_stub.dart'
    if (dart.library.js_interop) 'package:clinical_diary/services/reset_data_service_web.dart'
    as platform_reset;
import 'package:clinical_diary/services/task_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Orchestrates a "fresh install" wipe across every state store the app
/// touches. Tracking ticket: CUR-1315.
///
/// Cleanup order:
///   1. `AuthService.logout()` (defensive flush of in-memory auth flag).
///   2. `TaskService.clearAll()` (clears in-memory task list + its
///      SharedPreferences key).
///   3. `ClinicalDiaryRuntime.deleteDatabaseFiles()` (closes + deletes
///      the sembast event-sourcing datastore; file on native, IndexedDB
///      object store on web).
///   4. `FlutterSecureStorage().deleteAll()` (catch-all incl. `app_uuid`,
///      `auth_jwt`, `user_enrollment`).
///   5. `SharedPreferences.clear()` (catch-all).
///   6. Web only: `wipeWebOnlyState()` deletes `firebaseLocalStorageDb`
///      IndexedDB + clears localStorage / sessionStorage. This is where
///      Firebase Core/Messaging session state is evicted on web (the
///      app has no firebase_auth dependency, so step 1 is not the
///      Firebase signOut the name might suggest).
///
/// Dev/qa/uat only — gated upstream by `F.showResetData`. Not safe to
/// call while a sync is in flight (Tier 3 of CUR-1315 will add a queue
/// check). After a successful reset the runtime is unusable; the caller
/// must navigate to onboarding before any further widget.runtime access
/// (Tier 1.5 of CUR-1315 will add an explicit runtime re-bootstrap).
class ResetDataService {
  ResetDataService({
    required AuthService authService,
    required TaskService taskService,
    required ClinicalDiaryRuntime runtime,
    FlutterSecureStorage? secureStorage,
  }) : _authService = authService,
       _taskService = taskService,
       _runtime = runtime,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final AuthService _authService;
  final TaskService _taskService;
  final ClinicalDiaryRuntime _runtime;
  final FlutterSecureStorage _secureStorage;

  /// Wipe everything. `AuthService.logout` (a flag flip in secure storage)
  /// runs first as a defensive flush in case future auth wiring adds
  /// shutdown writes; today it is redundant with the later
  /// `secureStorage.deleteAll`. Catch-all wipes (`secureStorage.deleteAll`,
  /// `prefs.clear`) run at the end so anything the per-service clears
  /// write is also caught.
  ///
  /// On web, `platform_reset.wipeWebOnlyState()` additionally deletes the
  /// `firebaseLocalStorageDb` IndexedDB and clears localStorage /
  /// sessionStorage — state that survives flutter_secure_storage.deleteAll()
  /// and SharedPreferences.clear() in the browser. This is where Firebase
  /// Core/Messaging session state (the design spec's original "Firebase
  /// signOut" framing) is actually evicted in this codebase, since the app
  /// has no firebase_auth dependency.
  Future<void> resetEverything() async {
    await _authService.logout();
    await _taskService.clearAll();
    await _runtime.deleteDatabaseFiles();
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await platform_reset.wipeWebOnlyState();
  }
}
