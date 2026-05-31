// Implements: DIARY-DEV-shared-events-catalog/A+D
//   Refines: DIARY-PRD-epistaxis-capture-standard
//
// Typed payload schemas for the diary-originated clinical entry types, frozen
// with the diary/portal cross-wire surface on 2026-05-29
// (docs/evs-lib-port/diary-event-surface.md). The JSON maps here ARE the
// cross-wire payload contract; the classes are the typed Dart view shared by
// every consumer. Per assertion D, payloads carry no OTP / recovery / session
// tokens. The event "kind" (finalized / tombstone / checkpoint) rides in event
// metadata, not in the payload.
library;

/// Nosebleed severity, in ascending intensity. The wire value is the enum
/// [name] (e.g. `drippingQuickly`).
enum NosebleedIntensity {
  spotting,
  dripping,
  drippingQuickly,
  steadyStream,
  pouring,
  gushing;

  /// Parses a wire value; returns `null` for null or unrecognized input.
  static NosebleedIntensity? fromWire(String? value) {
    if (value == null) return null;
    for (final intensity in NosebleedIntensity.values) {
      if (intensity.name == value) return intensity;
    }
    return null;
  }
}

/// Payload for an `epistaxis_event` (a recorded nosebleed).
///
/// [startTime] / [endTime] are ISO 8601 timestamps that include the UTC offset.
/// [startTimeZone] / [endTimeZone] are IANA zone ids (e.g. `America/New_York`).
/// [startTimeUtcOffset] / [endTimeUtcOffset] are the ISO offset (e.g. `-05:00`)
/// captured at event time and MUST equal the offset embedded in the matching
/// timestamp.
class EpistaxisEventPayload {
  const EpistaxisEventPayload({
    required this.startTime,
    required this.startTimeZone,
    required this.startTimeUtcOffset,
    this.endTime,
    this.endTimeZone,
    this.endTimeUtcOffset,
    this.intensity,
  });

  final String startTime;
  final String startTimeZone;
  final String startTimeUtcOffset;
  final String? endTime;
  final String? endTimeZone;
  final String? endTimeUtcOffset;
  final NosebleedIntensity? intensity;

  factory EpistaxisEventPayload.fromJson(Map<String, Object?> json) {
    return EpistaxisEventPayload(
      startTime: json['startTime']! as String,
      startTimeZone: json['startTimeZone']! as String,
      startTimeUtcOffset: json['startTimeUtcOffset']! as String,
      endTime: json['endTime'] as String?,
      endTimeZone: json['endTimeZone'] as String?,
      endTimeUtcOffset: json['endTimeUtcOffset'] as String?,
      intensity: NosebleedIntensity.fromWire(json['intensity'] as String?),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'startTime': startTime,
      'startTimeZone': startTimeZone,
      'startTimeUtcOffset': startTimeUtcOffset,
      if (endTime != null) 'endTime': endTime,
      if (endTimeZone != null) 'endTimeZone': endTimeZone,
      if (endTimeUtcOffset != null) 'endTimeUtcOffset': endTimeUtcOffset,
      if (intensity != null) 'intensity': intensity!.name,
    };
  }
}

/// Payload for a `no_epistaxis_event` or `unknown_day_event` — the local
/// calendar [date] (ISO 8601, e.g. `2025-10-15`) the assertion covers. Both
/// entry types share this shape; the entry-type id distinguishes them.
class DayMarkerPayload {
  const DayMarkerPayload({required this.date});

  final String date;

  factory DayMarkerPayload.fromJson(Map<String, Object?> json) {
    return DayMarkerPayload(date: json['date']! as String);
  }

  Map<String, Object?> toJson() => <String, Object?>{'date': date};
}
