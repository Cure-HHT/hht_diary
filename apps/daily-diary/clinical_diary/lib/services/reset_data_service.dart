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
/// touches. See docs/superpowers/specs/2026-05-10-cur-1315-reset-all-data-design.md
/// for the cleanup matrix and ordering rationale.
///
/// Dev/qa/uat only — gated upstream by `F.showResetData`. Not safe to call
/// while a sync is in flight (Tier 3 of CUR-1315 will add a queue check).
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

  /// Wipe everything. Ordering matters — auth logout MUST precede the
  /// storage wipes so any auth library that writes state during shutdown
  /// has already flushed before we delete the underlying stores. Catch-all
  /// wipes (`secureStorage.deleteAll`, `prefs.clear`) run at the end so
  /// anything the per-service clears write is also caught.
  ///
  /// On web, `platform_reset.wipeWebOnlyState()` additionally deletes the
  /// `firebaseLocalStorageDb` IndexedDB and clears localStorage /
  /// sessionStorage — state that survives flutter_secure_storage.deleteAll()
  /// and SharedPreferences.clear() in the browser.
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
