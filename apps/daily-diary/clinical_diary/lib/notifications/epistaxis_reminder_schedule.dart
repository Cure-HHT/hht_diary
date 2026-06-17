// Implements: DIARY-PRD-notification-ongoing-epistaxis/G+H+I+J — the Reminder
//   Schedule is resolved from the event-sourced settings projection: a present,
//   non-null sponsor schedule wins and the personal schedule is NOT applied (J);
//   otherwise the personal schedule applies (H); otherwise the empty default,
//   yielding no reminders (G). Sponsor configurability is the `reminder.
//   epistaxisScheduleSponsor` key delivered set-once-at-link (I).
//
// Pure derivation, mirroring `SponsorUiConfig.fromSettings` /
// `userPreferencesFromSettings`: no I/O, deterministic, defensive about the
// stored wire shape (a `List` of minute integers from an unvalidated source).
import 'package:diary_shared_model/diary_shared_model.dart';

/// Settings-stream key for the participant's personal Reminder Schedule
/// (`source: user`). Value is a `List<int>` of whole minutes.
const String reminderEpistaxisScheduleKey = 'reminder.epistaxisSchedule';

/// Settings-stream key for the *Sponsor*-configured Reminder Schedule
/// (`source: sponsor`, `locked: true`), delivered in the `/link`
/// `sponsor_settings` batch. Value is a `List<int>` of whole minutes. When this
/// key carries a `List` value it is "in effect" and overrides the personal key.
const String reminderEpistaxisScheduleSponsorKey =
    'reminder.epistaxisScheduleSponsor';

/// Upper bound on a single interval (minutes). Defense-in-depth against a
/// hand-authored deployment asset or settings row carrying an absurd value;
/// a nosebleed reminder beyond a day is meaningless.
const int _kMaxIntervalMinutes = 24 * 60;

/// Personal-use default schedule (whole minutes), applied when neither a
/// *Sponsor* nor a personal schedule has been configured.
///
/// NOTE: the platform spec `DIARY-PRD-notification-ongoing-epistaxis/G` defines
/// the default as *empty* (no reminders). Per the CUR-863 product decision this
/// deployment ships a non-empty personal-use default so reminders work out of
/// the box when the app is not connected to a *Sponsor*. A participant can still
/// turn reminders off explicitly (an empty personal schedule, see below), which
/// is distinct from "never configured".
const List<int> kDefaultEpistaxisReminderScheduleMinutes = <int>[5, 10, 15, 30];

/// Resolves the effective Ongoing Epistaxis Reminder Schedule from the folded
/// settings map.
///
/// Precedence (assertions I/J + CUR-863 default):
/// 1. If the *Sponsor* key holds a `List` value → use it (the sponsor schedule
///    is "in effect" and the personal schedule is ignored, per J — even when
///    the sponsor list is empty, which is a deliberate "no reminders" policy).
/// 2. Else if the personal key is *present* → use it (H). A present-but-empty
///    personal schedule is an explicit "Off" and yields no reminders; this is
///    distinct from the key being absent.
/// 3. Else (never configured) → [kDefaultEpistaxisReminderScheduleMinutes].
///
/// Each parsed interval must be a positive whole number of minutes; non-numeric,
/// zero, negative, and over-[_kMaxIntervalMinutes] entries are dropped. Order is
/// preserved (the schedule is an ordered list; each interval is measured from
/// the previous notification — see [fireTimesFor]).
List<Duration> resolveEpistaxisReminderSchedule(
  Map<String, SettingPayload> settings,
) {
  final sponsor = settings[reminderEpistaxisScheduleSponsorKey]?.value;
  if (sponsor is List) {
    return _parseMinutes(sponsor);
  }
  final personalPayload = settings[reminderEpistaxisScheduleKey];
  if (personalPayload != null) {
    final personal = personalPayload.value;
    // Present key (incl. an explicit empty "Off") wins over the default.
    return personal is List ? _parseMinutes(personal) : const <Duration>[];
  }
  // Never configured → personal-use default.
  return _parseMinutes(kDefaultEpistaxisReminderScheduleMinutes);
}

/// Parses a wire `List` of minute values into positive [Duration]s, preserving
/// order and dropping anything that is not a positive whole minute within range.
List<Duration> _parseMinutes(List<Object?> raw) {
  final out = <Duration>[];
  for (final entry in raw) {
    final minutes = switch (entry) {
      final int i => i,
      // Tolerate a JSON-decoded double that is integral (e.g. 5.0).
      final double d when d == d.roundToDouble() => d.toInt(),
      _ => null,
    };
    if (minutes == null || minutes <= 0 || minutes > _kMaxIntervalMinutes) {
      continue;
    }
    out.add(Duration(minutes: minutes));
  }
  return List<Duration>.unmodifiable(out);
}

/// Computes the absolute UTC fire times for one Incomplete Record, given the
/// [anchorUtc] (the participant's most recent interaction with the record) and
/// the resolved [schedule].
///
/// Each interval is measured from the time of the *previous* notification, with
/// the first measured from [anchorUtc] (the Reminder Schedule definition). The
/// returned list therefore holds the cumulative-sum offsets:
/// `anchor + s0`, `anchor + s0 + s1`, … — exactly one entry per interval, and
/// none after the final interval (assertions A/B/C). An empty [schedule]
/// yields no fire times (G).
// Implements: DIARY-PRD-notification-ongoing-epistaxis/A+B+C
List<DateTime> fireTimesFor(DateTime anchorUtc, List<Duration> schedule) {
  final anchor = anchorUtc.toUtc();
  final out = <DateTime>[];
  var elapsed = Duration.zero;
  for (final interval in schedule) {
    elapsed += interval;
    out.add(anchor.add(elapsed));
  }
  return List<DateTime>.unmodifiable(out);
}
