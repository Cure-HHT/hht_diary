// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

/// Stub implementation that throws if accidentally used.
/// This should never be called - the conditional import should select
/// either the web or native implementation.
Future<String?> readFile(String path) {
  throw UnsupportedError(
    'FileReadService stub called - conditional import failed',
  );
}
