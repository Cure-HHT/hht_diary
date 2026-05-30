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
