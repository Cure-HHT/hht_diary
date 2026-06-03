import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class ResetLookup {
  const ResetLookup({required this.email});
  final String email;
}

class PasswordResetRateLimited implements Exception {
  const PasswordResetRateLimited();
  @override
  String toString() => 'PasswordResetRateLimited';
}

class _Entry {
  _Entry({required this.email, required this.expiresAt});
  final String email;
  final DateTime expiresAt;
  DateTime? usedAt;
}

/// Ephemeral, in-process password-reset code store. Holds only a one-way hash
/// of each code; single-use; 24h TTL; invalidates a user's prior unused code on
/// re-issue; issuance rate-limited. NEVER written to the event log.
// Implements: DIARY-DEV-portal-reset-code-lifecycle/A+B+C
class PasswordResetCodeStore {
  PasswordResetCodeStore({
    this.ttl = const Duration(hours: 24),
    this.maxIssuesPerWindow = 3,
    this.issueWindow = const Duration(minutes: 15),
    String Function()? codeGen,
  }) : _codeGen = codeGen ?? _defaultCodeGen;

  final Duration ttl;
  final int maxIssuesPerWindow;
  final Duration issueWindow;
  final String Function() _codeGen;

  final Map<String, _Entry> _byHash = <String, _Entry>{};
  final Map<String, String> _activeHashByEmail = <String, String>{};
  final Map<String, List<DateTime>> _issuesByEmail = <String, List<DateTime>>{};

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

  /// Mints a code for [email] (24h TTL), invalidating any prior unused code.
  /// Throws [PasswordResetRateLimited] if too many were issued in the window.
  String issue({required String email, required DateTime now}) {
    final recent = (_issuesByEmail[email] ?? const <DateTime>[])
        .where((t) => now.difference(t) < issueWindow)
        .toList();
    if (recent.length >= maxIssuesPerWindow) {
      throw const PasswordResetRateLimited();
    }
    recent.add(now);
    _issuesByEmail[email] = recent;

    final prior = _activeHashByEmail[email];
    if (prior != null) _byHash.remove(prior);
    final code = _codeGen();
    final h = _hash(code);
    _byHash[h] = _Entry(email: email, expiresAt: now.add(ttl));
    _activeHashByEmail[email] = h;
    return code;
  }

  /// Returns the bound email for a valid, unexpired, unused code; else null.
  ResetLookup? validate(String code, {required DateTime now}) {
    final e = _byHash[_hash(code)];
    if (e == null || e.usedAt != null) return null;
    if (!now.isBefore(e.expiresAt)) return null;
    return ResetLookup(email: e.email);
  }

  /// Marks the code used (single-use).
  void consume(String code) {
    final e = _byHash[_hash(code)];
    if (e != null) e.usedAt = DateTime.now();
  }
}
