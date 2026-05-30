// Verifies: DIARY-DEV-shared-events-catalog/A — entry types are declared against
//   the extracted event_sourcing EntryTypeDefinition.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:test/test.dart';

void main() {
  test(
    'renamed event_sourcing lib resolves and EntryTypeDefinition is minimal',
    () {
      const def = EntryTypeDefinition(
        id: 'smoke_probe',
        registeredVersion: 1,
        name: 'Smoke Probe',
      );
      expect(def.id, 'smoke_probe');
      expect(def.registeredVersion, 1);
      expect(def.isMaterialized, isTrue); // default
      expect(def.toJson()['id'], 'smoke_probe');
    },
  );
}
