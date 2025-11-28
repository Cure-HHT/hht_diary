// IMPLEMENTS REQUIREMENTS:
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00013: Application Instance UUID Generation

/// Severity levels for nosebleed events
enum NosebleedSeverity {
  spotting,
  dripping,
  drippingQuickly,
  steadyStream,
  pouring,
  gushing;

  String get displayName {
    switch (this) {
      case NosebleedSeverity.spotting:
        return 'Spotting';
      case NosebleedSeverity.dripping:
        return 'Dripping';
      case NosebleedSeverity.drippingQuickly:
        return 'Dripping quickly';
      case NosebleedSeverity.steadyStream:
        return 'Steady stream';
      case NosebleedSeverity.pouring:
        return 'Pouring';
      case NosebleedSeverity.gushing:
        return 'Gushing';
    }
  }

  static NosebleedSeverity? fromString(String? value) {
    if (value == null) return null;
    return NosebleedSeverity.values.cast<NosebleedSeverity?>().firstWhere(
          (e) => e?.displayName == value || e?.name == value,
          orElse: () => null,
        );
  }
}

/// Represents a nosebleed event record
class NosebleedRecord {

  NosebleedRecord({
    required this.id,
    required this.date,
    this.startTime,
    this.endTime,
    this.severity,
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
      date: DateTime.parse(json['date'] as String),
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'] as String)
          : null,
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      severity: NosebleedSeverity.fromString(json['severity'] as String?),
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
  final DateTime date;
  final DateTime? startTime;
  final DateTime? endTime;
  final NosebleedSeverity? severity;
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
  bool get isRealEvent => !isNoNosebleedsEvent && !isUnknownEvent;

  /// Check if the record has all required data
  bool get isComplete =>
      isNoNosebleedsEvent ||
      isUnknownEvent ||
      (startTime != null && endTime != null && severity != null);

  /// Calculate duration in minutes
  int? get durationMinutes {
    if (startTime == null || endTime == null) return null;
    return endTime!.difference(startTime!).inMinutes;
  }

  /// Create a copy with updated fields
  NosebleedRecord copyWith({
    String? id,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    NosebleedSeverity? severity,
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
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      severity: severity ?? this.severity,
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
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'severity': severity?.name,
      'notes': notes,
      'isNoNosebleedsEvent': isNoNosebleedsEvent,
      'isUnknownEvent': isUnknownEvent,
      'isIncomplete': isIncomplete,
      'isDeleted': isDeleted,
      'deleteReason': deleteReason,
      'parentRecordId': parentRecordId,
      'deviceUuid': deviceUuid,
      'createdAt': createdAt.toIso8601String(),
      'syncedAt': syncedAt?.toIso8601String(),
    };
  }
}
