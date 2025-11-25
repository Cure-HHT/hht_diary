// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00013: Application Instance UUID Generation

import 'dart:async';
import 'dart:convert';

import 'package:clinical_diary/config/app_config.dart';
import 'package:clinical_diary/models/nosebleed_record.dart';
import 'package:clinical_diary/services/enrollment_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service for managing nosebleed records with offline-first architecture
/// All operations are append-only - records cannot be updated or deleted
/// Uses HTTP calls to Firebase Functions for cloud sync
class NosebleedService {

  NosebleedService({
    required EnrollmentService enrollmentService,
    http.Client? httpClient,
  })  : _enrollmentService = enrollmentService,
        _httpClient = httpClient ?? http.Client();
  static const _localRecordsKey = 'nosebleed_records';
  static const _deviceUuidKey = 'device_uuid';

  final EnrollmentService _enrollmentService;
  final http.Client _httpClient;
  final Uuid _uuid = const Uuid();

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

  /// Get all local records
  Future<List<NosebleedRecord>> getLocalRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_localRecordsKey);
    if (data == null) return [];

    try {
      final jsonList = jsonDecode(data) as List<dynamic>;
      return jsonList
          .map((json) => NosebleedRecord.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save records to local storage
  Future<void> _saveLocalRecords(List<NosebleedRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = records.map((r) => r.toJson()).toList();
    await prefs.setString(_localRecordsKey, jsonEncode(jsonList));
  }

  /// Add a new nosebleed record (append-only)
  /// This is the primary way to create records - no updates allowed
  Future<NosebleedRecord> addRecord({
    required DateTime date,
    DateTime? startTime,
    DateTime? endTime,
    NosebleedSeverity? severity,
    String? notes,
    bool isNoNosebleedsEvent = false,
    bool isUnknownEvent = false,
  }) async {
    final deviceUuid = await getDeviceUuid();
    final record = NosebleedRecord(
      id: generateRecordId(),
      date: date,
      startTime: startTime,
      endTime: endTime,
      severity: severity,
      notes: notes,
      isNoNosebleedsEvent: isNoNosebleedsEvent,
      isUnknownEvent: isUnknownEvent,
      isIncomplete: !isNoNosebleedsEvent &&
          !isUnknownEvent &&
          (startTime == null || endTime == null || severity == null),
      deviceUuid: deviceUuid,
      createdAt: DateTime.now(),
    );

    // Save locally first (offline-first)
    final records = await getLocalRecords();
    records.add(record);
    await _saveLocalRecords(records);

    // Try to sync to cloud (non-blocking)
    unawaited(_syncRecordToCloud(record));

    return record;
  }

  /// Mark a day as having no nosebleeds
  Future<NosebleedRecord> markNoNosebleeds(DateTime date) async {
    return addRecord(
      date: date,
      startTime: date,
      isNoNosebleedsEvent: true,
    );
  }

  /// Mark a day as unknown (don't remember)
  Future<NosebleedRecord> markUnknown(DateTime date) async {
    return addRecord(
      date: date,
      startTime: date,
      isUnknownEvent: true,
    );
  }

  /// Complete an incomplete record by adding a new complete version
  /// The original incomplete record is kept for audit trail
  Future<NosebleedRecord> completeRecord({
    required String originalRecordId,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
    required NosebleedSeverity severity,
    String? notes,
  }) async {
    // Mark the original as completed by adding a new complete record
    // We don't modify the original - append-only pattern
    return addRecord(
      date: date,
      startTime: startTime,
      endTime: endTime,
      severity: severity,
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
      ..sort((a, b) => (a.startTime ?? a.date).compareTo(b.startTime ?? b.date));
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
        // Update local record with sync time
        final records = await getLocalRecords();
        final index = records.indexWhere((r) => r.id == record.id);
        if (index != -1) {
          records[index] = record.copyWith(syncedAt: DateTime.now());
          await _saveLocalRecords(records);
        }
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
    final records = await getLocalRecords();
    final unsynced = records.where((r) => r.syncedAt == null).toList();

    if (unsynced.isEmpty) return;

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
          'records': unsynced.map((r) => r.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        // Update all synced records
        final now = DateTime.now();
        final updatedRecords = records.map((r) {
          if (r.syncedAt == null) {
            return r.copyWith(syncedAt: now);
          }
          return r;
        }).toList();
        await _saveLocalRecords(updatedRecords);
        debugPrint('Synced ${unsynced.length} records');
      } else {
        debugPrint('Bulk sync failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Bulk sync error: $e');
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
            .map((json) => NosebleedRecord.fromJson(json as Map<String, dynamic>))
            .toList();

        // Merge with local records (cloud records take precedence for same ID)
        final localRecords = await getLocalRecords();
        final localIds = localRecords.map((r) => r.id).toSet();

        for (final cloudRecord in cloudRecords) {
          if (!localIds.contains(cloudRecord.id)) {
            localRecords.add(cloudRecord.copyWith(syncedAt: DateTime.now()));
          }
        }

        await _saveLocalRecords(localRecords);
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
    final records = await getLocalRecords();
    return records.where((r) => r.syncedAt == null).length;
  }

  /// Clear all local data (for testing)
  Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localRecordsKey);
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}
