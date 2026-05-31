// Implements: DIARY-DEV-shared-events-catalog/A+D
//   Refines: DIARY-BASE-sponsor-requested-settings
//
// The one generic, diary-originated settings event payload + the shared
// projection that folds it latest-per-key. The portal requests settings; the
// diary applies them through the SAME path a participant uses and records the
// result here, so the portal reads one stream to observe compliance (anti-drift).
// The lock is EXPLICIT and stored (`locked`), never inferred: after unlock the
// latest event for a sponsor key is still source=sponsor, so a stream-only
// reader needs the stored flag to tell locked from unlocked.
library;

import 'package:event_sourcing/event_sourcing.dart';

/// Aggregate type stamped on every settings event (one aggregate per key).
const String settingAggregateType = 'Setting';

/// View name of the canonical settings projection.
const String settingsViewName = 'settings';

/// Canonical settings projection: one row per setting key, latest
/// `setting_applied` event wins. Settings are superseded, never tombstoned,
/// so only the `finalized` kind is of interest.
const AggregateProjectionSpec settingsProjection = AggregateProjectionSpec(
  viewName: settingsViewName,
  interest: SubscriptionFilter(
    aggregateTypes: {settingAggregateType},
    eventTypes: {'finalized'},
  ),
  // Settings are superseded by the latest event, never deleted.
  tombstoneEventTypes: {},
);

/// Who applied a setting. `sponsor` settings are recorded `locked: true` while
/// the participant is participating; `user` settings are never locked.
enum SettingSource {
  user,
  sponsor;

  static SettingSource? fromWire(String? value) {
    if (value == null) return null;
    for (final s in SettingSource.values) {
      if (s.name == value) return s;
    }
    return null;
  }
}

/// Payload for a `setting_applied` event: the latest value of one setting [key],
/// who set it ([source]), and whether it is [locked] (read-only to the user).
class SettingPayload {
  const SettingPayload({
    required this.key,
    required this.value,
    required this.source,
    required this.locked,
  });

  /// Namespaced setting key (e.g. `pref.darkMode`, `clinical.lockThresholdHours`).
  /// The projection does not interpret it; the typed accessors do.
  final String key;

  /// JSON-encodable value; the key's schema governs the concrete type.
  final Object? value;

  final SettingSource source;
  final bool locked;

  factory SettingPayload.fromJson(Map<String, Object?> json) {
    final source = SettingSource.fromWire(json['source'] as String?);
    if (source == null) {
      throw FormatException('invalid setting source: ${json['source']}');
    }
    return SettingPayload(
      key: json['key']! as String,
      value: json['value'],
      source: source,
      locked: json['locked']! as bool,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'value': value,
    'source': source.name,
    'locked': locked,
  };
}

/// Setting keys read by [EntryGateRules.fromSettings] (integer hours).
const String justificationThresholdHoursKey =
    'clinical.justificationThresholdHours';
const String lockThresholdHoursKey = 'clinical.lockThresholdHours';
