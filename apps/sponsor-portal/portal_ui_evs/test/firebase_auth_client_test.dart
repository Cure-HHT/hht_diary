// Verifies: DIARY-DEV-portal-emulator-bootstrap/B — the production session
// restore builds RealFirebaseAuthClient BEFORE `Firebase.initializeApp()` runs
// (it is handed as the `readPersistedIdToken` callback into resolveAuthBootstrap,
// which only initializes Firebase afterwards). Constructing the client must
// therefore NOT read `FirebaseAuth.instance` — that throws a FirebaseException
// until the `[DEFAULT]` app exists. Regression: an eager `FirebaseAuth.instance`
// in the constructor crashed `_resolveAuthMode` on load (the thrown
// FirebaseException surfaced on web as a confusing JS-interop cast error).
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/firebase_auth_client.dart';

void main() {
  test('construction stays lazy — does not touch FirebaseAuth.instance', () {
    // No Firebase app is initialized in the test VM, so any eager read of
    // FirebaseAuth.instance would throw here. Construction must succeed.
    expect(RealFirebaseAuthClient.new, returnsNormally);
  });
}
