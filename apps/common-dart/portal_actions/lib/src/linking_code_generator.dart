import 'dart:math';

// Implements: DIARY-DEV-linking-code-lifecycle/A — server-side linking-code
//   generation: 2-char sponsor prefix + 8 chars from the non-ambiguous charset.
//   Mirrors legacy portal_functions generateParticipantLinkingCode.
const linkingCodeCharset =
    'ABCDEFGHJKLMNPQRTUVWXY346789'; // excludes I,1,O,0,S,5,Z,2

/// Generate a linking code: [prefix] + 8 random chars from [linkingCodeCharset].
///
/// The sponsor [prefix] is injected by the caller (threaded from server boot,
/// where SPONSOR_LINKING_PREFIX is read) so this package stays free of dart:io.
String generateLinkingCode({required String prefix}) {
  final random = Random.secure();
  final body = List.generate(
    8,
    (_) => linkingCodeCharset[random.nextInt(linkingCodeCharset.length)],
  ).join();
  return '$prefix$body';
}
