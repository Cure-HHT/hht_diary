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

  test('patient aggregate declares the [P]/edge entry types', () {
    final ids = patientEventTypes.map((t) => t.id).toSet();
    expect(ids, {
      'patient_synced_from_edc',
      'patient_linking_code_issued',
      'patient_linking_code_revoked',
      'patient_trial_started',
      'patient_disconnected',
      'patient_reconnected',
      'patient_marked_not_participating',
      'patient_reactivated',
      'patient_enrollment_status_changed',
    });
    expect(ids, isNot(contains('patient_linked'))); // [M], held
  });
}
