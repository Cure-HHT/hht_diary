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
  }) : _enrollmentService = enrollmentService,
       _httpClient = httpClient ?? http.Client(),
       _repository = repository;

  static const _deviceUuidKey = 'device_uuid';

  final EnrollmentService _enrollmentService;
  final http.Client _httpClient;
  final EventRepository? _repository;
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
  NosebleedRecord _eventToNosebleedRecord(StoredEvent event) {
    final data = event.data;
    return NosebleedRecord(
      // Use stored recordId if available, fallback to eventId for backwards compatibility
      id: data['recordId'] as String? ?? event.eventId,
      date: DateTime.parse(data['date'] as String),
      startTime: data['startTime'] != null
          ? DateTime.parse(data['startTime'] as String)
          : null,
      endTime: data['endTime'] != null
          ? DateTime.parse(data['endTime'] as String)
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
    );
  }

  /// Get local records with materialized view (latest version of each record)
  /// This "crunches" the append-only log to show only the current state
  Future<List<NosebleedRecord>> getLocalRecords() async {
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
  Future<NosebleedRecord> addRecord({
    required DateTime date,
    DateTime? startTime,
    DateTime? endTime,
    NosebleedIntensity? intensity,
    String? notes,
    bool isNoNosebleedsEvent = false,
    bool isUnknownEvent = false,
    String? parentRecordId,
  }) async {
    final deviceUuid = await getDeviceUuid();
    final record = NosebleedRecord(
      id: generateRecordId(),
      date: date,
      startTime: startTime,
      endTime: endTime,
      intensity: intensity,
      notes: notes,
      isNoNosebleedsEvent: isNoNosebleedsEvent,
      isUnknownEvent: isUnknownEvent,
      isIncomplete:
          !isNoNosebleedsEvent &&
          !isUnknownEvent &&
          (startTime == null || endTime == null || intensity == null),
      parentRecordId: parentRecordId,
      deviceUuid: deviceUuid,
      createdAt: DateTime.now(),
    );

    // Save to append-only datastore
    final userId = await _enrollmentService.getUserId() ?? 'anonymous';
    await _eventRepository.append(
      aggregateId: 'diary-${date.year}-${date.month}-${date.day}',
      eventType: 'NosebleedRecorded',
      data: {
        'recordId':
            record.id, // Store user-visible record ID for materialization
        'date': record.date.toIso8601String(),
        if (record.startTime != null)
          'startTime': record.startTime!.toIso8601String(),
        if (record.endTime != null)
          'endTime': record.endTime!.toIso8601String(),
        if (record.intensity != null) 'intensity': record.intensity!.name,
        if (record.notes != null) 'notes': record.notes,
        'isNoNosebleedsEvent': record.isNoNosebleedsEvent,
        'isUnknownEvent': record.isUnknownEvent,
        'isIncomplete': record.isIncomplete,
        if (record.parentRecordId != null)
          'parentRecordId': record.parentRecordId,
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
    required DateTime date,
    DateTime? startTime,
    DateTime? endTime,
    NosebleedIntensity? intensity,
    String? notes,
    bool isNoNosebleedsEvent = false,
    bool isUnknownEvent = false,
  }) async {
    return addRecord(
      date: date,
      startTime: startTime,
      endTime: endTime,
      intensity: intensity,
      notes: notes,
      isNoNosebleedsEvent: isNoNosebleedsEvent,
      isUnknownEvent: isUnknownEvent,
      parentRecordId: originalRecordId,
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
      date: DateTime.now(),
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
        'date': record.date.toIso8601String(),
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
    return addRecord(date: date, startTime: date, isNoNosebleedsEvent: true);
  }

  /// Mark a day as unknown (don't remember)
  Future<NosebleedRecord> markUnknown(DateTime date) async {
    return addRecord(date: date, startTime: date, isUnknownEvent: true);
  }

  /// Complete an incomplete record by adding a new complete version
  /// The original incomplete record is kept for audit trail
  Future<NosebleedRecord> completeRecord({
    required String originalRecordId,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
    required NosebleedIntensity intensity,
    String? notes,
  }) async {
    // Mark the original as completed by adding a new complete record
    // We don't modify the original - append-only pattern
    return addRecord(
      date: date,
      startTime: startTime,
      endTime: endTime,
      intensity: intensity,
      notes: notes,
    );
  }

  /// Get records for a specific date
  Future<List<NosebleedRecord>> getRecordsForDate(DateTime date) async {
    final records = await getLocalRecords();
    return records.where((r) {
      return r.date.year == date.year &&
          r.date.month == date.month &&
          r.date.day == date.day;
    }).toList();
  }

  /// Get records from the last 24 hours
  Future<List<NosebleedRecord>> getRecentRecords() async {
    final records = await getLocalRecords();
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    return records
        .where((r) => r.startTime?.isAfter(yesterday) ?? false)
        .toList()
      ..sort(
        (a, b) => (a.startTime ?? a.date).compareTo(b.startTime ?? b.date),
      );
  }

  /// Get incomplete records
  Future<List<NosebleedRecord>> getIncompleteRecords() async {
    final records = await getLocalRecords();
    return records.where((r) => r.isIncomplete).toList();
  }

  /// Check if there are records for yesterday
  Future<bool> hasRecordsForYesterday() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final records = await getRecordsForDate(yesterday);
    return records.isNotEmpty;
  }

  /// Sync a single record to cloud via HTTP
  Future<void> _syncRecordToCloud(NosebleedRecord record) async {
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
            await _eventRepository.append(
              aggregateId:
                  'diary-${cloudRecord.date.year}-${cloudRecord.date.month}-${cloudRecord.date.day}',
              eventType: 'NosebleedRecorded',
              data: {
                'recordId': cloudRecord.id, // Preserve cloud record ID
                'date': cloudRecord.date.toIso8601String(),
                if (cloudRecord.startTime != null)
                  'startTime': cloudRecord.startTime!.toIso8601String(),
                if (cloudRecord.endTime != null)
                  'endTime': cloudRecord.endTime!.toIso8601String(),
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
    final records = await getRecordsForDate(date);
    if (records.isEmpty) return DayStatus.notRecorded;

    final hasNosebleed = records.any((r) => r.isRealEvent && !r.isIncomplete);
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
  Future<Map<DateTime, DayStatus>> getDayStatusRange(
    DateTime start,
    DateTime end,
  ) async {
    final result = <DateTime, DayStatus>{};
    final records = await getLocalRecords();

    for (
      var date = start;
      date.isBefore(end) || date.isAtSameMomentAs(end);
      date = date.add(const Duration(days: 1))
    ) {
      final dayRecords = records.where((r) {
        return r.date.year == date.year &&
            r.date.month == date.month &&
            r.date.day == date.day;
      }).toList();

      if (dayRecords.isEmpty) {
        result[DateTime(date.year, date.month, date.day)] =
            DayStatus.notRecorded;
        continue;
      }

      final hasNosebleed = dayRecords.any(
        (r) => r.isRealEvent && !r.isIncomplete,
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

  /// Clear all local data (for testing)
  Future<void> clearLocalData() async {
    // Note: In production, we wouldn't allow clearing the append-only datastore
    // This is kept for testing purposes only
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceUuidKey);
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
