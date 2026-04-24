import 'package:event_sourcing_datastore/src/destinations/subscription_filter.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:flutter_test/flutter_test.dart';

StoredEvent _mkEvent({
  String entryType = 'epistaxis_event',
  String eventType = 'finalized',
  String eventId = 'ev-1',
}) => StoredEvent(
  key: 1,
  eventId: eventId,
  aggregateId: 'agg-1',
  aggregateType: 'DiaryEntry',
  entryType: entryType,
  eventType: eventType,
  sequenceNumber: 1,
  data: const <String, dynamic>{},
  metadata: const <String, dynamic>{},
  initiator: const UserInitiator('u1'),
  clientTimestamp: DateTime.utc(2026, 4, 22),
  eventHash: 'hash',
);

void main() {
  group('SubscriptionFilter', () {
    // Verifies: REQ-d00122-F — absent allow-list (null) matches every event.
    test('REQ-d00122-F: null lists match everything', () {
      const f = SubscriptionFilter();
      expect(f.matches(_mkEvent()), isTrue);
      expect(
        f.matches(
          _mkEvent(entryType: 'nose_hht_survey', eventType: 'tombstone'),
        ),
        isTrue,
      );
    });

    // Verifies: REQ-d00122-F — entryTypes allow-list filters by entry_type.
    test('REQ-d00122-F: entryTypes allow-list selects by entry_type', () {
      const f = SubscriptionFilter(entryTypes: ['epistaxis_event']);
      expect(f.matches(_mkEvent(entryType: 'epistaxis_event')), isTrue);
      expect(f.matches(_mkEvent(entryType: 'nose_hht_survey')), isFalse);
    });

    // Verifies: REQ-d00122-F — eventTypes allow-list filters by event_type.
    test('REQ-d00122-F: eventTypes allow-list selects by event_type', () {
      const f = SubscriptionFilter(eventTypes: ['finalized']);
      expect(f.matches(_mkEvent(eventType: 'finalized')), isTrue);
      expect(f.matches(_mkEvent(eventType: 'checkpoint')), isFalse);
      expect(f.matches(_mkEvent(eventType: 'tombstone')), isFalse);
    });

    // Intersection: both allow-lists must match when both are set.
    test('REQ-d00122-F: entryTypes AND eventTypes — both must match', () {
      const f = SubscriptionFilter(
        entryTypes: ['epistaxis_event'],
        eventTypes: ['finalized'],
      );
      expect(
        f.matches(
          _mkEvent(entryType: 'epistaxis_event', eventType: 'finalized'),
        ),
        isTrue,
      );
      expect(
        f.matches(
          _mkEvent(entryType: 'epistaxis_event', eventType: 'checkpoint'),
        ),
        isFalse,
      );
      expect(
        f.matches(
          _mkEvent(entryType: 'nose_hht_survey', eventType: 'finalized'),
        ),
        isFalse,
      );
    });

    // REQ-d00122-F distinguishes absent (null = match all) from empty
    // (list of length 0 = match nothing). This guards the foot-gun where
    // an unintended `[]` default would accept an event by accident.
    test('REQ-d00122-F: empty entryTypes list matches nothing '
        '(distinct from null)', () {
      const emptyEntryTypes = SubscriptionFilter(entryTypes: []);
      expect(emptyEntryTypes.matches(_mkEvent()), isFalse);
      expect(
        emptyEntryTypes.matches(_mkEvent(entryType: 'nose_hht_survey')),
        isFalse,
      );
    });

    test('REQ-d00122-F: empty eventTypes list matches nothing '
        '(distinct from null)', () {
      const emptyEventTypes = SubscriptionFilter(eventTypes: []);
      expect(emptyEventTypes.matches(_mkEvent()), isFalse);
      expect(
        emptyEventTypes.matches(_mkEvent(eventType: 'tombstone')),
        isFalse,
      );
    });

    // Verifies: REQ-d00122-F — predicate is consulted after allow-lists
    // pass; a predicate returning false blocks the event.
    test('REQ-d00122-F: predicate escape-hatch filters further', () {
      final f = SubscriptionFilter(
        predicate: (event) => event.eventId == 'ev-allow',
      );
      expect(f.matches(_mkEvent(eventId: 'ev-allow')), isTrue);
      expect(f.matches(_mkEvent(eventId: 'ev-block')), isFalse);
    });

    // Short-circuit: if the allow-lists fail, the predicate MUST NOT be
    // invoked. This matters when the predicate is expensive (e.g., hits
    // a registry lookup).
    test('REQ-d00122-F: predicate is not invoked when allow-lists fail', () {
      var predicateCalls = 0;
      final f = SubscriptionFilter(
        entryTypes: const ['epistaxis_event'],
        predicate: (event) {
          predicateCalls += 1;
          return true;
        },
      );
      expect(f.matches(_mkEvent(entryType: 'nose_hht_survey')), isFalse);
      expect(predicateCalls, 0);

      // Sanity: the predicate IS invoked when allow-lists pass.
      expect(f.matches(_mkEvent(entryType: 'epistaxis_event')), isTrue);
      expect(predicateCalls, 1);
    });

    // All three constraints compose: entryTypes + eventTypes + predicate.
    test('REQ-d00122-F: all three constraints compose (AND)', () {
      final f = SubscriptionFilter(
        entryTypes: const ['epistaxis_event'],
        eventTypes: const ['finalized'],
        predicate: (event) => event.aggregateId == 'agg-1',
      );
      final match = _mkEvent(
        entryType: 'epistaxis_event',
        eventType: 'finalized',
      );
      expect(f.matches(match), isTrue);
    });

    // Default filter — no constraints at all — is functionally "match
    // everything"; equivalent to REQ-d00122-B's any-event behavior.
    test('default SubscriptionFilter (no constraints) matches everything', () {
      const f = SubscriptionFilter();
      for (final entry in ['epistaxis_event', 'nose_hht_survey', 'random']) {
        for (final event in ['finalized', 'checkpoint', 'tombstone']) {
          expect(
            f.matches(_mkEvent(entryType: entry, eventType: event)),
            isTrue,
            reason: 'entry=$entry event=$event should match',
          );
        }
      }
    });
  });
}
