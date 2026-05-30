import 'package:event_sourcing/event_sourcing.dart';
import 'package:shared_events/shared_events.dart';
import 'package:test/test.dart';

void main() {
  test('SharedEventType exposes id and origin from its definition', () {
    const t = SharedEventType(
      definition: EntryTypeDefinition(
        id: 'example_event',
        registeredVersion: 1,
        name: 'Example',
      ),
      origin: EventOrigin.portal,
    );
    expect(t.id, 'example_event');
    expect(t.origin, EventOrigin.portal);
  });
}
