import 'package:audited_actions/src/execution_result.dart';
import 'package:test/test.dart';

// Test double to avoid importing Flutter transitively via event_sourcing_datastore
class _FakeSecurityDetails {
  const _FakeSecurityDetails({this.ipAddress});

  final String? ipAddress;
}

void main() {
  group('ExecutionResult', () {
    test('REQ-d00166-D: holds result + events', () {
      const r = ExecutionResult<int>(result: 42, events: <dynamic>[]);
      expect(r.result, 42);
      expect(r.events, isEmpty);
      expect(r.securityDetailsOverride, isNull);
    });

    test('REQ-d00166-D: events list MAY be empty (no-op success)', () {
      const r = ExecutionResult<String>(result: 'ok', events: <dynamic>[]);
      expect(r.events, isEmpty);
    });

    test('securityDetailsOverride is preserved when set', () {
      const sd = _FakeSecurityDetails(ipAddress: '10.0.0.1');
      const r = ExecutionResult<void>(
        result: null,
        events: <dynamic>[],
        securityDetailsOverride: sd,
      );
      expect(r.securityDetailsOverride, isNotNull);
      expect(
        (r.securityDetailsOverride as _FakeSecurityDetails?)?.ipAddress,
        '10.0.0.1',
      );
    });
  });
}
