// ============================================================================
// Clinical Trial Diary - Flutter/Dart Data Models
// ============================================================================
//
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00011: ALCOA+ Data Integrity Principles
//   REQ-d00004: Local-First Data Entry Implementation
//
// These models match the JSONB schema defined in spec/JSONB_SCHEMA.md
// and validated by database functions in database/schema.sql
//
// ALCOA+ COMPLIANCE:
// - All enums use meaningful strings (not numbers) for Legibility
// - All timestamps use ISO 8601 format with timezone for Accuracy
// - UUIDs are RFC 9562 compliant (v7 recommended for time-ordering)
// - Data must be clear and unambiguous without database context (Legible)
//
// ============================================================================

import 'package:uuid/uuid.dart';

// ============================================================================
// TOP-LEVEL EVENT RECORD
// ============================================================================

/// Top-level event record that contains all diary events
///
/// This is the root structure stored in database JSONB columns:
/// - record_audit.data
/// - record_state.current_data
class EventRecord {
  /// Client-generated UUID (RFC 9562)
  /// Recommended: UUID v7 for time-ordered sorting
  /// Supported: UUID v4 for compatibility
  final String id;

  /// Event type with version number
  /// Format: "{type}-v{major}.{minor}"
  /// Examples: "epistaxis-v1.0", "survey-v2.1"
  final String versionedType;

  /// Type-specific event data
  /// Type must be EpistaxisRecord or SurveyRecord (or future types)
  final dynamic eventData;

  EventRecord({
    required this.id,
    required this.versionedType,
    required this.eventData,
  });

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'versioned_type': versionedType,
      'event_data': eventData.toJson(),
    };
  }

  /// Create from database JSON
  factory EventRecord.fromJson(Map<String, dynamic> json) {
    final versionedType = json['versioned_type'] as String;
    final eventType = versionedType.split('-v')[0];

    dynamic eventData;
    switch (eventType) {
      case 'epistaxis':
        eventData = EpistaxisRecord.fromJson(json['event_data']);
        break;
      case 'survey':
        eventData = SurveyRecord.fromJson(json['event_data']);
        break;
      default:
        throw ArgumentError('Unknown event type: $eventType');
    }

    return EventRecord(
      id: json['id'] as String,
      versionedType: versionedType,
      eventData: eventData,
    );
  }

  /// Generate new UUID v7 (time-ordered)
  /// Falls back to v4 if v7 not available
  static String generateUuid() {
    // TODO: Use UUID v7 when package supports it
    // For now, using v4
    return const Uuid().v4();
  }
}

// ============================================================================
// EPISTAXIS (NOSEBLEED) RECORD
// ============================================================================

/// Severity levels for nosebleed events
///
/// IMPORTANT: Uses meaningful strings (not numbers) per ALCOA+ principles
enum EpistaxisSeverity {
  minimal('minimal'),
  mild('mild'),
  moderate('moderate'),
  severe('severe'),
  verySevere('very_severe'),
  extreme('extreme');

  final String value;
  const EpistaxisSeverity(this.value);

  static EpistaxisSeverity fromString(String value) {
    return EpistaxisSeverity.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid severity: $value'),
    );
  }

  /// User-friendly display text
  String get displayText {
    switch (this) {
      case EpistaxisSeverity.minimal:
        return 'Minimal';
      case EpistaxisSeverity.mild:
        return 'Mild';
      case EpistaxisSeverity.moderate:
        return 'Moderate';
      case EpistaxisSeverity.severe:
        return 'Severe';
      case EpistaxisSeverity.verySevere:
        return 'Very Severe';
      case EpistaxisSeverity.extreme:
        return 'Extreme';
    }
  }
}

/// Epistaxis (nosebleed) event record
///
/// Versioned type: "epistaxis-v1.0"
class EpistaxisRecord {
  /// Event UUID (typically same as parent EventRecord.id)
  final String id;

  /// When nosebleed started (ISO 8601 with timezone)
  /// Example: "2025-10-15T14:30:00-05:00"
  final DateTime startTime;

  /// When nosebleed stopped (ISO 8601 with timezone)
  /// Null if ongoing or unknown
  final DateTime? endTime;

  /// Clinical severity rating
  /// Null if not applicable (e.g., no nosebleed event)
  final EpistaxisSeverity? severity;

  /// Patient-entered free-text notes
  /// Max recommended length: 2000 characters
  final String? userNotes;

  /// True if user confirmed NO nosebleeds occurred on this date
  /// Mutually exclusive with isUnknownNosebleedsEvent
  final bool isNoNosebleedsEvent;

  /// True if user cannot recall events for this date
  /// Mutually exclusive with isNoNosebleedsEvent
  final bool isUnknownNosebleedsEvent;

