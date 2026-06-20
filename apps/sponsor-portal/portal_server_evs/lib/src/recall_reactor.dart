// Implements: DIARY-DEV-outgoing-intent-correlation/A+C
//   Enriches questionnaire_called_back (which carries only {by, reason}) into a
//   questionnaire_recall_notice that carries participant_id + study_event +
//   the echoed flow token. That notice drives both the silent push (notification
//   reactor intent) and the participant-facing recall_notice projection.
import 'dart:async';
import 'dart:io';

import 'package:event_sourcing/event_sourcing.dart';

class RecallReactor {
  RecallReactor({required this.eventStore, required this.backend});
  final EventStore eventStore;
  final StorageBackend backend;
  StreamSubscription<Update<StoredEvent>>? _sub;

  void start() {
    _sub = eventStore
        .subscribe<StoredEvent>(
      const SubscriptionFilter(
        aggregateTypes: {'questionnaire_instance'},
        eventTypes: {'questionnaire_called_back'},
      ),
      const Events(),
    )
        .listen((update) {
      if (update is Delta<StoredEvent>) {
        unawaited(handleCalledBack(update.value)
            .catchError((Object e, StackTrace st) {
          stderr.writeln(
              'RecallReactor.handleCalledBack failed (continuing): $e\n$st');
        }));
      }
    }, onError: (Object e, StackTrace st) {
      stderr.writeln('RecallReactor subscription error (continuing): $e\n$st');
    });
  }

  // Implements: DIARY-DEV-outgoing-intent-correlation/A+C
  Future<void> handleCalledBack(StoredEvent event) async {
    final instanceId = event.aggregateId;

    // Resolve participant_id + study_event from the instance's assigned event
    // (durable; independent of the now-tombstoned questionnaire_instance view).
    final history = await backend.findEventsForAggregate(instanceId);
    StoredEvent? assigned;
    for (final e in history) {
      if (e.entryType == 'questionnaire_assigned') {
        assigned = e;
        break;
      }
    }
    if (assigned == null) {
      return; // no assignment to recall — nothing to notify.
    }
    final participantId = assigned.data['participant_id'] as String?;
    if (participantId == null) return;
    final studyEvent = assigned.data['study_event'];

    final recallAggId = '$participantId:recall:$instanceId';

    // Idempotency: skip if a notice already exists for this recall aggregate.
    final existing = await backend.findEventsForAggregate(recallAggId);
    if (existing.any((e) => e.entryType == 'questionnaire_recall_notice')) {
      return;
    }

    await eventStore.append(
      entryType: 'questionnaire_recall_notice',
      aggregateType: 'questionnaire_recall_notice',
      aggregateId: recallAggId,
      eventType: 'questionnaire_recall_notice',
      flowToken: event.flowToken,
      data: <String, Object?>{
        'participant_id': participantId,
        'instance_id': instanceId,
        'study_event': studyEvent,
        'recalled_at': event.clientTimestamp.toUtc().toIso8601String(),
        'flow_token': event.flowToken,
      },
      initiator: const AutomationInitiator(service: 'recall'),
    );
  }

  Future<void> stop() async => _sub?.cancel();
}
