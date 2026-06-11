import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:event_sourcing/event_sourcing.dart';

class ActivationLookup {
  const ActivationLookup({required this.email});
  final String email;
}

/// Durable activation-code store over the event log. Each code's lifecycle is
/// persisted as `activation_code_minted` / `activation_code_consumed` events
/// carrying ONLY a keyed hash (HMAC-SHA-256 under a server-side pepper) — the
/// cleartext exists solely in the emailed link, so pending links survive
/// server restarts and deploys while nobody but the mailbox owner ever sees a
/// usable code. Validation reads the `activation_codes` view, which keys rows
/// by email so a fresh mint supersedes the prior code by fold.
///
/// Rotating the pepper invalidates all outstanding codes (stored HMACs no
/// longer match); Resend Invite is the recovery path.
// Implements: DIARY-DEV-portal-activation-code-lifecycle/A+B+C+D+E+F
class ActivationCodeStore {
  ActivationCodeStore({
    required EventStore eventStore,
    required String pepper,
    String Function()? codeGen,
  })  : _eventStore = eventStore,
        _pepper = utf8.encode(pepper),
        _codeGen = codeGen ?? _defaultCodeGen;

  static const String viewName = 'activation_codes';

  final EventStore _eventStore;
  final List<int> _pepper;
  final String Function() _codeGen;

  static final _rand = Random.secure();
  static String _defaultCodeGen() {
    String block() =>
        List<int>.generate(5, (_) => _rand.nextInt(36)).map(_b36).join();
    return '${block()}-${block()}';
  }

  static String _b36(int n) =>
      n < 10 ? String.fromCharCode(48 + n) : String.fromCharCode(65 + n - 10);

  String _hash(String code) =>
      Hmac(sha256, _pepper).convert(utf8.encode(code)).toString();

  Future<void> _append(String eventType, Map<String, Object?> data) =>
      _eventStore.append(
        entryType: eventType,
        aggregateType: 'portal_user',
        aggregateId: data['email']! as String,
        eventType: eventType,
        data: data,
        initiator: const AutomationInitiator(service: 'activation'),
      );

  /// Mints a code for [email]. The minted event folds onto the email-keyed
  /// `activation_codes` row, overwriting (= invalidating) any prior unused
  /// code for that email. Returns the cleartext code (for the link); only its
  /// keyed hash is ever persisted.
  Future<String> issue(
      {required String email, required DateTime expiresAt}) async {
    final code = _codeGen();
    await _append('activation_code_minted', <String, Object?>{
      'email': email,
      'code_hash': _hash(code),
      'expires_at': expiresAt.toUtc().toIso8601String(),
      'status': 'active',
    });
    return code;
  }

  /// The email's view row, but only if it carries [code]'s hash still active.
  Future<Map<String, dynamic>?> _activeRow(String code) async {
    final h = _hash(code);
    final rows = await _eventStore.backend.findViewRows(viewName);
    for (final row in rows) {
      if (row['code_hash'] == h && row['status'] == 'active') return row;
    }
    return null;
  }

  /// Returns the bound email for a valid, unexpired, unconsumed code; else null.
  Future<ActivationLookup?> validate(String code,
      {required DateTime now}) async {
    final row = await _activeRow(code);
    if (row == null) return null;
    final expiresRaw = row['expires_at'];
    if (expiresRaw is! String) return null;
    if (!now.isBefore(DateTime.parse(expiresRaw))) return null;
    final email = row['email'];
    if (email is! String) return null;
    return ActivationLookup(email: email);
  }

  /// Marks the code consumed (single-use). Hash-matched against the active
  /// row, so a stale superseded code can never clobber the current one.
  Future<void> consume(String code, {required DateTime now}) async {
    final row = await _activeRow(code);
    if (row == null) return;
    await _append('activation_code_consumed', <String, Object?>{
      'email': row['email'],
      'code_hash': row['code_hash'],
      'status': 'consumed',
      'consumed_at': now.toUtc().toIso8601String(),
    });
  }
}
