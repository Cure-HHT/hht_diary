// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00013: Application Instance UUID Generation

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
class NosebleedRecord {
  NosebleedRecord({
    required this.id,
    required this.startTime,
    this.startTimezone,
    this.endTime,
    this.endTimezone,
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
  factory NosebleedRecord.fromJson(Map<String, dynamic> json) {
    return NosebleedRecord(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      startTimezone: json['startTimezone'] as String?,
      endTimezone: json['endTimezone'] as String?,
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
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      syncedAt: json['syncedAt'] != null
          ? DateTime.parse(json['syncedAt'] as String)
          : null,
    );
  }

  final String id;
  final DateTime startTime;
  final DateTime? endTime;

  /// IANA timezone string for start time (e.g., "America/New_York")
  /// If null, assumes device's current timezone for legacy records.
  final String? startTimezone;

  /// IANA timezone string for end time (e.g., "America/Los_Angeles")
  /// May differ from startTimezone if user traveled during the event.
  /// If null, assumes same as startTimezone.
  final String? endTimezone;

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
    DateTime? recordDate,
    DateTime? startTime,
    DateTime? endTime,
    String? startTimezone,
    String? endTimezone,
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
      startTimezone: startTimezone ?? this.startTimezone,
      endTimezone: endTimezone ?? this.endTimezone,
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

  /// Convert to JSON for local storage and API calls
  /// Times are stored as UTC ISO8601 strings for timezone-safe storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime?.toUtc().toIso8601String(),
      'startTimezone': startTimezone,
      'endTimezone': endTimezone,
      'intensity': intensity?.name,
      'notes': notes,
      'isNoNosebleedsEvent': isNoNosebleedsEvent,
      'isUnknownEvent': isUnknownEvent,
      'isIncomplete': isIncomplete,
      'isDeleted': isDeleted,
      'deleteReason': deleteReason,
      'parentRecordId': parentRecordId,
      'deviceUuid': deviceUuid,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'syncedAt': syncedAt?.toUtc().toIso8601String(),
    };
  }
}
