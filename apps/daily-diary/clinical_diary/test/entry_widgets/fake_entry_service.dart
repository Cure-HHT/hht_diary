// Verifies: REQ-p00006-A+B; REQ-d00004-E+F+G; REQ-p01067-A+B+C.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';

/// Lightweight fake `EntryRecorder` function used in widget tests.
///
/// Usage:
/// ```dart
/// final fake = FakeEntryService();
/// final ctx = EntryWidgetContext(..., recorder: fake.record);
/// ```
///
/// Every call to `fake.record(...)` is captured in [calls] so tests can
/// assert on the exact arguments.
class FakeEntryService {
  final List<RecordCall> calls = [];

  /// Optional override for the return value of the next call.
  StoredEvent? nextResult;

  /// An `EntryRecorder`-compatible closure that records each invocation.
  Future<StoredEvent?> Function({
    required String entryType,
    required String aggregateId,
    required String eventType,
    required Map<String, Object?> answers,
    String? checkpointReason,
    String? changeReason,
  })
  get record => _record;

  Future<StoredEvent?> _record({
    required String entryType,
    required String aggregateId,
    required String eventType,
    required Map<String, Object?> answers,
    String? checkpointReason,
    String? changeReason,
  }) async {
    calls.add(
      RecordCall(
        entryType: entryType,
        aggregateId: aggregateId,
        eventType: eventType,
        answers: Map.unmodifiable(answers),
        checkpointReason: checkpointReason,
        changeReason: changeReason,
      ),
    );
    final result = nextResult;
    nextResult = null; // consume once
    return result;
  }

  /// Clears recorded calls.
  void reset() => calls.clear();
}

/// Value object capturing one `EntryRecorder` invocation.
class RecordCall {
  const RecordCall({
    required this.entryType,
    required this.aggregateId,
    required this.eventType,
    required this.answers,
    this.checkpointReason,
    this.changeReason,
  });

  final String entryType;
  final String aggregateId;
  final String eventType;
  final Map<String, Object?> answers;
  final String? checkpointReason;
  final String? changeReason;

  @override
  String toString() =>
      'RecordCall('
      'entryType: $entryType, '
      'aggregateId: $aggregateId, '
      'eventType: $eventType, '
      'answers: $answers, '
      'changeReason: $changeReason)';
}
