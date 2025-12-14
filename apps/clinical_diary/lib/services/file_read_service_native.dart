// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'dart:io';

import 'package:flutter/foundation.dart';

/// Native implementation - reads files from the filesystem.
Future<String?> readFile(String path) async {
  try {
    final file = File(path);
    if (!file.existsSync()) {
      debugPrint('[FileReadService] File not found: $path');
      return null;
    }
    return file.readAsStringSync();
  } catch (e) {
    debugPrint('[FileReadService] Error reading file $path: $e');
    return null;
  }
}
