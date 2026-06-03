import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Outcome of an OTP verification attempt.
enum OtpResult { ok, invalid, expired, tooManyAttempts }

/// Thrown when a user requests codes faster than the issuance rate limit.
class OtpRateLimited implements Exception {
  const OtpRateLimited();
  @override
  String toString() => 'OtpRateLimited';
}

class _Entry {
  _Entry({required this.hash, required this.expiresAt});
  final String hash;
  final DateTime expiresAt;
  int attempts = 0;
  bool used = false;
}

/// Ephemeral, in-process email-OTP store. Holds only a one-way hash of each
/// code; the cleartext lives solely in the delivered email. Single-use,
/// time-limited, attempt-capped, rate-limited, prior-invalidating on re-issue.
/// NEVER written to the event log.
// Implements: DIARY-DEV-portal-login-second-factor/A+B
class OtpStore {
  OtpStore({
    this.ttl = const Duration(minutes: 10),
    this.maxAttempts = 5,
    this.maxIssuesPerWindow = 3,
    this.issueWindow = const Duration(minutes: 15),
    String Function()? codeGen,
  }) : _codeGen = codeGen ?? _defaultCodeGen;

  final Duration ttl;
  final int maxAttempts;
  final int maxIssuesPerWindow;
  final Duration issueWindow;
  final String Function() _codeGen;

  final Map<String, _Entry> _byUser = <String, _Entry>{};
  final Map<String, List<DateTime>> _issuesByUser = <String, List<DateTime>>{};

  static final _rand = Random.secure();
  static String _defaultCodeGen() =>
      List<int>.generate(6, (_) => _rand.nextInt(10)).join();

  static String _hash(String code) =>
      sha256.convert(utf8.encode(code)).toString();

  /// Mints a 6-digit code for [userId], invalidating any prior code.
  /// Throws [OtpRateLimited] if too many codes were issued in the window.
  /// Returns the cleartext code; only its hash is retained.
  String issue({required String userId, required DateTime now}) {
    final recent = (_issuesByUser[userId] ?? const <DateTime>[])
        .where((t) => now.difference(t) < issueWindow)
        .toList();
    if (recent.length >= maxIssuesPerWindow) throw const OtpRateLimited();
    recent.add(now);
    _issuesByUser[userId] = recent;

    final code = _codeGen();
    _byUser[userId] = _Entry(hash: _hash(code), expiresAt: now.add(ttl));
    return code;
  }

  /// Verifies [code] for [userId]. On the wrong code, increments attempts;
  /// once attempts exceed [maxAttempts] the code is invalidated.
  OtpResult verify({
    required String userId,
    required String code,
    required DateTime now,
  }) {
    final e = _byUser[userId];
    if (e == null || e.used) return OtpResult.invalid;
    if (!now.isBefore(e.expiresAt)) {
      _byUser.remove(userId);
      return OtpResult.expired;
    }
    if (e.attempts >= maxAttempts) {
      _byUser.remove(userId);
      return OtpResult.tooManyAttempts;
    }
    if (_hash(code) != e.hash) {
      e.attempts++;
      return OtpResult.invalid;
    }
    e.used = true;
    return OtpResult.ok;
  }
}
