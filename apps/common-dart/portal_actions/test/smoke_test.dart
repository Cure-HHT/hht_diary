// Verifies: DIARY-PRD-action-inventory/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:test/test.dart';

void main() {
  test(
    'DIARY-PRD-action-inventory/A: Action framework + diary_shared_model resolve',
    () {
      const p = Permission('portal.user.deactivate');
      expect(p.name, 'portal.user.deactivate');
      expect(Idempotency.values, contains(Idempotency.required));
      expect(sharedEventCatalog, isNotEmpty);
    },
  );
}
