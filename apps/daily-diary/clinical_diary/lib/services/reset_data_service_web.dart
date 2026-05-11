// IMPLEMENTS REQUIREMENTS:
//   REQ-d00013: Application Instance UUID Generation (clause G — fresh-install trigger)
//   REQ-d00004: Local-First Data Entry Implementation (sembast datastore cleared)

// Web-only — selected via conditional import in reset_data_service.dart.
// Wipes browser state that is NOT owned by flutter_secure_storage or
// SharedPreferences, namely Firebase Auth's own IndexedDB and any
// app-written localStorage/sessionStorage entries.
//
// Uses package:web (the modern dart:js_interop-based API) to match the
// project's existing web helpers (see lib/utils/web_update_helper_web.dart).
// dart:html / dart:indexed_db are deprecated and not used in this project.

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web/web.dart' as web;

/// Delete browser-only state that survives flutter_secure_storage.deleteAll()
/// and SharedPreferences.clear(): Firebase Auth's IndexedDB + localStorage +
/// sessionStorage. Runs after AuthService.logout() so any auth library that
/// writes state during shutdown has already flushed.
Future<void> wipeWebOnlyState() async {
  await _deleteIndexedDb('firebaseLocalStorageDb');
  try {
    web.window.localStorage.clear();
  } catch (_) {
    // Some sandboxed contexts (e.g. file:// origins in tests) deny
    // localStorage; treat as no-op rather than failing the whole reset.
  }
  try {
    web.window.sessionStorage.clear();
  } catch (_) {
    // Same rationale as localStorage above.
  }
}

Future<void> _deleteIndexedDb(String name) async {
  final completer = Completer<void>();
  try {
    web.window.indexedDB.deleteDatabase(name)
      ..onsuccess = (web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }.toJS
      ..onerror = (web.Event event) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception('IndexedDB deleteDatabase($name) error'),
          );
        }
      }.toJS
      ..onblocked = ((web.Event _) {
        debugPrint(
          '[ResetDataService] IndexedDB delete of $name blocked; another '
          'connection holds the DB open. Completing optimistically — the '
          'browser will delete it once the other connection closes.',
        );
        if (!completer.isCompleted) completer.complete();
      }).toJS;
  } catch (e) {
    // No IndexedDB available (e.g. file:// origin); nothing to delete.
    return;
  }
  await completer.future
      .timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // A blocked deletion (open connection from another tab) is unusual
          // for a "Reset All Data" tap in our single-tab flow. Log via
          // debugPrint so test output captures it; do not throw.
          debugPrint('[ResetDataService] IndexedDB delete of $name timed out');
          if (!completer.isCompleted) completer.complete();
        },
      )
      .catchError((Object e) {
        // Log the error but do not propagate — a failed IndexedDB delete
        // is non-fatal for the overall reset; the other stores are already
        // cleared.
        debugPrint('[ResetDataService] IndexedDB delete of $name failed: $e');
      });
}
