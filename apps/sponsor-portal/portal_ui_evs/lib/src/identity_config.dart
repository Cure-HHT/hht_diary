import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Fetches the portal's identity configuration (`GET /config/identity`).
/// Returns the decoded map, or null if the request fails. The map carries the
/// Firebase options plus `authMode`, which the client uses to pick its login UI.
Future<Map<String, Object?>?> fetchIdentityConfig(String serverUrl) async {
  final r = await http.get(Uri.parse('$serverUrl/config/identity'));
  if (r.statusCode != 200) return null;
  return jsonDecode(r.body) as Map<String, Object?>;
}

/// Initializes Firebase + the auth emulator (if an emulator host is reported)
/// from an already-fetched identity-config [cfg]. Returns true when an emulator
/// was wired.
///
/// Retry-safe (the bootstrap calls this repeatedly until it succeeds): a
/// `duplicate-app` from a prior partial attempt is treated as "already
/// initialized" and ignored. Failures are NOT swallowed — they propagate so
/// the caller gates readiness on a clean connect instead of silently falling
/// back to production Firebase.
Future<bool> initFirebaseWithConfig(Map<String, Object?> cfg) async {
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: (cfg['apiKey'] as String?) ?? 'demo-api-key',
        appId: (cfg['appId'] as String?) ?? '',
        messagingSenderId: (cfg['messagingSenderId'] as String?) ?? '',
        projectId: (cfg['projectId'] as String?) ?? 'demo-local-stack',
        authDomain: (cfg['authDomain'] as String?) ?? '',
      ),
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
  final emulatorHost = (cfg['emulatorHost'] as String?) ?? '';
  if (emulatorHost.isEmpty) return false;
  final parts = emulatorHost.split(':');
  await FirebaseAuth.instance.useAuthEmulator(
    parts[0],
    int.tryParse(parts.length > 1 ? parts[1] : '9099') ?? 9099,
  );
  return true;
}

/// "Not reached the emulator yet" failure codes: the SDK couldn't talk to a
/// real auth backend at all. Before the emulator connect applies, the
/// local-stack's dummy API key yields one of these; once connected, the
/// emulator instead returns a *credential* rejection (a different code).
const Set<String> _emulatorNotReachedCodes = {
  'api-key-not-valid',
  'invalid-api-key',
  'network-request-failed',
  'app-not-authorized',
  'internal-error',
};

/// Behavioural probe that succeeds only once an auth call actually REACHES the
/// emulator. `useAuthEmulator()` returns before the SDK applies the connect
/// (the connect — and the SDK's emulator banner — land a beat later), so the
/// bootstrap polls this until it stops throwing, then presents the login.
///
/// It attempts a sign-in with a bogus account: once the emulator answers it
/// rejects the credentials (a credential-error code) which we treat as
/// "reached"; while calls still hit production the dummy API key yields an
/// [_emulatorNotReachedCodes] error which we rethrow so the poll continues. A
/// failed sign-in establishes no session, so the probe is side-effect-free.
Future<void> verifyEmulatorConnected() async {
  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'connectivity-probe@portal.invalid',
      password: 'not-a-real-password',
    );
  } on FirebaseAuthException catch (e) {
    if (_emulatorNotReachedCodes.contains(e.code)) rethrow; // not connected yet
    // Any other code is the emulator rejecting the bogus creds => reached.
  }
}
