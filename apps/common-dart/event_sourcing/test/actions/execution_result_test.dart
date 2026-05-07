import 'package:event_sourcing/event_sourcing.dart'
    show EventDraft, SecurityDetails;
import 'package:event_sourcing/src/actions/execution_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExecutionResult', () {
    test('REQ-d00166-D: holds result + events', () {
      const r = ExecutionResult<int>(result: 42, events: <EventDraft>[]);
      expect(r.result, 42);
      expect(r.events, isEmpty);
      expect(r.securityDetailsOverride, isNull);
    });

    test('REQ-d00166-D: events list MAY be empty (no-op success)', () {
      const r = ExecutionResult<String>(result: 'ok', events: <EventDraft>[]);
      expect(r.events, isEmpty);
    });

    test('securityDetailsOverride is preserved when set', () {
      const sd = SecurityDetails(ipAddress: '10.0.0.1');
      const r = ExecutionResult<void>(
        result: null,
        events: <EventDraft>[],
        securityDetailsOverride: sd,
      );
      expect(r.securityDetailsOverride, isNotNull);
      expect(r.securityDetailsOverride?.ipAddress, '10.0.0.1');
    });
  });
}
