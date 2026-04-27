# Changelog

## 0.1.0 (2026-04-22)

Initial release. RFC 8785 (JSON Canonicalization Scheme) for Dart, adapted
from the Apache-2.0-licensed Affinidi SSI SDK. See NOTICE.md for full
attribution and list of local adaptations.

- `canonicalize(value)` returns canonical JSON string.
- `canonicalizeBytes(value)` returns UTF-8 bytes ready for hashing.
- `FormatException` on NaN / Infinity / unsupported types.
- Test coverage includes RFC 8785 Appendix B number vectors.
