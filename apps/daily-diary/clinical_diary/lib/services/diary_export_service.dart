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

/// Result of a [DiaryExportService.importAll] call.
class DiaryImportResult {
  const DiaryImportResult({
    required this.imported,
    required this.duplicates,
    required this.skipped,
  });

  /// Events ingested as new (not previously present in the local log).
  final int imported;

  /// Events that matched an event already in the local log (idempotent
  /// re-ingest, no mutation).
  final int duplicates;

  /// Events the importer could not parse, or that the EventStore refused
  /// at ingest time. The remainder of the import continues regardless so
  /// one bad row does not abort the whole file.
  final int skipped;
}

/// Exports and re-imports the local event-sourcing log as JSON.
///
/// Mirrors the legacy export's metadata wrapper but replaces the per-record
/// nosebleed payload with the raw [StoredEvent] audit trail. Import accepts
/// the same shape ([_exportVersion] only) and feeds each row through
/// [EventStore.ingestEvent], which is idempotent on `event_id`. Legacy
/// nosebleed-shape JSON is intentionally NOT supported.
class DiaryExportService {
  DiaryExportService({
    required SembastBackend backend,
    required String deviceId,
    EventStore? eventStore,
    Future<PackageInfo> Function()? packageInfoLoader,
    DateTime Function()? clock,
  }) : _backend = backend,
       _deviceId = deviceId,
       _eventStore = eventStore,
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
       _clock = clock ?? DateTime.now;

  static const int _exportVersion = 2;

  final SembastBackend _backend;
  final String _deviceId;
  final EventStore? _eventStore;
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

  /// Re-import a payload previously produced by [exportAll].
  ///
  /// Each event is fed through [EventStore.ingestEvent], which is
  /// idempotent on `event_id`: re-importing the same export against the
  /// same backend produces all duplicates; importing into a fresh backend
  /// produces all new events.
  ///
  /// One bad row never aborts the import: parse errors and per-event
  /// ingest exceptions count toward [DiaryImportResult.skipped] and the
  /// remaining rows continue to be processed.
  ///
  /// Throws [FormatException] when the payload is missing the required
  /// `exportVersion` / `events` fields, or when `exportVersion` does not
  /// match this service's [_exportVersion]. Throws [StateError] when the
  /// service was constructed without an [EventStore] (export-only mode).
  Future<DiaryImportResult> importAll(Map<String, Object?> payload) async {
    final eventStore = _eventStore;
    if (eventStore == null) {
      throw StateError(
        'DiaryExportService was constructed without an EventStore; '
        'importAll is unavailable.',
      );
    }

    final version = payload['exportVersion'];
    if (version is! int) {
      throw const FormatException(
        'Diary import: payload is missing required "exportVersion" int field.',
      );
    }
    if (version != _exportVersion) {
      throw FormatException(
        'Diary import: unsupported export version: $version '
        '(this build expects $_exportVersion).',
      );
    }

    final rawEvents = payload['events'];
    if (rawEvents is! List) {
      throw const FormatException(
        'Diary import: payload is missing required "events" list.',
      );
    }

    var imported = 0;
    var duplicates = 0;
    var skipped = 0;

    for (final raw in rawEvents) {
      try {
        if (raw is! Map) {
          skipped++;
          continue;
        }
        // StoredEvent.fromMap requires Map<String, Object?>; the JSON
        // decoder hands us Map<String, dynamic>, so normalize the shape.
        final eventMap = Map<String, Object?>.from(raw);
        final stored = StoredEvent.fromMap(eventMap, 0);
        final outcome = await eventStore.ingestEvent(stored);
        switch (outcome.outcome) {
          case IngestOutcome.ingested:
            imported++;
          case IngestOutcome.duplicate:
            duplicates++;
        }
      } catch (_) {
        // Per-event errors are absorbed: a single corrupt row should not
        // abort the rest of the import. The caller surfaces the count via
        // [DiaryImportResult.skipped] so the patient can see something
        // was missed.
        skipped++;
      }
    }

    return DiaryImportResult(
      imported: imported,
      duplicates: duplicates,
      skipped: skipped,
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
