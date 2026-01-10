// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Native implementation - uses file_picker save dialog
Future<bool> saveFile({
  required String fileName,
  required String data,
  String? dialogTitle,
}) async {
  try {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle ?? 'Save file',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: utf8.encode(data),
    );
    return result != null;
  } catch (e) {
    debugPrint('Native save error: $e');
    rethrow;
  }
}