  /// True if entry is partial (e.g., only startTime recorded)
  /// User can complete later
  final bool isIncomplete;

  /// When record was last modified (ISO 8601 with timezone)
  /// Used for conflict detection in multi-device sync
  final DateTime lastModified;

  EpistaxisRecord({
    required this.id,
    required this.startTime,
    this.endTime,
    this.severity,
    this.userNotes,
    this.isNoNosebleedsEvent = false,
    this.isUnknownNosebleedsEvent = false,
    this.isIncomplete = false,
    required this.lastModified,
  }) {
    // Validate mutual exclusivity
    if (isNoNosebleedsEvent && isUnknownNosebleedsEvent) {
      throw ArgumentError(
        'isNoNosebleedsEvent and isUnknownNosebleedsEvent cannot both be true',
      );
    }

    // Validate special events don't have clinical data
    if ((isNoNosebleedsEvent || isUnknownNosebleedsEvent) && severity != null) {
      throw ArgumentError(
        'severity must be null when isNoNosebleedsEvent or isUnknownNosebleedsEvent is true',
      );
    }

    if ((isNoNosebleedsEvent || isUnknownNosebleedsEvent) && endTime != null) {
      throw ArgumentError(
        'endTime must be null when isNoNosebleedsEvent or isUnknownNosebleedsEvent is true',
      );
    }
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
      if (severity != null) 'severity': severity!.value,
      if (userNotes != null) 'user_notes': userNotes,
      if (isNoNosebleedsEvent) 'isNoNosebleedsEvent': isNoNosebleedsEvent,
      if (isUnknownNosebleedsEvent) 'isUnknownNosebleedsEvent': isUnknownNosebleedsEvent,
      if (isIncomplete) 'isIncomplete': isIncomplete,
      'lastModified': lastModified.toIso8601String(),
    };
  }

  /// Create from database JSON
  factory EpistaxisRecord.fromJson(Map<String, dynamic> json) {
    return EpistaxisRecord(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      severity: json['severity'] != null
          ? EpistaxisSeverity.fromString(json['severity'] as String)
          : null,
      userNotes: json['user_notes'] as String?,
      isNoNosebleedsEvent: json['isNoNosebleedsEvent'] as bool? ?? false,
      isUnknownNosebleedsEvent: json['isUnknownNosebleedsEvent'] as bool? ?? false,
      isIncomplete: json['isIncomplete'] as bool? ?? false,
      lastModified: DateTime.parse(json['lastModified'] as String),
    );
  }

  /// Create a new nosebleed event
  factory EpistaxisRecord.createNosebleed({
    required DateTime startTime,
    DateTime? endTime,
    EpistaxisSeverity? severity,
    String? userNotes,
    bool isIncomplete = false,
  }) {
    final now = DateTime.now();
    return EpistaxisRecord(
      id: EventRecord.generateUuid(),
      startTime: startTime,
      endTime: endTime,
      severity: severity,
      userNotes: userNotes,
      isIncomplete: isIncomplete,
      lastModified: now,
    );
  }

  /// Create a "no nosebleeds" confirmation event
  factory EpistaxisRecord.createNoNosebleeds({
    required DateTime date,
    String? userNotes,
  }) {
    final now = DateTime.now();
    return EpistaxisRecord(
      id: EventRecord.generateUuid(),
      startTime: date,
      userNotes: userNotes,
      isNoNosebleedsEvent: true,
      lastModified: now,
    );
  }

  /// Create an "unknown/don't recall" event
  factory EpistaxisRecord.createUnknown({
    required DateTime date,
    String? userNotes,
  }) {
    final now = DateTime.now();
    return EpistaxisRecord(
      id: EventRecord.generateUuid(),
      startTime: date,
      userNotes: userNotes,
      isUnknownNosebleedsEvent: true,
      lastModified: now,
    );
  }

  /// Create a copy with updated fields
  EpistaxisRecord copyWith({
    DateTime? startTime,
    DateTime? endTime,
    EpistaxisSeverity? severity,
    String? userNotes,
    bool? isIncomplete,
  }) {
    return EpistaxisRecord(
      id: id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      severity: severity ?? this.severity,
      userNotes: userNotes ?? this.userNotes,
      isNoNosebleedsEvent: isNoNosebleedsEvent,
      isUnknownNosebleedsEvent: isUnknownNosebleedsEvent,
      isIncomplete: isIncomplete ?? this.isIncomplete,
      lastModified: DateTime.now(), // Always update lastModified on changes
    );
  }
}

// ============================================================================
// SURVEY RECORD
// ============================================================================

/// A single question and response in a survey
class SurveyQuestion {
  /// Unique question identifier (stable across versions)
  /// Example: "q1_frequency", "q2_impact"
  final String questionId;

  /// Full text of question
  /// Stored for auditability even if question changes later
  final String questionText;

