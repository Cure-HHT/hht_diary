# Cross-Language Contract: Linking Code Check Characters

`linking-code-mac-vectors.json` pins the check-char algorithm shared between the
Dart issuer (`portal_actions`) and the Go verifier (diary-portal-resolver service).

## What the vectors prove

Each entry is:

```json
{ "input": "<8 chars>", "keyUtf8": "<HMAC key>", "check": "<2 chars>" }
```

- `input` — the first 8 characters of a linking code (2-char sponsor prefix + 6
  random chars from the 28-symbol charset `ABCDEFGHJKLMNPQRTUVWXY346789`).
- `keyUtf8` — the per-sponsor HMAC key, encoded as UTF-8.
- `check` — the two check characters the algorithm MUST produce for this
  `(input, key)` pair.

Both the Dart issuer and the Go verifier MUST produce identical `check` values for
every vector. A divergence means the two implementations have drifted.

## Algorithm (normative)

```
mac  = HMAC-SHA256(key=utf8(keyUtf8), msg=utf8(input))
c1   = charset[mac.bytes[0] % 28]
c2   = charset[mac.bytes[1] % 28]
check = c1 + c2
```

Modulo bias (28 does not divide 256 evenly) is accepted by design.

## Regenerating the vectors

Run from `apps/common-dart/portal_actions/`:

```bash
dart run tool/gen_vectors.dart > ../../../contract/linking-code-mac-vectors.json
```

Any change to the check-char algorithm MUST regenerate the vectors AND update both
the Dart issuer and Go verifier to agree on the new output.

## Independent verification

The vectors are independently reproducible with any HMAC-SHA256 tool:

```bash
# Example with Python:
python3 -c "
import hmac, hashlib
charset = 'ABCDEFGHJKLMNPQRTUVWXY346789'
key = b'test-sponsor-key-not-secret'
msg = b'CARANDOM'
mac = hmac.new(key, msg, hashlib.sha256).digest()
print(charset[mac[0] % 28] + charset[mac[1] % 28])
"
# Expected: A4
```
