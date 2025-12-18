// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00013: Application Instance UUID Generation
//   REQ-p00006: Offline-First Data Entry

import 'dart:async';
import 'dart:convert';

import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:clinical_diary/utils/date_time_formatter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Status of a day for calendar display
enum DayStatus { nosebleed, noNosebleed, unknown, incomplete, notRecorded }

/// Service for managing nosebleed records with offline-first architecture.
///
/// All operations are append-only - records cannot be updated or deleted.
/// Uses the append_only_datastore for local persistence with cryptographic
/// hash chain for tamper detection (FDA 21 CFR Part 11 compliance).
/// Uses HTTP calls to Firebase Functions for cloud sync.
class NosebleedService {
  NosebleedService({
    required EnrollmentService enrollmentService,
    http.Client? httpClient,
    EventRepository? repository,
    bool enableCloudSync = true,
  }) : _enrollmentService = enrollmentService,
       _httpClient = httpClient ?? http.Client(),
       _repository = repository,
       _enableCloudSync = enableCloudSync;

  static const _deviceUuidKey = 'device_uuid';

  final EnrollmentService _enrollmentService;
  final http.Client _httpClient;
  final EventRepository? _repository;
  final bool _enableCloudSync;
  final Uuid _uuid = const Uuid();

  /// Get the event repository (from Datastore singleton or injected for tests)
  EventRepository get _eventRepository =>
      _repository ?? Datastore.instance.repository;

