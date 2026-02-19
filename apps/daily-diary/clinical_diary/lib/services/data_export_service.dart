// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation

import 'dart:convert';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/config/feature_flags.dart';
import 'package:clinical_diary/models/app_state_export.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/services/nosebleed_service.dart';
import 'package:clinical_diary/services/preferences_service.dart';
import 'package:clinical_diary/utils/date_time_formatter.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Result of an import operation
class ImportResult {
  const ImportResult._({
    required this.success,
    this.error,
    this.recordsImported = 0,
  });

  factory ImportResult.success({required int recordsImported}) =>
      ImportResult._(success: true, recordsImported: recordsImported);

  factory ImportResult.failure(String error) =>
      ImportResult._(success: false, error: error);

  final bool success;
  final String? error;
  final int recordsImported;
}

/// Service for exporting and importing app state data.
///
/// Handles the complete backup and restore of:
/// - Device UUID
/// - Feature flags (sponsor config)
/// - User preferences
/// - Timezone information
/// - All nosebleed records (full audit trail)
class DataExportService {
  DataExportService({
    required NosebleedService nosebleedService,
    required PreferencesService preferencesService,
    required EnrollmentService enrollmentService,
    FeatureFlagService? featureFlagService,
  }) : _nosebleedService = nosebleedService,
       _preferencesService = preferencesService,
       _enrollmentService = enrollmentService,
       _featureFlagService = featureFlagService ?? FeatureFlagService.instance;

  final NosebleedService _nosebleedService;
  final PreferencesService _preferencesService;
  final EnrollmentService _enrollmentService;
  final FeatureFlagService _featureFlagService;

  /// Export all app state to a JSON string.
  ///
  /// Captures:
  /// - Device UUID
  /// - Feature flags and sponsor ID
  /// - User preferences
  /// - Current timezone
  /// - All nosebleed records (raw event log)
  Future<String> exportAppState() async {
    // Get app version
    String appVersion;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.buildNumber.isNotEmpty
          ? '${packageInfo.version}+${packageInfo.buildNumber}'
          : packageInfo.version;
    } catch (e) {
      appVersion = '0.0.0';
    }

    // Get device UUID
    final deviceUuid = await _nosebleedService.getDeviceUuid();

    // Get feature flags
    final featureFlags = FeatureFlagsExport.fromService(_featureFlagService);

    // Get user preferences
    final userPrefs = await _preferencesService.getPreferences();
    final userPreferences = UserPreferencesExport.fromPreferences(userPrefs);

    // Get timezone
    final timezone = TimezoneExport.fromSystem();

    // Get all nosebleed records (raw event log for full audit trail)
    final nosebleedRecords = await _nosebleedService.getAllLocalRecords();

    // Create export
    final export = AppStateExport(
      exportVersion: AppStateExport.currentExportVersion,
      exportedAt: DateTime.now(),
      appVersion: appVersion,
      deviceUuid: deviceUuid,
      featureFlags: featureFlags,
      userPreferences: userPreferences,
      timezone: timezone,
      nosebleedRecords: nosebleedRecords,
    );

    // Convert to pretty JSON
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(export.toJson());
  }

  /// Import app state from a JSON string.
  ///
  /// This will:
  /// - Validate the JSON format
  /// - Restore feature flags (if sponsor matches or no current sponsor)
  /// - Restore user preferences
  /// - Import nosebleed records (merge with existing, skip duplicates)
  ///
  /// Returns an [ImportResult] indicating success or failure.
  Future<ImportResult> importAppState(String jsonString) async {
    try {
      // Parse JSON
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        return ImportResult.failure('Invalid JSON format: $e');
      }

      // Validate export version
      final exportVersion = json['exportVersion'] as int?;
      if (exportVersion == null) {
        return ImportResult.failure('Missing export version');
      }
      if (exportVersion > AppStateExport.currentExportVersion) {
        return ImportResult.failure(
          'Export version $exportVersion is newer than supported '
          '(${AppStateExport.currentExportVersion}). '
          'Please update the app.',
        );
      }

      // Parse export
      final AppStateExport export;
      try {
        export = AppStateExport.fromJson(json);
      } catch (e) {
        return ImportResult.failure('Failed to parse export data: $e');
      }

      // Restore feature flags
      export.featureFlags.applyToService(_featureFlagService);

      // Restore user preferences
      await _preferencesService.savePreferences(
        export.userPreferences.toUserPreferences(),
      );

      // Import nosebleed records
      final recordsImported = await _importNosebleedRecords(export);

      debugPrint(
        '[DataExportService] Import complete: $recordsImported records',
      );

      return ImportResult.success(recordsImported: recordsImported);
    } catch (e, stack) {
      debugPrint('[DataExportService] Import error: $e');
      debugPrint('[DataExportService] Stack: $stack');
      return ImportResult.failure('Import failed: $e');
    }
  }

  /// Import nosebleed records, skipping duplicates.
  ///
  /// Returns the number of records imported.
  Future<int> _importNosebleedRecords(AppStateExport export) async {
    // Get existing event IDs
    final existingRecords = await _nosebleedService.getAllLocalRecords();
    final existingIds = existingRecords.map((r) => r.id).toSet();

    debugPrint(
      '[DataExportService] Import: ${export.nosebleedRecords.length} records '
      'in file, ${existingIds.length} existing records',
    );

    // Get repository for direct event insertion
    final repository = Datastore.instance.repository;
    final deviceUuid = await _nosebleedService.getDeviceUuid();
    final userId = await _enrollmentService.getUserId() ?? 'anonymous';

    var importedCount = 0;
    var skippedCount = 0;

    for (final record in export.nosebleedRecords) {
      // Skip if record already exists
      if (existingIds.contains(record.id)) {
        skippedCount++;
        debugPrint(
          '[DataExportService] Skipping duplicate record: ${record.id}',
        );
        continue;
      }

      // Determine event type
      final eventType = record.isDeleted
          ? 'NosebleedDeleted'
          : 'NosebleedRecorded';

      // Build event data
      final data = <String, dynamic>{
        'recordId': record.id,
        'startTime': DateTimeFormatter.format(record.startTime),
        if (record.endTime != null)
          'endTime': DateTimeFormatter.format(record.endTime!),
        if (record.intensity != null) 'intensity': record.intensity!.name,
        if (record.notes != null) 'notes': record.notes,
        'isNoNosebleedsEvent': record.isNoNosebleedsEvent,
        'isUnknownEvent': record.isUnknownEvent,
        'isIncomplete': record.isIncomplete,
        'isDeleted': record.isDeleted,
        if (record.deleteReason != null) 'deleteReason': record.deleteReason,
        if (record.parentRecordId != null)
          'parentRecordId': record.parentRecordId,
        'imported': true,
        'importedFrom': export.deviceUuid,
      };

      // Append to datastore
      await repository.append(
        aggregateId:
            'diary-${record.startTime.year}-${record.startTime.month}-${record.startTime.day}',
        eventType: eventType,
        data: data,
        userId: userId,
        deviceId: record.deviceUuid ?? deviceUuid,
        clientTimestamp: record.createdAt,
      );

      importedCount++;
    }

    debugPrint(
      '[DataExportService] Import summary: $importedCount imported, '
      '$skippedCount skipped as duplicates',
    );

    return importedCount;
  }

  /// Generate a suggested filename for export.
  ///
  /// Format: hht-diary-export-YYYY-MM-DD-HHMMSS.json
  String generateExportFilename() {
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'
        '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'hht-diary-export-$timestamp.json';
  }
}
