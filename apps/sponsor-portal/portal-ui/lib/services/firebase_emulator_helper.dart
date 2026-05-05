// IMPLEMENTS REQUIREMENTS:
//   REQ-p00009 (Sponsor-Specific Web Portals — local-flavor build must
//               actually route auth ops to the local emulator)
//   REQ-CAL-p00046 (Session Management — login flow must be deterministic)
//
// CUR-1280: workaround for flutterfire #9528 / its sibling cluster.
//
// Firebase Auth's web SDK (firebase-auth.js) silently fails to apply
// `useAuthEmulator` when the Auth instance has already been "used"
// (e.g. by the JS SDK's automatic IndexedDB state-restoration after
// Firebase.initializeApp). main.dart calls useAuthEmulator immediately
// after init, but the auto-restore can race against the bind, leaving
// the JS-level binding unset even though the Dart-level call returned
// successfully.
//
// Symptom: every Firebase Auth network op on a fresh page load goes
// to https://identitytoolkit.googleapis.com (production) and fails
// with `api-key-not-valid`. The user is told to "ensure the emulator
// is running" — but the emulator IS running; the binding just didn't
// apply.
//
// Practical evidence the bind didn't apply on first attempt: the
// `WARNING: You are using the Auth Emulator…` log from the JS SDK
// only fires when useEmulator runs. Locally we observed it firing
// only on a re-bind, not on the original main.dart bind, even though
// the Dart `await useAuthEmulator(...)` returned without throwing.
//
// Re-binding before each auth network op is the stable workaround.
// useAuthEmulator is idempotent — calling it again with the same
// host/port is cheap.
//
// Upstream: https://github.com/firebase/flutterfire/issues/9528
//
// In production builds (F.useEmulator = false), [ensureAuthEmulatorBound]
// is a no-op. The function is safe to call from any code path that
// performs a Firebase Auth network op.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../flavors.dart';

/// Ensures `FirebaseAuth.instance` is bound to the local Firebase Auth
/// emulator on local-flavor builds. No-op for any other flavor.
///
/// Call this BEFORE any network-issuing Firebase Auth operation
/// (signInWithEmailAndPassword, createUserWithEmailAndPassword,
/// resolveSignIn, verifyPasswordResetCode, confirmPasswordReset,
/// MultiFactor.enroll, etc.) in code paths that may run on a
/// fresh page load.
///
/// Idempotent: calling repeatedly with the same target is cheap.
/// Throws are swallowed and logged via [debugPrint]; the workaround
/// is best-effort and must never block the calling auth flow.
Future<void> ensureAuthEmulatorBound() async {
  if (!F.useEmulator) return;
  const emulatorHost = String.fromEnvironment(
    'FIREBASE_AUTH_EMULATOR_HOST',
    defaultValue: '',
  );
  if (emulatorHost.isEmpty) return;
  final parts = emulatorHost.split(':');
  final host = parts[0];
  final port = int.tryParse(parts.length > 1 ? parts[1] : '9099') ?? 9099;
  try {
    await FirebaseAuth.instance.useAuthEmulator(host, port);
  } catch (e) {
    // Re-binds are expected to be no-ops; any error here means the
    // SDK rejected the call (e.g. "Auth instance already used"). We
    // proceed regardless — if the binding was already applied earlier
    // the auth op will use the emulator anyway.
    debugPrint(
      '[AUTH] ensureAuthEmulatorBound: $e (proceeding; binding may '
      'still be in effect from main.dart)',
    );
  }
}
