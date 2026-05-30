// Implements: DIARY-BASE-sponsor-requested-settings/A — a setting applied by the
//   participant goes through the same settings-apply path (one setting_applied
//   event); user settings are never locked.
// Implements: DIARY-DEV-action-write-path/A — the write flows through the core
//   ActionDispatcher rather than a direct append.
//
// Diary per-app settings Actions (diary_actions). All three emit the same
// shared `setting_applied` event on the per-key `Setting` aggregate; they differ
// only in source/locked. The lock is stored explicitly on the event.
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';

EventDraft _settingDraft(SettingPayload payload) => EventDraft(
  aggregateType: settingAggregateType,
  aggregateId: payload.key,
  entryType: 'setting_applied',
  eventType: 'finalized',
  data: payload.toJson(),
);

/// Parsed input for [SetUserSettingAction].
class SetUserSettingInput {
  const SetUserSettingInput({required this.key, required this.value});
  final String key;
  final Object? value;
}

/// Records a participant-chosen setting as `setting_applied(source: user,
/// locked: false)`. Returns the setting key.
class SetUserSettingAction extends Action<SetUserSettingInput, String> {
  const SetUserSettingAction();

  @override
  String get name => 'set_user_setting';

  @override
  String get description => 'Participant changes one of their settings.';

  @override
  Set<Permission> get permissions => const <Permission>{};

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  SetUserSettingInput parseInput(Map<String, Object?> raw) {
    final key = raw['key'];
    if (key is! String || key.isEmpty) {
      throw const FormatException('key is required');
    }
    return SetUserSettingInput(key: key, value: raw['value']);
  }

  @override
  void validate(SetUserSettingInput input) {
    // Pure-structural only. The UI offers editing solely for unlocked keys, and
    // the diary-server re-validates compliance on ingest (defense-in-depth).
  }

  @override
  Future<ExecutionResult<String>> execute(
    SetUserSettingInput input,
    ActionContext ctx,
  ) async {
    final payload = SettingPayload(
      key: input.key,
      value: input.value,
      source: SettingSource.user,
      locked: false,
    );
    return ExecutionResult<String>(
      result: input.key,
      events: <EventDraft>[_settingDraft(payload)],
    );
  }
}

/// Parsed input for the sponsor-settings actions ([ApplySponsorSettingsAction]
/// and the unlock action): the `{key: value}` set to apply.
class SponsorSettingsInput {
  const SponsorSettingsInput({required this.settings});
  final Map<String, Object?> settings;
}

Map<String, Object?> _parseSettingsMap(Map<String, Object?> raw, String field) {
  final settings = raw[field];
  if (settings is! Map) {
    throw FormatException('$field map is required');
  }
  return settings.cast<String, Object?>();
}

/// Applies a portal-requested settings set: one `setting_applied(source:
/// sponsor, locked: true)` per key. This is the SAME apply path as the user
/// action — same event type — only source/locked differ. Returns the keys.
class ApplySponsorSettingsAction
    extends Action<SponsorSettingsInput, List<String>> {
  const ApplySponsorSettingsAction();

  @override
  String get name => 'apply_sponsor_settings';

  @override
  String get description =>
      'Diary applies (and locks) the sponsor-requested settings.';

  @override
  Set<Permission> get permissions => const <Permission>{};

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  SponsorSettingsInput parseInput(Map<String, Object?> raw) =>
      SponsorSettingsInput(settings: _parseSettingsMap(raw, 'settings'));

  @override
  void validate(SponsorSettingsInput input) {
    if (input.settings.isEmpty) {
      throw ArgumentError.value(
        input.settings,
        'settings',
        'a sponsor settings request must contain at least one setting',
      );
    }
  }

  @override
  Future<ExecutionResult<List<String>>> execute(
    SponsorSettingsInput input,
    ActionContext ctx,
  ) async {
    final events = <EventDraft>[
      for (final entry in input.settings.entries)
        _settingDraft(
          SettingPayload(
            key: entry.key,
            value: entry.value,
            source: SettingSource.sponsor,
            locked: true,
          ),
        ),
    ];
    return ExecutionResult<List<String>>(
      result: input.settings.keys.toList(),
      events: events,
    );
  }
}
