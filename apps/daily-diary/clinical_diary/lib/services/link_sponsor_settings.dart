// Implements: DIARY-BASE-sponsor-requested-settings/A+B — the portal requests
//   sponsor settings; the diary applies them through the SAME settings-apply
//   path a participant uses (the registered `apply_sponsor_settings` action,
//   NOT a direct event append), recording each `setting_applied(source: sponsor,
//   locked: true)`. The lock is stored explicitly on the event.
//
// The link-time delivery of branding (and any future sponsor-locked settings):
// the `/link` response carries a `sponsor_settings` batch — a list of
// `{key, value, locked}` — which the diary applies at the link transition.
//
// Idempotence is at the EVENT-LOG level, not merely the latest-wins view: we
// diff the incoming batch against the materialized `settings` projection and
// dispatch ONLY the keys whose (value, locked) differ (or are absent). An
// already-linked participant cold-restarting re-runs this with an unchanged
// batch and appends ZERO events; a genuinely changed branding value appends
// just that one key. This mirrors the portal seed's "emit only if differs".
import 'dart:async';

import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:reaction/reaction.dart';

/// Applies the `sponsor_settings` batch carried in a `/link` response through
/// the diary's normal action dispatcher. [batch] is the decoded
/// `sponsor_settings` list (each entry a `{key, value, locked}` map). An
/// empty/absent batch is a no-op (no dispatch). Returns the keys actually
/// applied (the changed subset).
///
/// The batch entries are already sponsor/locked; the `apply_sponsor_settings`
/// action stamps `source: sponsor, locked: true` regardless, so only the
/// `{key: value}` projection of the changed subset is forwarded.
///
/// Change detection: the existing materialized [SettingPayload] for a key is
/// read from the diary's `settings` projection. A key is in the applied subset
/// when it is absent, or its `value` differs from the incoming value, or it is
/// not currently `locked == true`. If the subset is empty the call dispatches
/// nothing.
// Implements: DIARY-BASE-sponsor-requested-settings/A+B
Future<List<String>> applyLinkSponsorSettings(
  LocalScope scope,
  List<Object?>? batch,
) async {
  if (batch == null || batch.isEmpty) return const <String>[];

  // Decode the batch into a {key: value} map (entries already sponsor/locked).
  final incoming = <String, Object?>{};
  for (final entry in batch) {
    if (entry is! Map) continue;
    final key = entry['key'];
    if (key is! String || key.isEmpty) continue;
    incoming[key] = entry['value'];
  }
  if (incoming.isEmpty) return const <String>[];

  // Read what is already materialized so we apply only genuine changes.
  final existing = await _currentSettings(scope);

  final changed = <String, Object?>{};
  incoming.forEach((key, value) {
    final current = existing[key];
    final differs =
        current == null || current.value != value || current.locked != true;
    if (differs) changed[key] = value;
  });
  if (changed.isEmpty) return const <String>[];

  await scope.actionSubmitter.submit(
    ActionSubmission(
      actionName: 'apply_sponsor_settings',
      rawInput: <String, Object?>{'settings': changed},
    ),
  );
  return changed.keys.toList();
}

/// One-shot read of the diary's `settings` projection into a
/// `{key: SettingPayload}` map. Drains the snapshot phase (every current row)
/// and returns once `EndOfReplay` arrives; live deltas are not consulted.
Future<Map<String, SettingPayload>> _currentSettings(LocalScope scope) async {
  final out = <String, SettingPayload>{};
  final done = Completer<void>();
  late final StreamSubscription<Update<Map<String, Object?>>> sub;
  sub = scope.viewSource
      .watch<Map<String, Object?>>(viewName: settingsViewName, mapper: (r) => r)
      .listen((u) {
        switch (u) {
          case Snapshot<Map<String, Object?>>(:final value):
            if (value != null) {
              final payload = SettingPayload.fromJson(value);
              out[payload.key] = payload;
            }
          case EndOfReplay<Map<String, Object?>>():
            if (!done.isCompleted) done.complete();
          default:
            break;
        }
      });
  await done.future;
  await sub.cancel();
  return out;
}
