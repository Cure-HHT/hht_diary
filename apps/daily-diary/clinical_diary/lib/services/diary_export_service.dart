// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//
// Implements: REQ-d00004 — full local audit trail can be exported as JSON
// for support, debugging, and recovery.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Result of a successful [DiaryExportService.exportAll] call.
class DiaryExportResult {
  const DiaryExportResult({required this.filename, required this.payload});

  /// Suggested filename of the form `hht-diary-export-YYYY-MM-DD-HHMMSS.json`.
  final String filename;

  /// JSON-encodable map carrying the full local event log plus metadata.
  final Map<String, Object?> payload;
}

/// Exports the local event-sourcing log as JSON.
///
/// Mirrors the legacy export's metadata wrapper but replaces the per-record
/// nosebleed payload with the raw [StoredEvent] audit trail. Import is
/// deferred to a follow-up ticket — re-importing JSON would require
/// translating legacy event shapes back to the new `EntryService.record` API
/// which would be exactly the kind of legacy-shape adapter we're avoiding.
class DiaryExportService {
  DiaryExportService({
    required SembastBackend backend,
    required String deviceId,
    Future<PackageInfo> Function()? packageInfoLoader,
    DateTime Function()? clock,
  }) : _backend = backend,
       _deviceId = deviceId,
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _clock = clock ?? DateTime.now;

  static const int _exportVersion = 2;

  final SembastBackend _backend;
  final String _deviceId;
  final Future<PackageInfo> Function() _packageInfoLoader;
  final DateTime Function() _clock;

  /// Build a JSON-encodable payload containing the full local event log,
  /// stamped with metadata, and a suggested filename.
  ///
  /// The [DiaryExportResult.payload] shape:
  /// ```json
  /// {
  ///   "exportVersion": 2,
  ///   "exportedAt": "<ISO 8601 with offset>",
  ///   "appVersion": "<from PackageInfo>",
  ///   "deviceUuid": "<from constructor>",
  ///   "events": [<every StoredEvent in the local log, serialized via toJson()>]
  /// }
  /// ```
  Future<DiaryExportResult> exportAll() async {
    final exportedAt = _clock();
    final appVersion = await _readAppVersion();
    final events = await _backend.findAllEvents();

    final payload = <String, Object?>{
      'exportVersion': _exportVersion,
      'exportedAt': _formatLocalIso(exportedAt),
      'appVersion': appVersion,
      'deviceUuid': _deviceId,
      'events': events.map((e) => e.toJson()).toList(),
    };

    return DiaryExportResult(
      filename: _generateFilename(exportedAt),
      payload: payload,
    );
  }

  Future<String> _readAppVersion() async {
    try {
      final pkg = await _packageInfoLoader();
      return pkg.buildNumber.isNotEmpty
          ? '${pkg.version}+${pkg.buildNumber}'
          : pkg.version;
    } catch (_) {
      return '0.0.0';
    }
  }

  /// Generate a suggested filename for the export.
  ///
  /// Format: `hht-diary-export-YYYY-MM-DD-HHMMSS.json`. Preserved verbatim
  /// from the legacy data-export service so external tooling that grepped on
  /// this prefix keeps working.
  static String _generateFilename(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    final timestamp =
        '${now.year}-${two(now.month)}-${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return 'hht-diary-export-$timestamp.json';
  }

  /// Format a [DateTime] as ISO 8601 with explicit timezone offset.
  ///
  /// Mirrors the legacy `DateTimeFormatter.format` but inlined to keep this
  /// service free of imports from clinical_diary's own utils package
  /// (callers can pass any [DateTime] — local or UTC — and get a sensible
  /// representation).
  static String _formatLocalIso(DateTime dt) {
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hh = offset.inHours.abs().toString().padLeft(2, '0');
    final mm = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    final base =
        '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)}'
        'T${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}'
        '.${three(dt.millisecond)}';
    return '$base$sign$hh:$mm';
  }
}
