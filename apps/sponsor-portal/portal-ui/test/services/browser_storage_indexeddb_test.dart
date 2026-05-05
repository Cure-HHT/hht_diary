@TestOn('browser')
library;

// Chrome-platform test for BrowserStorageService.clearStorage().
//
// CUR-1280 Task 1.3: locks down the bounded-time guarantee on the IndexedDB
// delete path. The previous _clearIndexedDB issued deleteDatabase requests
// fire-and-forget; for any DB with an open connection (e.g. Firebase Auth's
// firebaseLocalStorageDb), the request transitions to `blocked` and the
// caller is left blocked indefinitely if it ever tries to await the result.
//
// This test opens a fixture IndexedDB and KEEPS THE CONNECTION OPEN for the
// duration of the test, then calls clearStorage() with a 2-second timeout.
// Pre-fix expectation: the call hangs and the timeout fires.
// Post-fix expectation: the call completes well under 2s, having logged a
// "blocked" / "timed out" debug message and moved on.
//
// Lives in its own file because @TestOn is a file-level annotation; the
// existing browser_storage_test.dart targets the dart VM and exercises the
// AuthService injection contract.
//
// IMPLEMENTS REQUIREMENTS (parent-repo / hht_diary):
//   REQ-d00083-D: clear IndexedDB databases on logout
//   REQ-d00083-I: clear IndexedDB databases on session timeout
//   REQ-d00083-N: clear IndexedDB databases on browser close
//   REQ-p01044-M: no patient data recoverable from browser after logout
//
// Per CHECKLIST §3: REQ-p01044 lives in hht_diary/spec/prd-diary-web.md and
// REQ-d00083 in hht_diary/spec/dev-diary-web.md (both confirmed). The
// elspais MCP graph in this worktree is callisto-scoped (REQ-CAL-*), so the
// hashes for these parent-repo REQs are not auto-tracked here; that is
// expected and acknowledged.

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:sponsor_portal_ui/services/browser_storage_service.dart';
import 'package:web/web.dart' as web;

const _fixtureDbName = 'cur1280-fixture';

void main() {
  group('BrowserStorageService.clearStorage IndexedDB delete', () {
    late web.IDBDatabase fixtureDb;

    setUp(() async {
      // Best-effort: clear any leftover fixture from a prior run before the
      // test creates a new connection. We don't await the result — if a
      // previous run left the DB orphaned with no connections, this just
      // succeeds; if a connection somehow survived, the new open() below
      // will still proceed because we use the same name+version.
      web.window.indexedDB.deleteDatabase(_fixtureDbName);

      final completer = Completer<web.IDBDatabase>();
      final openReq = web.window.indexedDB.open(_fixtureDbName, 1);
      openReq.onupgradeneeded = ((web.Event _) {
        final db = openReq.result as web.IDBDatabase;
        db.createObjectStore('s');
      }).toJS;
      openReq.onsuccess = ((web.Event _) {
        if (!completer.isCompleted) {
          completer.complete(openReq.result as web.IDBDatabase);
        }
      }).toJS;
      openReq.onerror = ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('Failed to open fixture IndexedDB $_fixtureDbName'),
          );
        }
      }).toJS;
      openReq.onblocked = ((web.Event _) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('Fixture IndexedDB open blocked unexpectedly'),
          );
        }
      }).toJS;

      fixtureDb = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError(
          'Fixture IndexedDB open timed out — environment cannot run this test',
        ),
      );
    });

    tearDown(() {
      // Always release the fixture connection so a subsequent run can re-open.
      try {
        fixtureDb.close();
      } catch (_) {
        // Already closed — ignore.
      }
      // Best-effort cleanup. We don't await — the production fix already
      // proves bounded-time deletion when a connection holds a DB open, so
      // there's no value in blocking teardown on it.
      web.window.indexedDB.deleteDatabase(_fixtureDbName);
    });

    test('awaits a blocked IndexedDB delete in bounded time '
        '(does not return instantly without trying)', () async {
      // Sanity: the fixture connection is alive. If this becomes flaky on
      // some browsers the test should fail loudly here rather than mask
      // the production bug.
      expect(fixtureDb.name, equals(_fixtureDbName));

      final svc = BrowserStorageService();

      // The post-fix _clearIndexedDB issues deleteDatabase, attaches
      // success/error/blocked listeners, and awaits the resulting request
      // with a per-DB timeout (~800ms). With our fixture connection held
      // open, the delete WILL be blocked, so post-fix the call resolves
      // when the per-DB timeout fires.
      //
      // The pre-fix _clearIndexedDB calls deleteDatabase fire-and-forget
      // and returns ~immediately — meaning clearStorage() never actually
      // waits for the delete to be attempted. That's the bug.
      //
      // We assert two things:
      //   (1) the call completes within 2s (post-fix bounded-time
      //       guarantee — a future regression that awaited forever would
      //       fail this);
      //   (2) the call took at least 200ms (proves it actually awaited
      //       the blocked delete; pre-fix returns in <50ms because it
      //       doesn't await anything in the IDB path).
      final stopwatch = Stopwatch()..start();
      await svc.clearStorage().timeout(
        const Duration(seconds: 2),
        onTimeout: () => fail(
          'clearStorage() did not complete within 2s while a fixture '
          'IndexedDB connection was held open — bounded-time guarantee '
          'broken (REQ-d00083-D/I/N, REQ-p01044-M).',
        ),
      );
      stopwatch.stop();

      // 200ms is well below the 800ms per-DB timeout in `_deleteDatabase`,
      // so the post-fix elapsed (~800ms) clears it with margin. The lower
      // bound only false-positives if the fixture connection somehow
      // closed before `clearStorage()` issued its delete — but `fixtureDb`
      // is held open by `setUp` and `tearDown` is the only close path,
      // and `tearDown` runs AFTER this body. Under defined test
      // conditions `deleteDatabase` is therefore guaranteed to be
      // `blocked` and the 800ms timeout is the only path to resolution,
      // so this floor cannot be reached without the fix.
      expect(
        stopwatch.elapsedMilliseconds,
        greaterThanOrEqualTo(200),
        reason:
            'clearStorage() returned in ${stopwatch.elapsedMilliseconds}ms — '
            'too fast to have awaited the IndexedDB delete request. The '
            'pre-CUR-1280 implementation issued deleteDatabase() without '
            'awaiting the IDBOpenDBRequest, so the IndexedDB was not '
            'actually deleted by the time clearStorage() resolved. The fix '
            'must await each delete (with a per-DB timeout to handle '
            'blocked requests). REQ-d00083-D/I/N, REQ-p01044-M.',
      );
    });
  });
}
