// Implements: DIARY-DEV-shared-events-catalog/D  (correlation tokens carry no cleartext secret)
//
// Mints human-scannable, globally-monotonic correlation serials (e.g. FT000001)
// for outgoing-intent flows. Injected because a monotonic serial needs state a
// pure Action.execute() cannot hold. Phase 2 (portal-server) backs this with a
// persistent sequence; this in-memory impl serves the library + tests.
abstract class FlowTokenMinter {
  /// Next correlation serial. [stream] is a short uppercase prefix labelling the
  /// flow type (e.g. 'QST'); the numeric counter is globally monotonic.
  String next({String stream});
}

class SerialFlowTokenMinter implements FlowTokenMinter {
  SerialFlowTokenMinter({int start = 1, int width = 6})
    : _next = start,
      _width = width;
  int _next;
  final int _width;

  @override
  String next({String stream = 'FT'}) {
    final serial = '$stream${_next.toString().padLeft(_width, '0')}';
    _next++;
    return serial;
  }
}
