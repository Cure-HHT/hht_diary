// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:clinical_diary/services/file_save_service_stub.dart'
    if (dart.library.html) 'package:clinical_diary/services/file_save_service_web.dart'
    if (dart.library.io) 'package:clinical_diary/services/file_save_service_native.dart'
    as impl;

/// Service for saving files in a platform-aware way.
///
/// On web: Triggers a browser download
/// On native: Uses file_picker save dialog
class FileSaveService {
  /// Save data to a file.
  ///
  /// On web, this triggers a browser download.
  /// On native platforms, this opens a save dialog.
  ///
  /// Returns true if the save was initiated (web) or completed (native).
  /// Returns false if the user cancelled or an error occurred.
  static Future<bool> saveFile({
    required String fileName,
    required String data,
    String? dialogTitle,
  }) {
    return impl.saveFile(
      fileName: fileName,
      data: data,
      dialogTitle: dialogTitle,
    );
  }
}