  /// Get or create device UUID (persisted across app restarts)
  Future<String> getDeviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceUuid = prefs.getString(_deviceUuidKey);
    if (deviceUuid == null) {
      deviceUuid = _uuid.v4();
      await prefs.setString(_deviceUuidKey, deviceUuid);
    }
    return deviceUuid;
  }

  /// Generate a new record ID
  String generateRecordId() => _uuid.v4();

  /// Get all local records (raw event log - includes all versions)
  Future<List<NosebleedRecord>> getAllLocalRecords() async {
    try {
      final events = await _eventRepository.getAllEvents();
      return events
          .where(
            (e) =>
                e.eventType == 'NosebleedRecorded' ||
                e.eventType == 'NosebleedDeleted',
          )
          .map(_eventToNosebleedRecord)
          .toList();
    } catch (e) {
      debugPrint('Error getting local records: $e');
      return [];
    }
  }

  /// Convert a StoredEvent to a NosebleedRecord
  ///
  /// Uses DateTimeFormatter.parse() to ensure timestamps are converted to
  /// local time for correct display in the user's timezone (CUR-512).
  NosebleedRecord _eventToNosebleedRecord(StoredEvent event) {
    final data = event.data;
    return NosebleedRecord(
      // Use stored recordId if available, fallback to eventId for backwards compatibility
      id: data['recordId'] as String? ?? event.eventId,
      startTime: DateTimeFormatter.parse(data['startTime'] as String),
      endTime: data['endTime'] != null
          ? DateTimeFormatter.parse(data['endTime'] as String)
          : null,
      intensity: data['intensity'] != null
          ? NosebleedIntensity.values.firstWhere(
              (s) => s.name == data['intensity'],
              orElse: () => NosebleedIntensity.spotting,
            )
          : null,
      notes: data['notes'] as String?,
      isNoNosebleedsEvent: data['isNoNosebleedsEvent'] as bool? ?? false,
      isUnknownEvent: data['isUnknownEvent'] as bool? ?? false,
      isIncomplete: data['isIncomplete'] as bool? ?? false,
      isDeleted: data['isDeleted'] as bool? ?? false,
      deleteReason: data['deleteReason'] as String?,
      parentRecordId: data['parentRecordId'] as String?,
      deviceUuid: event.deviceId,
      createdAt: event.clientTimestamp,
      syncedAt: event.syncedAt,
      // CUR-516: Read timezone for UI restoration on incomplete records
      startTimeTimezone: data['startTimeTimezone'] as String?,
      endTimeTimezone: data['endTimeTimezone'] as String?,
    );
  }

  /// Get local records with materialized view (latest version of each record)
  /// This "crunches" the append-only log to show only the current state
  Future<List<NosebleedRecord>> getLocalMaterializedRecords() async {
    final allRecords = await getAllLocalRecords();
    return _materializeRecords(allRecords);
  }

  /// Materialize records: return only the latest version of each record chain
  /// Records with parentRecordId are updates to previous records
  List<NosebleedRecord> _materializeRecords(List<NosebleedRecord> allRecords) {
    // Build a map of record ID to its latest version
    // Records that have been superseded (have a child) should not appear
    final supersededIds = <String>{};
    for (final record in allRecords) {
      if (record.parentRecordId != null) {
        supersededIds.add(record.parentRecordId!);
      }
    }

    // Filter to only non-superseded, non-deleted records
    // Sort by createdAt descending (newest first)
    return allRecords
        .where((r) => !supersededIds.contains(r.id) && !r.isDeleted)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Add a new nosebleed record (append-only)
  /// This is the primary way to create records - no updates allowed
  ///
  /// All timestamps are stored in ISO 8601 format with timezone offset
  /// embedded (e.g., "2025-10-15T14:30:00.000-05:00"). This preserves
  /// the user's local timezone at the time of entry for clinical accuracy.
  ///
  /// CUR-516: [startTimeTimezone] stores the IANA timezone name (e.g.,
  /// "America/Los_Angeles") ONLY to restore the UI timezone selection
  Future<NosebleedRecord> addRecord({
    required DateTime startTime,
    DateTime? endTime,
    NosebleedIntensity? intensity,
    String? notes,
    bool isNoNosebleedsEvent = false,
    bool isUnknownEvent = false,
    String? parentRecordId,
    String? startTimeTimezone,
    String? endTimeTimezone,
  }) async {
    final deviceUuid = await getDeviceUuid();
    final record = NosebleedRecord(
      id: generateRecordId(),
      startTime: startTime,
      endTime: endTime,
      intensity: intensity,
      notes: notes,
      isNoNosebleedsEvent: isNoNosebleedsEvent,
      isUnknownEvent: isUnknownEvent,
      isIncomplete:
          !isNoNosebleedsEvent &&
          !isUnknownEvent &&
          (endTime == null || intensity == null),
      parentRecordId: parentRecordId,
      deviceUuid: deviceUuid,
      createdAt: DateTime.now(),
      startTimeTimezone: startTimeTimezone,
      endTimeTimezone: endTimeTimezone,
    );

    // Save to append-only datastore
    // Timestamps are stored in ISO 8601 with timezone offset
    final userId = await _enrollmentService.getUserId() ?? 'anonymous';
    await _eventRepository.append(
      aggregateId:
          'diary-${startTime.year}-${startTime.month}-${startTime.day}',
      eventType: 'NosebleedRecorded',
      data: {
        'recordId':
            record.id, // Store user-visible record ID for materialization
        'startTime': DateTimeFormatter.format(record.startTime),
        if (record.endTime != null)
          'endTime': DateTimeFormatter.format(record.endTime!),
        if (record.intensity != null) 'intensity': record.intensity!.name,
        if (record.notes != null) 'notes': record.notes,
        'isNoNosebleedsEvent': record.isNoNosebleedsEvent,
        'isUnknownEvent': record.isUnknownEvent,
        'isIncomplete': record.isIncomplete,
        if (record.parentRecordId != null)
          'parentRecordId': record.parentRecordId,
        if (record.startTimeTimezone != null)
          'startTimeTimezone': record.startTimeTimezone,
        if (record.endTimeTimezone != null)
          'endTimeTimezone': record.endTimeTimezone,
      },
      userId: userId,
      deviceId: deviceUuid,
      clientTimestamp: record.createdAt,
    );

    // Try to sync to cloud (non-blocking)
    unawaited(_syncRecordToCloud(record));

    return record;
  }

  /// Update an existing record (append-only pattern)
  /// Creates a new record that supersedes the original
  Future<NosebleedRecord> updateRecord({
    required String originalRecordId,
    required DateTime startTime,
    DateTime? endTime,
    NosebleedIntensity? intensity,
    String? notes,
    bool isNoNosebleedsEvent = false,
    bool isUnknownEvent = false,
    String? startTimeTimezone,
    String? endTimeTimezone,
  }) async {
    return addRecord(
      startTime: startTime,
      endTime: endTime,
      intensity: intensity,
      notes: notes,
      isNoNosebleedsEvent: isNoNosebleedsEvent,
      isUnknownEvent: isUnknownEvent,
      parentRecordId: originalRecordId,
      startTimeTimezone: startTimeTimezone,
      endTimeTimezone: endTimeTimezone,
    );
  }

  /// Delete a record (append-only pattern)
  /// Creates a deletion marker that supersedes the original
  Future<NosebleedRecord> deleteRecord({
    required String recordId,
    required String reason,
  }) async {
    final deviceUuid = await getDeviceUuid();
    final record = NosebleedRecord(
      id: generateRecordId(),
      startTime: DateTime.now(),
      isDeleted: true,
      deleteReason: reason,
      parentRecordId: recordId,
      deviceUuid: deviceUuid,
      createdAt: DateTime.now(),
    );

    // Save to append-only datastore
    final userId = await _enrollmentService.getUserId() ?? 'anonymous';
    await _eventRepository.append(
      aggregateId: 'diary-deletion-${record.id}',
      eventType: 'NosebleedDeleted',
      data: {
        'recordId':
            record.id, // Store user-visible record ID for materialization
        'startTime': DateTimeFormatter.format(record.startTime),
        'isDeleted': true,
        'deleteReason': reason,
        'parentRecordId': recordId,
      },
      userId: userId,
      deviceId: deviceUuid,
      clientTimestamp: record.createdAt,
    );

    // Try to sync to cloud (non-blocking)
    unawaited(_syncRecordToCloud(record));

    return record;
  }

  /// Mark a day as having no nosebleeds
  Future<NosebleedRecord> markNoNosebleeds(DateTime date) async {
    return addRecord(startTime: date, isNoNosebleedsEvent: true);
  }

  /// Mark a day as unknown (don't remember)
  Future<NosebleedRecord> markUnknown(DateTime date) async {
    return addRecord(startTime: date, isUnknownEvent: true);
  }

  /// Complete an incomplete record by adding a new complete version
  /// The original incomplete record is kept for audit trail
  Future<NosebleedRecord> completeRecord({
    required String originalRecordId,
    required DateTime startTime,
    required DateTime endTime,
    required NosebleedIntensity intensity,
    String? notes,
  }) async {
    // Mark the original as completed by adding a new complete record
    // We don't modify the original - append-only pattern
    return addRecord(
      startTime: startTime,
      endTime: endTime,
      intensity: intensity,
      notes: notes,
    );
  }

  /// Get records for a specific start date
  /// Compares using local time to handle UTC storage correctly
  Future<List<NosebleedRecord>> getRecordsForStartDate(DateTime date) async {
    final records = await getLocalMaterializedRecords();
    final localDate = date.toLocal();
    return records.where((r) {
      final localStartTime = r.startTime.toLocal();
      return localStartTime.year == localDate.year &&
          localStartTime.month == localDate.month &&
          localStartTime.day == localDate.day;
    }).toList();
  }

  /// Get records from the last 24 hours
  Future<List<NosebleedRecord>> getRecentRecords() async {
    final records = await getLocalMaterializedRecords();
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    return records.where((r) => r.startTime.isAfter(yesterday)).toList()
      ..sort((a, b) => (a.startTime).compareTo(b.startTime));
  }

  /// Get incomplete records
  Future<List<NosebleedRecord>> getIncompleteRecords() async {
    final records = await getLocalMaterializedRecords();
    return records.where((r) => r.isIncomplete).toList();
  }

  /// Check if there are records for yesterday
  Future<bool> hasRecordsForYesterday() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final records = await getRecordsForStartDate(yesterday);
    return records.isNotEmpty;
  }

  /// Sync a single record to cloud via HTTP
  /// TODO make a syncService, mock in unit tests
  Future<void> _syncRecordToCloud(NosebleedRecord record) async {
    // Skip sync in unit tests
    if (!_enableCloudSync) return;

    try {
      final jwtToken = await _enrollmentService.getJwtToken();
      if (jwtToken == null) return;

      final response = await _httpClient.post(
        Uri.parse(AppConfig.syncUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'records': [record.toJson()],
        }),
      );

      if (response.statusCode == 200) {
        // Mark event as synced in the datastore
        await _eventRepository.markEventsSynced([record.id]);
        debugPrint('Record synced successfully: ${record.id}');
      } else {
        debugPrint('Sync failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Silently fail - will retry on next sync
      debugPrint('Sync error: $e');
    }
  }

  /// Sync all unsynced records to cloud
  Future<void> syncAllRecords() async {
    await syncAllRecordsWithResult();
  }

  /// Sync all unsynced records to cloud and return result
  /// Returns [SyncResult] indicating success or failure with details
  Future<SyncResult> syncAllRecordsWithResult() async {
    final unsyncedEvents = await _eventRepository.getUnsyncedEvents();
    final unsynced = unsyncedEvents
        .where((e) => e.eventType == 'NosebleedRecorded')
        .map(_eventToNosebleedRecord)
        .toList();

    if (unsynced.isEmpty) {
      return SyncResult.success(syncedCount: 0);
    }

    try {
      final jwtToken = await _enrollmentService.getJwtToken();
      if (jwtToken == null) {
        return SyncResult.success(syncedCount: 0); // No auth, nothing to sync
      }

      final response = await _httpClient.post(
        Uri.parse(AppConfig.syncUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'records': unsynced.map((r) => r.toJson()).toList()}),
      );

      if (response.statusCode == 200) {
        // Mark all events as synced
        await _eventRepository.markEventsSynced(
          unsynced.map((r) => r.id).toList(),
        );
        debugPrint('Synced ${unsynced.length} records');
        return SyncResult.success(syncedCount: unsynced.length);
      } else {
        debugPrint('Bulk sync failed: ${response.statusCode}');
        return SyncResult.failure(
          'Server error: ${response.statusCode}',
          failedCount: unsynced.length,
        );
      }
    } catch (e) {
      debugPrint('Bulk sync error: $e');
      return SyncResult.failure(
        'Network error: $e',
        failedCount: unsynced.length,
      );
    }
  }

  /// Fetch records from cloud and merge with local
  Future<void> fetchRecordsFromCloud() async {
    try {
      final jwtToken = await _enrollmentService.getJwtToken();
      if (jwtToken == null) return;

      final response = await _httpClient.post(
        Uri.parse(AppConfig.getRecordsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
        final cloudRecords = (responseBody['records'] as List<dynamic>)
            .map(
              (json) => NosebleedRecord.fromJson(json as Map<String, dynamic>),
            )
            .toList();

        // Get existing event IDs
        final existingEvents = await _eventRepository.getAllEvents();
        final existingIds = existingEvents.map((e) => e.eventId).toSet();

        // Add cloud records that don't exist locally
        final deviceUuid = await getDeviceUuid();
        final userId = await _enrollmentService.getUserId() ?? 'anonymous';

        for (final cloudRecord in cloudRecords) {
          if (!existingIds.contains(cloudRecord.id)) {
            // Append cloud record to local datastore
            // Use DateTimeFormatter to preserve timezone offset in storage
            await _eventRepository.append(
              aggregateId:
                  'diary-${cloudRecord.startTime.year}-${cloudRecord.startTime.month}-${cloudRecord.startTime.day}',
              eventType: 'NosebleedRecorded',
              data: {
                'recordId': cloudRecord.id, // Preserve cloud record ID
                'startTime': DateTimeFormatter.format(cloudRecord.startTime),
                if (cloudRecord.endTime != null)
                  'endTime': DateTimeFormatter.format(cloudRecord.endTime!),
                if (cloudRecord.intensity != null)
                  'intensity': cloudRecord.intensity!.name,
                if (cloudRecord.notes != null) 'notes': cloudRecord.notes,
                'isNoNosebleedsEvent': cloudRecord.isNoNosebleedsEvent,
                'isUnknownEvent': cloudRecord.isUnknownEvent,
                'isIncomplete': cloudRecord.isIncomplete,
                'fromCloud': true,
              },
              userId: userId,
              deviceId: cloudRecord.deviceUuid ?? deviceUuid,
              clientTimestamp: cloudRecord.createdAt,
            );
          }
        }

        debugPrint('Fetched ${cloudRecords.length} records from cloud');
      } else {
        debugPrint('Fetch failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
    }
  }

  /// Get count of unsynced records
  Future<int> getUnsyncedCount() async {
    return _eventRepository.getUnsyncedCount();
  }

  /// Get status for a specific date (for calendar view)
  Future<DayStatus> getDayStatus(DateTime date) async {
    final records = await getRecordsForStartDate(date);
    if (records.isEmpty) {
      return DayStatus.notRecorded;
    }

    final hasNosebleed = records.any(
      (r) => r.isRealNosebleedEvent && !r.isIncomplete,
    );
    final hasNoNosebleed = records.any((r) => r.isNoNosebleedsEvent);
    final hasUnknown = records.any((r) => r.isUnknownEvent);
    final hasIncomplete = records.any((r) => r.isIncomplete);

    if (hasNosebleed) return DayStatus.nosebleed;
    if (hasNoNosebleed) return DayStatus.noNosebleed;
    if (hasUnknown) return DayStatus.unknown;
    if (hasIncomplete) return DayStatus.incomplete;
    return DayStatus.notRecorded;
  }

  /// Get status for a range of dates (for calendar view)
  /// Compares using local time to handle UTC storage correctly
  Future<Map<DateTime, DayStatus>> getDayStatusRange(
    DateTime start,
    DateTime end,
  ) async {
    final result = <DateTime, DayStatus>{};
    final records = await getLocalMaterializedRecords();

    for (
      var date = start;
      date.isBefore(end) || date.isAtSameMomentAs(end);
      date = date.add(const Duration(days: 1))
    ) {
      final localDate = date.toLocal();
      final dayRecords = records.where((r) {
        final localStartTime = r.startTime.toLocal();
        return localStartTime.year == localDate.year &&
            localStartTime.month == localDate.month &&
            localStartTime.day == localDate.day;
      }).toList();

      if (dayRecords.isEmpty) {
        result[DateTime(date.year, date.month, date.day)] =
            DayStatus.notRecorded;
        continue;
      }

      final hasNosebleed = dayRecords.any(
        (r) => r.isRealNosebleedEvent && !r.isIncomplete,
      );
      final hasNoNosebleed = dayRecords.any((r) => r.isNoNosebleedsEvent);
      final hasUnknown = dayRecords.any((r) => r.isUnknownEvent);
      final hasIncomplete = dayRecords.any((r) => r.isIncomplete);

      if (hasNosebleed) {
        result[DateTime(date.year, date.month, date.day)] = DayStatus.nosebleed;
      } else if (hasNoNosebleed) {
        result[DateTime(date.year, date.month, date.day)] =
            DayStatus.noNosebleed;
      } else if (hasUnknown) {
        result[DateTime(date.year, date.month, date.day)] = DayStatus.unknown;
      } else if (hasIncomplete) {
        result[DateTime(date.year, date.month, date.day)] =
            DayStatus.incomplete;
      } else {
        result[DateTime(date.year, date.month, date.day)] =
            DayStatus.notRecorded;
      }
    }

    return result;
  }

  /// Verify data integrity (check hash chain)
  Future<bool> verifyDataIntegrity() async {
    return _eventRepository.verifyIntegrity();
  }

  /// Clear all local data (for dev/test environments only).
  ///
  /// This completely deletes the local database and clears preferences.
  /// In production, this should never be called - the append-only datastore
  /// is designed to be immutable for FDA compliance.
  ///
  /// After calling this method, the Datastore is reset and ready for use
  /// with a fresh database.
  ///
  /// Set [reinitialize] to false in unit tests where Datastore initialization
  /// is handled manually with a test-specific config.
  @visibleForTesting
  Future<void> clearLocalData({bool reinitialize = true}) async {
    // Clear device UUID from preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceUuidKey);

    // Delete and reset the datastore (clears all event records)
    // This uses the Datastore singleton's deleteAndReset method which
    // properly closes the database, deletes the file, and resets state.
    if (Datastore.isInitialized) {
      await Datastore.instance.deleteAndReset();

      // Reinitialize the datastore with a fresh database (skip in tests)
      if (reinitialize) {
        final deviceId = _uuid.v4();
        await Datastore.initialize(
          config: DatastoreConfig.development(
            deviceId: deviceId,
            userId: 'anonymous',
          ),
        );
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}

/// Result of a sync operation
class SyncResult {
  const SyncResult._({
    required this.isSuccess,
    this.errorMessage,
    this.syncedCount = 0,
    this.failedCount = 0,
  });

  factory SyncResult.success({required int syncedCount}) =>
      SyncResult._(isSuccess: true, syncedCount: syncedCount);

  factory SyncResult.failure(String message, {required int failedCount}) =>
      SyncResult._(
        isSuccess: false,
        errorMessage: message,
        failedCount: failedCount,
      );

  final bool isSuccess;
  final String? errorMessage;
  final int syncedCount;
  final int failedCount;
}