  /// Response value (type depends on question)
  /// Can be: int, double, String, bool, or List<String>
  /// Null if question was skipped
  final dynamic response;

  /// True if user explicitly skipped this question
  final bool skipped;

  SurveyQuestion({
    required this.questionId,
    required this.questionText,
    this.response,
    this.skipped = false,
  }) {
    // Validate response/skipped logic
    if (skipped && response != null) {
      throw ArgumentError(
        'response must be null when skipped=true for question $questionId',
      );
    }
    if (!skipped && response == null) {
      throw ArgumentError(
        'response is required when skipped=false for question $questionId',
      );
    }
    if (questionText.isEmpty) {
      throw ArgumentError('questionText cannot be empty');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'question_text': questionText,
      if (response != null) 'response': response,
      if (skipped) 'skipped': skipped,
    };
  }

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) {
    return SurveyQuestion(
      questionId: json['question_id'] as String,
      questionText: json['question_text'] as String,
      response: json['response'],
      skipped: json['skipped'] as bool? ?? false,
    );
  }
}

/// Survey scoring information
class SurveyScore {
  /// Total calculated score
  final num total;

  /// Named subscale scores
  /// Example: {"anxiety": 10, "depression": 15}
  final Map<String, num>? subscales;

  /// Version of scoring rubric used
  /// Format: "v{major}.{minor}"
  /// Example: "v1.2"
  final String rubricVersion;

  SurveyScore({
    required this.total,
    this.subscales,
    required this.rubricVersion,
  }) {
    if (!RegExp(r'^v\d+\.\d+$').hasMatch(rubricVersion)) {
      throw ArgumentError(
        'rubricVersion must match format v{major}.{minor}, got: $rubricVersion',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      if (subscales != null) 'subscales': subscales,
      'rubric_version': rubricVersion,
    };
  }

  factory SurveyScore.fromJson(Map<String, dynamic> json) {
    return SurveyScore(
      total: json['total'] as num,
      subscales: json['subscales'] != null
          ? Map<String, num>.from(json['subscales'] as Map)
          : null,
      rubricVersion: json['rubric_version'] as String,
    );
  }
}

/// Survey record with question/response pairs
///
/// Versioned type: "survey-v1.0"
class SurveyRecord {
  /// Event UUID (typically same as parent EventRecord.id)
  final String id;

  /// When survey was completed (ISO 8601 with timezone)
  final DateTime completedAt;

  /// Array of question/response pairs
  /// Must be non-empty
  final List<SurveyQuestion> survey;

  /// Calculated scores per rubric
  /// Null if survey incomplete or not scored
  final SurveyScore? score;

  /// When record was last modified (ISO 8601 with timezone)
  final DateTime lastModified;

  SurveyRecord({
    required this.id,
    required this.completedAt,
    required this.survey,
    this.score,
    required this.lastModified,
  }) {
    if (survey.isEmpty) {
      throw ArgumentError('survey must be non-empty');
    }

    // Check for duplicate question IDs
    final questionIds = survey.map((q) => q.questionId).toList();
    final uniqueIds = questionIds.toSet();
    if (questionIds.length != uniqueIds.length) {
      throw ArgumentError('survey contains duplicate question_id values');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'completedAt': completedAt.toIso8601String(),
      'survey': survey.map((q) => q.toJson()).toList(),
      if (score != null) 'score': score!.toJson(),
      'lastModified': lastModified.toIso8601String(),
    };
  }

  factory SurveyRecord.fromJson(Map<String, dynamic> json) {
    return SurveyRecord(
      id: json['id'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      survey: (json['survey'] as List)
          .map((q) => SurveyQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      score: json['score'] != null
          ? SurveyScore.fromJson(json['score'] as Map<String, dynamic>)
          : null,
      lastModified: DateTime.parse(json['lastModified'] as String),
    );
  }

  /// Create a new survey
  factory SurveyRecord.create({
    required List<SurveyQuestion> survey,
    SurveyScore? score,
  }) {
    final now = DateTime.now();
    return SurveyRecord(
      id: EventRecord.generateUuid(),
      completedAt: now,
      survey: survey,
      score: score,
      lastModified: now,
    );
  }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/// Get versioned type string for an event
String getVersionedType(dynamic eventData) {
  if (eventData is EpistaxisRecord) {
    return 'epistaxis-v1.0';
  } else if (eventData is SurveyRecord) {
    return 'survey-v1.0';
  } else {
    throw ArgumentError('Unknown event data type: ${eventData.runtimeType}');
  }
}

/// Create a complete EventRecord from event data
EventRecord createEventRecord(dynamic eventData) {
  final uuid = EventRecord.generateUuid();
  return EventRecord(
    id: uuid,
    versionedType: getVersionedType(eventData),
    eventData: eventData,
  );
}
