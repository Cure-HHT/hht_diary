// Verifies: DIARY-DEV-shared-events-catalog/D  (flowToken correlation; audit-scannable serials, no secrets)
import 'package:portal_actions/portal_actions.dart';
import 'package:test/test.dart';

void main() {
  test('serials are zero-padded, monotonic, default FT prefix', () {
    final m = SerialFlowTokenMinter();
    expect(m.next(), 'FT000001');
    expect(m.next(), 'FT000002');
  });

  test('stream prefix labels the flow; counter is globally monotonic', () {
    final m = SerialFlowTokenMinter(start: 5);
    expect(m.next(stream: 'QST'), 'QST000005');
    expect(m.next(), 'FT000006');
  });

  test('FlowTokenMinter is the injected abstraction', () {
    final FlowTokenMinter m = SerialFlowTokenMinter();
    expect(m.next(), matches(RegExp(r'^[A-Z]+\d{6}$')));
  });
}
