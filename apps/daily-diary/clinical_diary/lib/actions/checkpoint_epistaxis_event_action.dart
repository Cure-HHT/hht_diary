// Implements: DIARY-PRD-incomplete-entry-preservation/A+C+D — preserves a
//   partial nosebleed as a resumable, diary-LOCAL draft (a `checkpoint`). A
//   later `finalized` on the same aggregate promotes it and self-removes the
//   draft (diaryIncompleteProjection tombstones on `finalized`); checkpoints are
//   never part of the shared canonical view (frozen surface P6).
// Implements: DIARY-DEV-action-write-path/A
//
// Per-app diary Action: the checkpoint producer the incomplete projection was
// built for. Emits one `checkpoint` `epistaxis_event` — for a new draft on a
// freshly-minted aggregate, or on the SAME aggregate when resuming an existing
// draft. Same layering as RecordEpistaxisEventAction (pure structural validate;
// a draft may legitimately omit endTime/intensity).
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:uuid/uuid.dart';

/// Parsed input: the (possibly partial) nosebleed payload, an optional existing
/// [aggregateId] (null = a brand-new draft → mint a fresh id), and an optional
/// [checkpointReason] (e.g. why the draft was auto-saved).
class CheckpointEpistaxisInput {
  const CheckpointEpistaxisInput({
    required this.payload,
    this.aggregateId,
    this.checkpointReason,
  });

  final EpistaxisEventPayload payload;
  final String? aggregateId;
  final String? checkpointReason;
}

/// Checkpoints a nosebleed draft. Returns the aggregate id (minted for a new
/// draft, unchanged when resuming).
class CheckpointEpistaxisEventAction
    extends Action<CheckpointEpistaxisInput, String> {
  const CheckpointEpistaxisEventAction({Uuid? uuid}) : _uuid = uuid;

  final Uuid? _uuid;

  @override
  String get name => 'checkpoint_epistaxis_event';

  @override
  String get description =>
      'Participant auto-saves a partial nosebleed as a resumable draft '
      '(checkpoint epistaxis_event).';

  @override
  Set<Permission> get permissions => <Permission>{
    const Permission('diary.record_entry'),
  };

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  CheckpointEpistaxisInput parseInput(Map<String, Object?> raw) {
    final aggregateId = raw['aggregateId'];
    if (aggregateId != null &&
        (aggregateId is! String || aggregateId.isEmpty)) {
      throw const FormatException(
        'aggregateId must be a non-empty string when supplied',
      );
    }
    final EpistaxisEventPayload payload;
    try {
      payload = EpistaxisEventPayload.fromJson(raw);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('invalid epistaxis_event payload: $e');
    }
    final reason = raw['checkpointReason'];
    if (reason != null && reason is! String) {
      throw const FormatException('checkpointReason must be a string');
    }
    return CheckpointEpistaxisInput(
      payload: payload,
      aggregateId: aggregateId as String?,
      checkpointReason: reason as String?,
    );
  }

  @override
  void validate(CheckpointEpistaxisInput input) {
    final start = DateTime.tryParse(input.payload.startTime);
    if (start == null) {
      throw ArgumentError.value(
        input.payload.startTime,
        'startTime',
        'must be an ISO 8601 timestamp',
      );
    }
    final endRaw = input.payload.endTime;
    if (endRaw != null) {
      final end = DateTime.tryParse(endRaw);
      if (end == null) {
        throw ArgumentError.value(
          endRaw,
          'endTime',
          'must be an ISO 8601 timestamp',
        );
      }
      if (!end.isAfter(start)) {
        throw ArgumentError.value(endRaw, 'endTime', 'must be after startTime');
      }
    }
  }

  @override
  Future<ExecutionResult<String>> execute(
    CheckpointEpistaxisInput input,
    ActionContext ctx,
  ) async {
    final aggregateId = input.aggregateId ?? (_uuid ?? const Uuid()).v4();
    final data = <String, Object?>{
      ...input.payload.toJson(),
      if (input.checkpointReason != null)
        'checkpointReason': input.checkpointReason,
    };
    return ExecutionResult<String>(
      result: aggregateId,
      events: <EventDraft>[
        EventDraft(
          aggregateType: diaryEntryAggregateType,
          aggregateId: aggregateId,
          entryType: 'epistaxis_event',
          eventType: 'checkpoint',
          data: data,
        ),
      ],
    );
  }
}
