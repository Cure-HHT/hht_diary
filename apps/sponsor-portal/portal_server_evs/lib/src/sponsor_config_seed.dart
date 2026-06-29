// Implements: DIARY-DEV-sponsor-config-source/A+D+E — idempotent boot seed of the
//   sponsor configuration parameters into portal_settings; fail-fast when an
//   allow-set is restricted without a valid in-set default.
import 'package:event_sourcing/event_sourcing.dart';

const _platformLanguages = <String>['en', 'es', 'fr', 'de'];
const _platformFonts = <String>[
  'Roboto',
  'OpenDyslexic',
  'AtkinsonHyperlegible'
];

/// One seedable parameter: its setting key, its `PORTAL_SEED_*` env var, and a
/// parser from the raw env string to the stored value.
class _Param {
  const _Param(this.key, this.env, this.parse);
  final String key;
  final String env;
  final Object? Function(String raw) parse;
}

bool _parseBool(String raw) => true;
int _parseInt(String raw) => int.parse(raw.trim());
List<String> _parseList(String raw) {
  // Dedupe (preserving first-seen order) so idempotence is insensitive to
  // ordering/duplicates in the env value.
  final seen = <String>{};
  return [
    for (final s in raw.split(',').map((e) => e.trim()))
      if (s.isNotEmpty && seen.add(s)) s,
  ];
}

String _parseString(String raw) => raw.trim();

const _params = <_Param>[
  _Param('clinical.justificationThresholdHours',
      'PORTAL_SEED_CLINICAL_JUSTIFICATION_THRESHOLD_HOURS', _parseInt),
  _Param('clinical.lockThresholdHours',
      'PORTAL_SEED_CLINICAL_LOCK_THRESHOLD_HOURS', _parseInt),
  _Param('clinical.shortDurationConfirm',
      'PORTAL_SEED_CLINICAL_SHORT_DURATION_CONFIRM', _parseBool),
  _Param('clinical.longDurationConfirm',
      'PORTAL_SEED_CLINICAL_LONG_DURATION_CONFIRM', _parseBool),
  _Param('clinical.longDurationThresholdMinutes',
      'PORTAL_SEED_CLINICAL_LONG_DURATION_THRESHOLD_MINUTES', _parseInt),
  _Param('clinical.useReviewScreen', 'PORTAL_SEED_CLINICAL_USE_REVIEW_SCREEN',
      _parseBool),
  _Param('ui.useAnimations', 'PORTAL_SEED_UI_USE_ANIMATIONS', _parseBool),
  _Param('ui.availableFonts', 'PORTAL_SEED_UI_AVAILABLE_FONTS', _parseList),
  _Param('ui.defaultFont', 'PORTAL_SEED_UI_DEFAULT_FONT', _parseString),
  _Param('ui.availableLanguages', 'PORTAL_SEED_UI_AVAILABLE_LANGUAGES',
      _parseList),
  _Param('ui.defaultLanguage', 'PORTAL_SEED_UI_DEFAULT_LANGUAGE', _parseString),
  _Param('ui.notParticipatingMessage',
      'PORTAL_SEED_UI_NOT_PARTICIPATING_MESSAGE', _parseString),
  // Implements: DIARY-BASE-questionnaire-cycle-tracking/I
  _Param('questionnaire.cycle_tracking_enabled',
      'PORTAL_SEED_QUESTIONNAIRE_CYCLE_TRACKING_ENABLED', _parseBool),
  // Implements: DIARY-BASE-questionnaire-cycle-tracking/J
  _Param('questionnaire.require_initial_cycle_selection',
      'PORTAL_SEED_QUESTIONNAIRE_REQUIRE_INITIAL_CYCLE_SELECTION', _parseBool),
];

/// Seeds every configured sponsor configuration parameter into the
/// `portal_settings` store. Idempotent: appends a `portal_setting_changed` only
/// when the key is absent or its value differs from the materialized value.
Future<void> seedSponsorConfig({
  required EventStore eventStore,
  required StorageBackend backend,
  required Map<String, String> env,
}) async {
  // Parse every configured param up front so validation sees the full picture.
  final desired = <String, Object?>{};
  for (final p in _params) {
    final raw = env[p.env];
    if (raw == null || raw.isEmpty) continue;
    desired[p.key] = p.parse(raw);
  }

  _validateAllowSet(desired, 'ui.availableLanguages', 'ui.defaultLanguage',
      _platformLanguages);
  _validateAllowSet(
      desired, 'ui.availableFonts', 'ui.defaultFont', _platformFonts);

  final rows = await backend.findViewRows('portal_settings');
  final current = <String, Object?>{
    for (final r in rows) r['key'] as String: r['value'],
  };

  for (final entry in desired.entries) {
    if (current.containsKey(entry.key) &&
        _valueEq(current[entry.key], entry.value)) {
      continue; // unchanged — append nothing
    }
    await eventStore.append(
      entryType: 'portal_setting_changed',
      aggregateType: 'portal_setting',
      aggregateId: entry.key,
      eventType: 'portal_setting_changed',
      data: <String, Object?>{'key': entry.key, 'value': entry.value},
      initiator: const AutomationInitiator(service: 'sponsor-config-seed'),
    );
  }
}

/// Validates a seeded allow-set: every member must be a platform-supported value
/// (a sponsor can only RESTRICT the platform set, never extend it), and when the
/// set is restricted its [defaultKey] must be present and a member. Fail-fast on
/// either violation so a misconfigured deployment does not boot.
void _validateAllowSet(
  Map<String, Object?> desired,
  String allowKey,
  String defaultKey,
  List<String> platform,
) {
  final allow = desired[allowKey];
  if (allow is! List) return; // not configured
  final set = allow.whereType<String>().toList();

  final unsupported = set.where((v) => !platform.contains(v)).toList();
  if (unsupported.isNotEmpty) {
    throw StateError(
      'sponsor config: $allowKey contains unsupported value(s) $unsupported — '
      'supported values are $platform; refusing to start',
    );
  }

  final restricted = set.length < platform.length;
  if (!restricted) return;
  final def = desired[defaultKey];
  if (def is! String || !set.contains(def)) {
    throw StateError(
      'sponsor config: $allowKey is restricted to $set but $defaultKey '
      '(${def ?? 'unset'}) is not a member — refusing to start',
    );
  }
}

bool _valueEq(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  return a == b;
}
