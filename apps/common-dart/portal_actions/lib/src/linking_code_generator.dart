import 'dart:io';
import 'dart:math';

// Implements: DIARY-DEV-linking-code-lifecycle/A — server-side linking-code
//   generation: 2-char sponsor prefix + 8 chars from the non-ambiguous charset.
//   Mirrors legacy portal_functions generateParticipantLinkingCode.
const linkingCodeCharset =
    'ABCDEFGHJKLMNPQRTUVWXY346789'; // excludes I,1,O,0,S,5,Z,2

/// The sponsor prefix, from SPONSOR_LINKING_PREFIX (default 'XX').
String defaultSponsorLinkingPrefix() =>
    Platform.environment['SPONSOR_LINKING_PREFIX'] ?? 'XX';

/// Generate a linking code: [prefix] + 8 random chars from [linkingCodeCharset].
String generateLinkingCode({String? prefix}) {
  final p = prefix ?? defaultSponsorLinkingPrefix();
  final random = Random.secure();
  final body = List.generate(
    8,
    (_) => linkingCodeCharset[random.nextInt(linkingCodeCharset.length)],
  ).join();
  return '$p$body';
}
