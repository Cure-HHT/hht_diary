// Channel-agnostic PHI checker. Every sender (FcmChannel, OutboxWriter,
// notifications-table writes) routes its serializable text through
// [PayloadGuard.assertSafeText] before persistence or network egress.
//
// Centralized so a new pattern (e.g. a sponsor's coordinator name) is
// added once and enforced everywhere — no per-channel divergence.

import 'package:meta/meta.dart';

/// Thrown by [PayloadGuard] when a string matches a configured PHI
/// pattern. Carries the field name and the offending pattern label so
/// callers can log a structured ERROR per DIARY-DEV-push-payload-phi-safety without leaking
/// the matched text itself.
class PhiLeakException implements Exception {
  PhiLeakException({required this.field, required this.matchedPattern});

  /// Logical name of the field being checked (e.g. `'envelope.title'`,
  /// `'fcmMessage.data.questionnaire_instance_id'`).
  final String field;

  /// Label of the pattern that fired (e.g. `'subject_key'`, `'email'`).
  /// Never the matched text — that's the leak we're catching.
  final String matchedPattern;

  @override
  String toString() =>
      'PhiLeakException: field=$field matched=$matchedPattern '
      '(DIARY-DEV-push-payload-phi-safety)';
}

/// Compiled PHI patterns. Order is irrelevant — first match wins for
/// the exception payload.
class _Pattern {
  const _Pattern(this.label, this.regex);
  final String label;
  final RegExp regex;
}

/// Channel-agnostic PHI checker (DIARY-DEV-push-payload-phi-safety).
///
/// Built-in patterns cover the spec floor (DIARY-DEV-push-payload-phi-safety):
///   * `subject_key` — 3-3-3 digit identifiers, with an optional
///     uppercase letter suffix on the middle group to cover real-world
///     SubjectKeys like `999-001A-125`.
///   * `email` — RFC-lite local-part@domain.tld.
///
/// Sponsors extend with [commonNamePatterns] (DIARY-DEV-push-payload-phi-safety "configured
/// common-name patterns"). Defaults to empty so a sponsor onboarding
/// without coordinator names doesn't false-positive.
// Implements: DIARY-DEV-push-payload-phi-safety/A+B+C+D — single PHI guard, fail-closed, test-only bypass
class PayloadGuard {
  PayloadGuard._();

  /// Test-only escape hatch (DIARY-DEV-push-payload-phi-safety). Production code MUST NOT
  /// flip this; runtime guard below throws in release mode if it is
  /// flipped, so a slipped `testOnlyDisable = true` cannot reach prod.
  @visibleForTesting
  static bool testOnlyDisable = false;

  /// Sponsor-configurable common-name patterns (DIARY-DEV-push-payload-phi-safety). Each
  /// entry should match a known clinical-staff name that must never
  /// reach an FCM payload. Sponsor bootstraps populate this list from
  /// their config; otherwise it stays empty and only the built-ins run.
  static List<RegExp> commonNamePatterns = <RegExp>[];

  /// True when this Dart VM was compiled in release mode (`--release`).
  /// Used to harden [testOnlyDisable] against accidental production
  /// usage (DIARY-DEV-push-payload-phi-safety).
  static const bool _isReleaseMode = bool.fromEnvironment('dart.vm.product');

  static final List<_Pattern> _builtIns = <_Pattern>[
    _Pattern('subject_key', RegExp(r'\b\d{3}-\d{3}[A-Z]?-\d{3}\b')),
    _Pattern(
      'email',
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'),
    ),
  ];

  /// Assert [text] does not contain a PHI pattern. Throws
  /// [PhiLeakException] on the first match. [fieldName] is included in
  /// the exception so the caller can log which payload field tripped.
  static void assertSafeText(String text, {required String fieldName}) {
    if (testOnlyDisable) {
      // Fail-closed: a slipped `testOnlyDisable = true` in a release
      // build is a compliance breach (DIARY-DEV-push-payload-phi-safety). Throw at the call
      // site rather than silently bypass.
      if (_isReleaseMode) {
        throw StateError(
          'PayloadGuard.testOnlyDisable must not be set in release mode '
          '(DIARY-DEV-push-payload-phi-safety)',
        );
      }
      return;
    }

    for (final pattern in _builtIns) {
      if (pattern.regex.hasMatch(text)) {
        throw PhiLeakException(field: fieldName, matchedPattern: pattern.label);
      }
    }
    for (final regex in commonNamePatterns) {
      if (regex.hasMatch(text)) {
        throw PhiLeakException(field: fieldName, matchedPattern: 'common_name');
      }
    }
  }

  /// Convenience for checking every value of a string-keyed map (e.g.
  /// the FCM `data` payload). Each value is checked with a synthetic
  /// field name `<fieldPrefix>.<key>` so the exception identifies which
  /// entry tripped.
  static void assertSafeStringMap(
    Map<String, String> data, {
    required String fieldPrefix,
  }) {
    data.forEach((key, value) {
      assertSafeText(value, fieldName: '$fieldPrefix.$key');
    });
  }
}
