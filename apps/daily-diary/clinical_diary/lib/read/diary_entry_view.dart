// Implements: DIARY-DEV-reactive-read-path/B — typed view of a canonical diary
//   row; centralizes the clinical-field parsing that was scattered across
//   EventListItem and the recording screen. Display formatting (locale, device
//   timezone, intensity icons) stays in the widgets; this exposes typed data only.
import 'package:clinical_diary/read/diary_read.dart';
import 'package:diary_shared_model/diary_shared_model.dart';

sealed class DiaryEntryView {
  const DiaryEntryView(this.row, {required this.isComplete});
  final DiaryEntryRow row;
  final bool isComplete;
  String get aggregateId => row.aggregateId;
  String get entryType => row.entryType;
  String? get localDate => row.localDate;
}

/// Typed view of an `epistaxis_event` row.
///
/// Constructed eagerly from `row.data` via [EpistaxisEventPayload.fromJson];
/// **throws** (`FormatException`/`TypeError`) if the row does not conform to the
/// `EpistaxisEventPayload` schema. The event log is authoritative, so a
/// non-conforming row is a bug, not a recoverable condition — callers should not
/// expect to construct this from untrusted data.
class EpistaxisEntryView extends DiaryEntryView {
  EpistaxisEntryView(super.row, {required super.isComplete})
    : _payload = EpistaxisEventPayload.fromJson(row.data);
  final EpistaxisEventPayload _payload;
  DateTime get startTime => DateTime.parse(_payload.startTime);
  DateTime? get endTime =>
      _payload.endTime == null ? null : DateTime.parse(_payload.endTime!);
  String get startTimeZone => _payload.startTimeZone;
  String? get endTimeZone => _payload.endTimeZone;
  NosebleedIntensity? get intensity => _payload.intensity;
  int? get durationMinutes {
    final end = endTime;
    if (end == null) return null;
    if (end.isBefore(startTime)) return null;
    return end.difference(startTime).inMinutes;
  }

  bool get isMultiDay {
    final endTs = _payload.endTime;
    if (endTs == null) return false;
    // Compare the local wall-clock date portions directly from the raw ISO
    // timestamps. DateTime.parse normalises to UTC, so using .year/.month/.day
    // would silently shift the date for non-UTC offsets. _wallClockDate is
    // length-safe (no RangeError on a malformed short string).
    return _wallClockDate(_payload.startTime) != _wallClockDate(endTs);
  }

  /// The `yyyy-MM-dd` wall-clock date prefix of an ISO timestamp — the substring
  /// before `T`, mirroring how `canonicalEntryDate` derives the day. Length-safe.
  static String _wallClockDate(String iso) {
    final t = iso.indexOf('T');
    return t >= 0 ? iso.substring(0, t) : iso;
  }
}

class DayMarkerView extends DiaryEntryView {
  DayMarkerView(super.row, {super.isComplete = true});
}

DiaryEntryView diaryEntryViewOf(DiaryEntryRow row, {required bool isComplete}) {
  if (row.entryType == 'epistaxis_event') {
    return EpistaxisEntryView(row, isComplete: isComplete);
  }
  return DayMarkerView(row, isComplete: isComplete);
}
