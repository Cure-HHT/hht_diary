import 'package:firebase_auth/firebase_auth.dart';

/// Injectable seam over firebase_auth so login widgets are unit-testable.
abstract interface class FirebaseAuthClient {
  /// Signs in and returns a fresh Identity Platform ID token, or throws.
  Future<String> signInAndGetIdToken({
    required String email,
    required String password,
  });
}

class RealFirebaseAuthClient implements FirebaseAuthClient {
  RealFirebaseAuthClient([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;

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
}
