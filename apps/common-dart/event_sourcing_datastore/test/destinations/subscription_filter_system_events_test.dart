// Verifies: REQ-d00128-J — SubscriptionFilter.includeSystemEvents
// dispatches system entry types through the opt-in flag, bypassing the
// entryTypes allow-list. User entry types continue to use entryTypes.
// Verifies: REQ-d00154-F — system events flow to destinations that
// opt in via SubscriptionFilter.includeSystemEvents.
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Build a synthetic [StoredEvent] for [SubscriptionFilter.matches]
/// assertions. `matches()` only inspects `entryType` and `eventType`, so
/// every other field is filled with valid placeholder data.
StoredEvent _mkEvent({
  required String entryType,
  String eventType = 'finalized',
}) => StoredEvent(
  key: 1,
  eventId: 'ev-$entryType',
  aggregateId: 'agg-1',
  aggregateType: 'DiaryEntry',
  entryType: entryType,
  entryTypeVersion: 1,
  libFormatVersion: 1,
  eventType: eventType,
  sequenceNumber: 1,
  data: const <String, dynamic>{},
  metadata: const <String, dynamic>{},
  initiator: const UserInitiator('u1'),
  clientTimestamp: DateTime.utc(2026, 4, 26),
  eventHash: 'hash',
);

StoredEvent _systemEvent() =>
    _mkEvent(entryType: kDestinationRegisteredEntryType);

StoredEvent _userEvent(String entryType) => _mkEvent(entryType: entryType);

void main() {
  group('SubscriptionFilter.includeSystemEvents', () {
    // Verifies: REQ-d00128-J — default false rejects system events
    // regardless of entryTypes content.
    test('REQ-d00128-J: includeSystemEvents=false rejects system events '
        'regardless of entryTypes', () {
      const f = SubscriptionFilter(entryTypes: ['demo_note']);
      expect(f.includeSystemEvents, isFalse);
      expect(f.matches(_systemEvent()), isFalse);
    });

    // Verifies: REQ-d00128-J — when true, system entry types bypass
    // entryTypes (an empty list does not exclude them).
    test('REQ-d00128-J: includeSystemEvents=true admits system events even '
        'with empty entryTypes', () {
      const f = SubscriptionFilter(
        entryTypes: <String>[],
        includeSystemEvents: true,
      );
      expect(f.matches(_systemEvent()), isTrue);
    });

    // Verifies: REQ-d00128-J — opting in to system events does not
    // override entryTypes for user events; user events still use the
    // allow-list.
    test('REQ-d00128-J: includeSystemEvents=true still applies entryTypes '
        'for user events', () {
      const f = SubscriptionFilter(
        entryTypes: ['demo_note'],
        includeSystemEvents: true,
      );
      expect(f.matches(_userEvent('demo_note')), isTrue);
      expect(f.matches(_userEvent('red_button_pressed')), isFalse);
    });

    // Verifies: REQ-d00128-J — the default value of the flag is false.
    test('REQ-d00128-J: default includeSystemEvents is false', () {
      const f = SubscriptionFilter(entryTypes: ['demo_note']);
      expect(f.includeSystemEvents, isFalse);
    });

    // Verifies: REQ-d00154-F — every reserved system entry type is
    // gated by the same flag (the flag is keyed off the reserved set,
    // not a single id).
    test('REQ-d00154-F: includeSystemEvents=true admits every reserved '
        'system entry type', () {
      const f = SubscriptionFilter(includeSystemEvents: true);
      for (final id in kReservedSystemEntryTypeIds) {
        expect(
          f.matches(_mkEvent(entryType: id)),
          isTrue,
          reason:
              'system entry type $id should be admitted when '
              'includeSystemEvents=true',
        );
      }
    });
  });
}
