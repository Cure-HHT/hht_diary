// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

/// Stub implementation for unsupported platforms
Future<bool> saveFile({
  required String fileName,
  required String data,
  String? dialogTitle,
}) async {
  throw UnsupportedError('File saving not supported on this platform');
}
