# NOTICE

This package contains an adaptation of the JCS (JSON Canonicalization Scheme,
RFC 8785) utility from the Affinidi SSI SDK for Dart.

## Upstream source

Original file: `lib/src/util/jcs_util.dart`
Project: `affinidi-ssi-dart`
Repository: `https://github.com/affinidi/affinidi-ssi-dart`
License: Apache License, Version 2.0

Copyright 2024 Affinidi Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not
use this file except in compliance with the License. You may obtain a copy
of the License at:

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.

## Adaptations made in this package

- Replaced Affinidi-specific `SsiException` with `FormatException` so the
  package has zero runtime dependencies beyond `dart:convert`.
- Class renamed from `JcsUtil` to `CanonicalJson`.
- Added top-level `canonicalize(value)` and `canonicalizeBytes(value)` helpers
  as the primary entry points.
- Adapted `canonicalizeBytes(value)` to return UTF-8 encoded bytes suitable
  for feeding directly into a hash function.
- Added unit tests from RFC 8785 Appendix B (number test vectors) and
  additional edge-case coverage.
