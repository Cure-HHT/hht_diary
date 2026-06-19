import 'dart:io';

import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/task_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Performs a full local factory reset: wipes ALL on-device diary state so the
/// app returns to its first-launch condition.
///
/// **Precondition:** the EventStore backing the Sembast store (`diary_es.db`)
/// MUST already be CLOSED before calling this. Sembast holds the database file
/// open while a `Database` is live, so the caller is responsible for disposing
/// the `DiaryScopeRuntime` (which closes its store) BEFORE invoking
/// [wipeLocalData]. Deleting an open file silently fails (or leaks a handle) on
/// some platforms.
///
/// The wipe is step-by-step and resilient: a failure deleting one file is
/// caught and logged, and the remaining steps still run, so a single locked
/// file cannot leave the app half-wired. The caller re-initializes the runtime
/// after this returns.
///
/// Steps:
/// 1. Delete the event store `diary_es.db`.
/// 2. Clear secure storage except the stable install id
///    ([EnrollmentService.clearSecureStorageForFactoryReset] — drops
///    enrollment, the session JWT, and `auth_*` keys, keeps `app_uuid`).
/// 3. Clear cached tasks ([TaskService.clearAll]).
/// 4. Clear ALL SharedPreferences ([SharedPreferences.clear]) — wipes the
///    device id, disconnection / not-participating flags, and any other diary
///    prefs, so re-init mints a fresh device id.
// Implements: DIARY-BASE-local-data-reset/A
Future<void> wipeLocalData({
  required String documentsPath,
  required EnrollmentService enrollmentService,
  required TaskService taskService,
  required SharedPreferences prefs,
}) async {
  // 1: delete the event store file. Guard with existsSync so a missing/locked
  // file does not abort the rest of the wipe.
  try {
    final file = File('$documentsPath/diary_es.db');
    if (file.existsSync()) {
      await file.delete();
    }
  } catch (e, stack) {
    debugPrint('[LocalDataReset] delete(diary_es.db) failed: $e\n$stack');
  }

  // 3: clear secure storage except the stable install id (app_uuid).
  try {
    await enrollmentService.clearSecureStorageForFactoryReset();
  } catch (e, stack) {
    debugPrint('[LocalDataReset] secure-storage wipe failed: $e\n$stack');
  }

  // 4: clear cached tasks.
  try {
    await taskService.clearAll();
  } catch (e, stack) {
    debugPrint('[LocalDataReset] clearAll failed: $e\n$stack');
  }

  // 5: clear all prefs (true factory reset — device id + flags + everything).
  try {
    await prefs.clear();
  } catch (e, stack) {
    debugPrint('[LocalDataReset] prefs.clear failed: $e\n$stack');
  }
}
