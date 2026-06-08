// Debug-only Study-Coordinator read of a participant's diary entries, sorted by
// CLINICAL event date (canonicalEntryDate), not the action timestamp. Not a
// product surface; gated by the ACT-SEE-004 portal.diary.view_entries permission.
import 'dart:convert';

import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:shelf/shelf.dart';

/// Permission that gates the debug diary-entries read (held by StudyCoordinator).
const String diaryDebugViewPermission = 'portal.diary.view_entries';

/// Shared core: read the canonical `diary_entries` view, keep only [participant]'s
/// rows, and sort them ascending by clinical event date (the entry's own captured
/// date via [canonicalEntryDate]) rather than the finalize/append order. 400 when
/// [participant] is null or empty.
Future<Response> respondWithDiaryEntries(
    EventStore eventStore, String? participant) async {
  if (participant == null || participant.isEmpty) {
    return Response(400, body: 'requires a participant query parameter');
  }
  final rows = await eventStore.backend.findViewRows(diaryEntriesViewName);
  final mine = rows.where((row) => row['participantId'] == participant).toList()
    ..sort((a, b) {
      final da = canonicalEntryDate(a['entryType'] as String? ?? '', a) ?? '';
      final db = canonicalEntryDate(b['entryType'] as String? ?? '', b) ?? '';
      return da.compareTo(db);
    });
  return Response.ok(
    jsonEncode(<String, Object?>{'rows': mine, 'count': mine.length}),
    headers: const {'Content-Type': 'application/json'},
  );
}

/// Test seam: the sort/filter core wired to a [Handler] WITHOUT auth (always
/// allowed), so the ordering + filtering logic is unit-testable without the
/// auth middleware. Production gating lives in the bootstrap route — never wire
/// this seam into a served pipeline. Intentionally NOT exported from the package
/// barrel; the test imports it via the `src/` path.
Handler diaryEntriesDebugHandlerForTest(EventStore eventStore) =>
    (Request request) => respondWithDiaryEntries(
        eventStore, request.url.queryParameters['participant']);
