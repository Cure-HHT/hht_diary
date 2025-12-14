// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Web implementation - triggers a browser download
Future<bool> saveFile({
  required String fileName,
  required String data,
  String? dialogTitle,
}) async {
  try {
    // Convert string to bytes
    final bytes = Uint8List.fromList(data.codeUnits);

    // Create a blob from the bytes
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );

    // Create object URL for the blob
    final url = web.URL.createObjectURL(blob);

    // Create an anchor element and trigger download
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName
      ..style.display = 'none';

    web.document.body?.appendChild(anchor);
    anchor.click();
    web.document.body?.removeChild(anchor);

    // Clean up the object URL
    web.URL.revokeObjectURL(url);

    return true;
  } catch (e) {
    debugPrint('Web download error: $e');
    return false;
  }
}
