// Regenerates contract/linking-code-mac-vectors.json from the authoritative Dart
// issuer. Run: dart run tool/gen_vectors.dart > ../../../contract/linking-code-mac-vectors.json
import 'dart:convert';
import 'package:portal_actions/src/linking_code_generator.dart';

void main() {
  const cases = [
    ['CARANDOM', 'test-sponsor-key-not-secret'],
    ['CAAAAAAA', 'test-sponsor-key-not-secret'],
    ['OR346789', 'another-key'],
    ['XXABCDEF', 'local-stack-discovery-key-not-secret'],
  ];
  final out = [
    for (final c in cases)
      {'input': c[0], 'keyUtf8': c[1], 'check': checkCharsFor(c[0], c[1])},
  ];
  print(const JsonEncoder.withIndent('  ').convert(out));
}
