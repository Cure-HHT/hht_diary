// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00013: Application Instance UUID Generation

import 'package:clinical_diary/utils/date_time_formatter.dart';

/// Intensity levels for nosebleed events
enum NosebleedIntensity {
  spotting,
  dripping,
  drippingQuickly,
  steadyStream,
  pouring,
  gushing;

  String get displayName {
    switch (this) {
      case NosebleedIntensity.spotting:
        return 'Spotting';
      case NosebleedIntensity.dripping:
        return 'Dripping';
      case NosebleedIntensity.drippingQuickly:
        return 'Dripping quickly';
      case NosebleedIntensity.steadyStream:
        return 'Steady stream';
      case NosebleedIntensity.pouring:
        return 'Pouring';
      case NosebleedIntensity.gushing:
        return 'Gushing';
    }
  }

  static NosebleedIntensity? fromString(String? value) {
    if (value == null) return null;
    return NosebleedIntensity.values.cast<NosebleedIntensity?>().firstWhere(
      (e) => e?.displayName == value || e?.name == value,
      orElse: () => null,
    );
  }
}

/// Represents a nosebleed event record
///
/// All timestamp fields (startTime, endTime, createdAt, syncedAt) are stored
/// as ISO 8601 strings with timezone offset embedded (e.g., "2025-10-15T14:30:00.000-05:00").
/// This preserves the user's local timezone at the time of entry for clinical accuracy.
class NosebleedRecord {
  NosebleedRecord({
    required this.id,
    required this.startTime,
    this.endTime,
    this.intensity,
    this.notes,
    this.isNoNosebleedsEvent = false,
    this.isUnknownEvent = false,
    this.isIncomplete = false,
    this.isDeleted = false,
    this.deleteReason,
    this.parentRecordId,
    this.deviceUuid,
    DateTime? createdAt,
    this.syncedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create from JSON (local storage and API responses)
  ///
  /// Timestamps are expected in ISO 8601 format with timezone offset
  /// (e.g., "2025-10-15T14:30:00.000-05:00"). Legacy formats without
  /// offset are also supported for backwards compatibility.
  ///
  /// All timestamps are converted to local time using DateTimeFormatter.parse()
  /// to ensure times display correctly in the user's timezone (CUR-512).
  factory NosebleedRecord.fromJson(Map<String, dynamic> json) {
    return NosebleedRecord(
      id: json['id'] as String,
      startTime: DateTimeFormatter.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTimeFormatter.parse(json['endTime'] as String)
          : null,
      intensity: NosebleedIntensity.fromString(json['intensity'] as String?),
      notes: json['notes'] as String?,
      isNoNosebleedsEvent: json['isNoNosebleedsEvent'] as bool? ?? false,
      isUnknownEvent: json['isUnknownEvent'] as bool? ?? false,
      isIncomplete: json['isIncomplete'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deleteReason: json['deleteReason'] as String?,
      parentRecordId: json['parentRecordId'] as String?,
      deviceUuid: json['deviceUuid'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTimeFormatter.parse(json['createdAt'] as String)
          : DateTime.now(),
      syncedAt: json['syncedAt'] != null
          ? DateTimeFormatter.parse(json['syncedAt'] as String)
          : null,
    );
  }

  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final NosebleedIntensity? intensity;
  final String? notes;
  final bool isNoNosebleedsEvent;
  final bool isUnknownEvent;
  final bool isIncomplete;
  final bool isDeleted;
  final String? deleteReason;
  final String? parentRecordId;
  final String? deviceUuid;
  final DateTime createdAt;
  final DateTime? syncedAt;

  /// Check if this is a real nosebleed event (not a "no nosebleed" or "unknown" marker)
  bool get isRealNosebleedEvent => !isNoNosebleedsEvent && !isUnknownEvent;

  /// Check if the record has all required data
  bool get isComplete =>
      isNoNosebleedsEvent ||
      isUnknownEvent ||
      (endTime != null && intensity != null);

  /// Calculate duration in minutes
  int? get durationMinutes {
    if (endTime == null) {
      return null;
    }
    if (endTime!.isBefore(startTime)) {
      return null;
    }
    return endTime!.difference(startTime).inMinutes;
  }

  /// Create a copy with updated fields
  NosebleedRecord copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    NosebleedIntensity? intensity,
    String? notes,
    bool? isNoNosebleedsEvent,
    bool? isUnknownEvent,
    bool? isIncomplete,
    bool? isDeleted,
    String? deleteReason,
    String? parentRecordId,
    String? deviceUuid,
    DateTime? createdAt,
    DateTime? syncedAt,
  }) {
    return NosebleedRecord(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      intensity: intensity ?? this.intensity,
      notes: notes ?? this.notes,
      isNoNosebleedsEvent: isNoNosebleedsEvent ?? this.isNoNosebleedsEvent,
      isUnknownEvent: isUnknownEvent ?? this.isUnknownEvent,
      isIncomplete: isIncomplete ?? this.isIncomplete,
      isDeleted: isDeleted ?? this.isDeleted,
      deleteReason: deleteReason ?? this.deleteReason,
      parentRecordId: parentRecordId ?? this.parentRecordId,
      deviceUuid: deviceUuid ?? this.deviceUuid,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  /// Convert to JSON for local storage and API calls.
  ///
  /// All timestamps are stored as ISO 8601 strings with timezone offset
  /// (e.g., "2025-10-15T14:30:00.000-05:00"). This preserves the user's
  /// local timezone at the time of entry for clinical accuracy.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': DateTimeFormatter.format(startTime),
      'endTime': endTime != null ? DateTimeFormatter.format(endTime!) : null,
      'intensity': intensity?.name,
      'notes': notes,
      'isNoNosebleedsEvent': isNoNosebleedsEvent,
      'isUnknownEvent': isUnknownEvent,
      'isIncomplete': isIncomplete,
      'isDeleted': isDeleted,
      'deleteReason': deleteReason,
      'parentRecordId': parentRecordId,
      'deviceUuid': deviceUuid,
      'createdAt': DateTimeFormatter.format(createdAt),
      'syncedAt': syncedAt != null ? DateTimeFormatter.format(syncedAt!) : null,
    };
  }
}
