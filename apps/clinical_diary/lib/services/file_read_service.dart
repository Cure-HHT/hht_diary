// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/services/file_read_service_stub.dart'
    if (dart.library.html) 'package:clinical_diary/services/file_read_service_web.dart'
    if (dart.library.io) 'package:clinical_diary/services/file_read_service_native.dart'
    as impl;

/// Service for reading files from the filesystem in a platform-aware way.
///
/// On native: Reads files directly from the filesystem
/// On web: Not supported (returns null) - web cannot read arbitrary local files
class FileReadService {
  /// Read the contents of a file at the given path.
  ///
  /// Returns the file contents as a string, or null if:
  /// - The file doesn't exist
  /// - The platform doesn't support file reading (web)
  /// - An error occurred
  static Future<String?> readFile(String path) {
    return impl.readFile(path);
  }
}
