// Implements: DIARY-BASE-sponsor-requested-settings/A+B — the portal requests
//   sponsor settings; the diary applies them through the SAME settings-apply
//   path a participant uses (the registered `apply_sponsor_settings` action,
//   NOT a direct event append), recording each `setting_applied(source: sponsor,
//   locked: true)`. The lock is stored explicitly on the event.
//
// The link-time delivery of branding (and any future sponsor-locked settings):
// the `/link` response carries a `sponsor_settings` batch — a list of
// `{key, value, locked}` — which the diary applies once at the link transition.
// Re-applying the same values is safe (settings are latest-wins), so this is
// idempotent and tolerant of being called again on a later reconcile.
import 'package:event_sourcing/event_sourcing.dart';
import 'package:reaction/reaction.dart';

/// Applies the `sponsor_settings` batch carried in a `/link` response through
/// the diary's normal action dispatcher. [batch] is the decoded
/// `sponsor_settings` list (each entry a `{key, value, locked}` map). An
/// empty/absent batch is a no-op (no dispatch). Returns the keys applied.
///
/// The batch entries are already sponsor/locked; the `apply_sponsor_settings`
/// action stamps `source: sponsor, locked: true` regardless, so only the
/// `{key: value}` projection of the batch is forwarded.
// Implements: DIARY-BASE-sponsor-requested-settings/A+B
Future<List<String>> applyLinkSponsorSettings(
  LocalScope scope,
  List<Object?>? batch,
) async {
  if (batch == null || batch.isEmpty) return const <String>[];

  final settings = <String, Object?>{};
  for (final entry in batch) {
    if (entry is! Map) continue;
    final key = entry['key'];
    if (key is! String || key.isEmpty) continue;
    settings[key] = entry['value'];
  }
  if (settings.isEmpty) return const <String>[];

  await scope.actionSubmitter.submit(
    ActionSubmission(
      actionName: 'apply_sponsor_settings',
      rawInput: <String, Object?>{'settings': settings},
    ),
  );
  return settings.keys.toList();
}
