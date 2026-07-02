import 'package:firebase_auth/firebase_auth.dart';

/// Injectable seam over firebase_auth so login widgets are unit-testable.
abstract interface class FirebaseAuthClient {
  /// Signs in and returns a fresh Identity Platform ID token, or throws.
  Future<String> signInAndGetIdToken({
    required String email,
    required String password,
  });

  /// Awaits the SDK's persisted-auth restore and returns a fresh ID token for
  /// the persisted *User*, or null when no *User* is persisted (logged out).
  ///
  /// On the web the *Auth* SDK auto-restores any user persisted in IndexedDB
  /// during initialization; this exposes that restored user's fresh ID token so
  /// the portal can re-derive its own session token on a hard page reload —
  /// realizing the "restorable *Session*" the production (non-emulator)
  /// bootstrap deliberately leaves intact.
  // Implements: DIARY-DEV-portal-emulator-bootstrap/B
  Future<String?> awaitPersistedIdToken();
}

class RealFirebaseAuthClient implements FirebaseAuthClient {
  RealFirebaseAuthClient([this._injectedAuth]);

  /// The injected instance for tests, or null to resolve [FirebaseAuth.instance]
  /// lazily on first use. It MUST stay lazy: the boot-time restore constructs
  /// this client BEFORE `Firebase.initializeApp()` runs (it is passed as a
  /// callback into the bootstrap), and reading `FirebaseAuth.instance` before the
  /// default app exists throws a `FirebaseException` (no `[DEFAULT]` app).
  /// Resolving eagerly in the constructor crashed `_resolveAuthMode` on load.
  final FirebaseAuth? _injectedAuth;
  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;

  @override
  Future<String> signInAndGetIdToken({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) throw StateError('no id token after sign-in');
    return token;
  }

  // Implements: DIARY-DEV-portal-emulator-bootstrap/B
  @override
  Future<String?> awaitPersistedIdToken() async {
    // The first `authStateChanges()` emission fires once the SDK has finished
    // its initial persisted-user restore, so it reflects the reloaded session
    // (the restored User, or null when none was persisted). We await that first
    // emission rather than reading `currentUser` eagerly, which can be null
    // before the async restore completes on web.
    final user = await _auth.authStateChanges().first;
    return user?.getIdToken();
  }
}
