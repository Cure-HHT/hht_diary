import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

// Implements: DIARY-DEV-linking-code-lifecycle/A — server-side linking-code
//   generation: 2-char sponsor prefix + 6 random + 2 keyed-MAC check chars.
const linkingCodeCharset =
    'ABCDEFGHJKLMNPQRTUVWXY346789'; // 28 symbols; excludes I,1,O,0,S,5,Z,2

/// The two HMAC check characters for an 8-char `prefix+random` [input], keyed by
/// the per-sponsor [sponsorKey]. The deterministic core the discovery service
/// (Go) mirrors byte-for-byte; pinned by contract/linking-code-mac-vectors.json.
// Implements: DIARY-DEV-linking-code-lifecycle/E
String checkCharsFor(String input, String sponsorKey) {
  final mac = Hmac(sha256, utf8.encode(sponsorKey)).convert(utf8.encode(input));
  final b = mac.bytes;
  return linkingCodeCharset[b[0] % 28] + linkingCodeCharset[b[1] % 28];
}

/// Generate a linking code: [prefix] + 6 random chars + 2 keyed-MAC check chars.
/// [prefix] and [sponsorKey] are injected by the caller (threaded from server
/// boot) so this package stays dart:io-free.
// Implements: DIARY-DEV-linking-code-lifecycle/A+E
String generateLinkingCode({required String prefix, String sponsorKey = ''}) {
  final random = Random.secure();
  final body = List.generate(
    6,
    (_) => linkingCodeCharset[random.nextInt(linkingCodeCharset.length)],
  ).join();
  final input = '$prefix$body';
  return '$input${checkCharsFor(input, sponsorKey)}';
}
