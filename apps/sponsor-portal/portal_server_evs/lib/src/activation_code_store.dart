import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class ActivationLookup {
  const ActivationLookup({required this.email});
  final String email;
}

class _Entry {
  _Entry({required this.email, required this.expiresAt});
  final String email;
  final DateTime expiresAt;
  DateTime? usedAt;
}

/// Ephemeral, in-process side-store of activation codes. Holds only a one-way
/// hash of each code (the cleartext lives solely in the emailed link), enforces
/// single-use + expiry, and invalidates a user's prior unused code on re-issue.
/// NEVER written to the event log.
// Implements: DIARY-DEV-portal-activation-code-lifecycle/A+B+C+D+E
class ActivationCodeStore {
  ActivationCodeStore({String Function()? codeGen})
      : _codeGen = codeGen ?? _defaultCodeGen;

  final String Function() _codeGen;
  final Map<String, _Entry> _byHash = <String, _Entry>{};
  final Map<String, String> _activeHashByEmail = <String, String>{};

  static final _rand = Random.secure();
  static String _defaultCodeGen() {
    String block() =>
        List<int>.generate(5, (_) => _rand.nextInt(36)).map(_b36).join();
    return '${block()}-${block()}';
  }

  static String _b36(int n) =>
      n < 10 ? String.fromCharCode(48 + n) : String.fromCharCode(65 + n - 10);

  static String _hash(String code) =>
      sha256.convert(utf8.encode(code)).toString();

  /// Mints a code for [email], invalidating any prior unused code for it.
  /// Returns the cleartext code (for the link); only its hash is retained.
  String issue({required String email, required DateTime expiresAt}) {
    final prior = _activeHashByEmail[email];
    if (prior != null) _byHash.remove(prior);
    final code = _codeGen();
    final h = _hash(code);
    _byHash[h] = _Entry(email: email, expiresAt: expiresAt);
    _activeHashByEmail[email] = h;
    return code;
  }

  /// Returns the bound email for a valid, unexpired, unused code; else null.
  ActivationLookup? validate(String code, {required DateTime now}) {
    final e = _byHash[_hash(code)];
    if (e == null || e.usedAt != null) return null;
    if (!now.isBefore(e.expiresAt)) return null;
    return ActivationLookup(email: e.email);
  }

  /// Marks the code used (single-use).
  void consume(String code) {
    final e = _byHash[_hash(code)];
    if (e != null) e.usedAt = DateTime.now();
  }
}
