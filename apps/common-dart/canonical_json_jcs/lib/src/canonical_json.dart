// Adapted from affinidi-ssi-dart/lib/src/util/jcs_util.dart
// (Apache License 2.0). See the package NOTICE.md for attribution and the
// list of local adaptations.

import 'dart:convert';

/// Top-level convenience: canonicalize [value] to its RFC 8785 JCS string.
String canonicalize(Object? value) => CanonicalJson.canonicalize(value);

/// Top-level convenience: canonicalize [value] and encode to UTF-8 bytes
/// ready to feed into a hash function.
List<int> canonicalizeBytes(Object? value) =>
    utf8.encode(CanonicalJson.canonicalize(value));

/// JSON Canonicalization Scheme (JCS) implementation per RFC 8785.
///
/// Produces deterministic byte-identical serialization of JSON values so a
/// cross-platform receiver can independently recompute a hash over the same
/// input and arrive at the same digest.
class CanonicalJson {
  /// Canonicalize a JSON value per RFC 8785.
  ///
  /// Accepted types: `null`, `bool`, `num`, `String`, `List`, `Map`. Throws
  /// [FormatException] on unsupported types or on `NaN` / `Infinity`.
  static String canonicalize(Object? value) => _canonicalizeValue(value);

  static String _canonicalizeValue(Object? value) {
    if (value == null || value is bool || value is String) {
      return jsonEncode(value);
    } else if (value is num) {
      return _canonicalizeNumber(value);
    } else if (value is List) {
      return _canonicalizeArray(value);
    } else if (value is Map) {
      return _canonicalizeObject(value);
    }
    throw FormatException(
      'CanonicalJson: unsupported type ${value.runtimeType}',
    );
  }

  /// RFC 8785 §3.2.2.3 number serialization via ECMA-262 Number.toString.
  ///
  /// Dart's `jsonEncode` gets most cases right but differs on two edge
  /// cases that JCS pins down: negative zero renders as `-0.0` instead of
  /// `0`, and whole-valued doubles carry a trailing `.0` where ECMA-262
  /// says they shouldn't. Both are handled explicitly below.
  static String _canonicalizeNumber(num value) {
    if (value.isNaN || value.isInfinite) {
      throw FormatException(
        'CanonicalJson: NaN and Infinity are not representable in RFC 8785 '
        '(got $value)',
      );
    }
    // RFC 8785 §3.2.2.3: ToString(-0) == "0".
    if (value == 0.0 && value.isNegative) {
      return '0';
    }
    final result = jsonEncode(value);
    // Trim trailing ".0" so whole-valued doubles match their integer form
    // (ECMA-262 7.1.12.1 "If m is an integer, return ToInteger(m).toString()").
    if (result.endsWith('.0')) {
      return result.substring(0, result.length - 2);
    }
    return result;
  }

  static String _canonicalizeArray(List<Object?> array) {
    final buffer = StringBuffer('[');
    for (var i = 0; i < array.length; i++) {
      if (i > 0) buffer.write(',');
      buffer.write(_canonicalizeValue(array[i]));
    }
    buffer.write(']');
    return buffer.toString();
  }

  /// Sort keys in UTF-16 code unit ascending order per RFC 8785 §3.2.3 and
  /// canonicalize each value recursively. Dart strings are internally
  /// UTF-16, so `String.compareTo` produces exactly the ordering the RFC
  /// requires, including correct handling of surrogate pairs for
  /// characters above U+FFFF. Do NOT substitute a Unicode-codepoint sort
  /// (e.g., iterating `String.runes`) — that would produce a different
  /// order for supplementary-plane characters and break cross-platform
  /// hash reproducibility.
  static String _canonicalizeObject(Map<Object?, Object?> object) {
    final sortedKeys = object.keys.map((k) => k.toString()).toList()..sort();
    final buffer = StringBuffer('{');
    for (var i = 0; i < sortedKeys.length; i++) {
      if (i > 0) buffer.write(',');
      final keyString = sortedKeys[i];
      final originalKey = _findOriginalKey(object, keyString);
      final value = object[originalKey];
      buffer
        ..write(jsonEncode(keyString))
        ..write(':')
        ..write(_canonicalizeValue(value));
    }
    buffer.write('}');
    return buffer.toString();
  }

  /// Find the original map key whose `toString()` equals [keyString].
  ///
  /// Used to look up the value from a possibly-non-string-keyed map after
  /// the sort step has stringified all keys. For the `Map<String, Object?>`
  /// inputs this package was built for, this is a no-op loop that always
  /// matches on the first iteration. For general `Map<Object?, Object?>`
  /// inputs: if two distinct non-string keys produce the same `.toString()`
  /// (e.g., two objects with a custom `toString` override that returns
  /// identical strings), this method returns whichever comes first in
  /// `object.keys` iteration order; the other colliding key's value is
  /// silently ignored. That path is not exercised by this library's
  /// intended use but callers outside the event-sourcing pipeline should
  /// be aware of the limitation.
  static Object? _findOriginalKey(
    Map<Object?, Object?> object,
    String keyString,
  ) {
    for (final key in object.keys) {
      if (key.toString() == keyString) return key;
    }
    return keyString;
  }
}
