# canonical_json_jcs

JSON Canonicalization Scheme ([RFC 8785](https://www.rfc-editor.org/rfc/rfc8785)) for Dart.

Produces a deterministic, byte-identical serialization of JSON values so
cross-platform receivers can independently recompute a hash over the same
input and arrive at the same digest. Used on the hht_diary mobile client
to stamp `event_hash` values that downstream systems (Python diary-server,
Dart portal, future Postgres verifier) can verify without needing to
preserve Dart's Map insertion order or number-formatting quirks (CUR-1154).

## Usage

```dart
import 'package:canonical_json_jcs/canonical_json_jcs.dart';
import 'package:crypto/crypto.dart';

final event = <String, Object?>{
  'event_type': 'finalized',
  'aggregate_id': 'abc123',
  'sequence_number': 42,
};

// Canonical JSON string.
final canonical = canonicalize(event);

// Bytes ready to feed to a hash function.
final digest = sha256.convert(canonicalizeBytes(event));
```

## Guarantees

- Object keys are sorted lexicographically at every depth.
- Numbers follow the ECMA-262 Number.prototype.toString algorithm that
  RFC 8785 §3.2.2.3 requires; `-0` serializes to `"0"`, trailing `.0` is
  stripped from integral doubles, `NaN` and `Infinity` are rejected.
- Strings use the minimal-escape form from RFC 8785 §3.2.2.2, matching
  Dart's `jsonEncode` default output for all characters this package
  supports.
- No whitespace outside of string contents.

## Scope limits

- Only the JSON types that occur in hht_diary events: null, bool, num,
  String, List, Map. Unsupported types raise `FormatException`.
- Map keys with colliding string representations (e.g., `1` (int) vs
  `'1'` (String)) are undefined — the class normalises all keys to their
  `toString()` form and uses lexicographic order, matching the upstream
  behaviour.

See NOTICE.md for attribution — this package is adapted from Affinidi's
SSI SDK JCS utility under Apache 2.0.
