// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'package:flutter/foundation.dart';

/// Web implementation - cannot read arbitrary local files.
/// Returns null with a debug message.
Future<String?> readFile(String path) async {
  debugPrint(
    '[FileReadService] Web platform cannot read local files. '
    'IMPORT_FILE is not supported on web.',
  );
  return null;
}
