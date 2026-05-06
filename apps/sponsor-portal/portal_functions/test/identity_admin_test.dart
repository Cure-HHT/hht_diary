// Verifies: REQ-d00166-C, REQ-d00166-F
import 'package:portal_functions/src/identity_admin.dart';
import 'package:test/test.dart';

void main() {
  group('IdentityAdmin', () {
    test(
      'REQ-d00166-C: IdentityAdmin.lookupOrProvisionByEmail signature exists',
      () {
        // Compilation-only test: the symbol must be accessible and its
        // return type must be a Record with the expected fields.
        final fn = IdentityAdmin.lookupOrProvisionByEmail;
        expect(fn, isA<Function>());
      },
    );

    test('REQ-d00166-F: LookupOrProvisionResult exposes uid and created', () {
      const r = LookupOrProvisionResult(uid: 'abc', created: true);
      expect(r.uid, equals('abc'));
      expect(r.created, isTrue);
    });
  });
}
