import 'package:collection/collection.dart';

/// Metadata describing one entry type supported by the mobile diary.
///
/// An `EntryTypeDefinition` is pure data (no storage, no Flutter dependency)
/// that participates in the Event Type Registry (REQ-p01050). It identifies
/// the entry type by `id`, binds it to a `version`-d schema, selects the
/// Flutter widget used to render it, and optionally carries hints for the
/// materializer (`effectiveDatePath`) and destination routing
/// (`destinationTags`).
///
/// JSON serialization uses snake_case keys:
/// `id`, `version`, `name`, `widget_id`, `widget_config`,
/// `effective_date_path`, `destination_tags`.
///
// Implements: REQ-d00116-A+B+C+D+E+F+G — value type carrying the seven
// fields called out in design-doc §6.4. REQ-d00116-E (materializer
// fallback) is enforced by the materializer in Phase 3, not here; this
// type only carries the path.
class EntryTypeDefinition {
  const EntryTypeDefinition({
    required this.id,
    required this.version,
    required this.name,
    required this.widgetId,
    required this.widgetConfig,
    this.effectiveDatePath,
    this.destinationTags,
  });

  // Implements: REQ-d00116-A+B+C+D+E — decode from snake_case JSON; reject
  // payloads missing any of the five required fields or with wrong types.
  // REQ-d00116-F+G — optional fields default to null when absent.
  factory EntryTypeDefinition.fromJson(Map<String, Object?> json) {
    final id = _requireString(json, 'id');
    final version = _requireString(json, 'version');
    final name = _requireString(json, 'name');
    final widgetId = _requireString(json, 'widget_id');
    final widgetConfigRaw = json['widget_config'];
    if (widgetConfigRaw is! Map) {
      throw const FormatException(
        'EntryTypeDefinition: missing or non-object "widget_config"',
      );
    }
    final widgetConfig = Map<String, Object?>.unmodifiable(
      Map<String, Object?>.from(widgetConfigRaw),
    );

    final effectiveDatePathRaw = json['effective_date_path'];
    if (effectiveDatePathRaw != null && effectiveDatePathRaw is! String) {
      throw const FormatException(
        'EntryTypeDefinition: "effective_date_path" must be a String when '
        'present',
      );
    }

    final destinationTagsRaw = json['destination_tags'];
    List<String>? destinationTags;
    if (destinationTagsRaw != null) {
      if (destinationTagsRaw is! List) {
        throw const FormatException(
          'EntryTypeDefinition: "destination_tags" must be a List when present',
        );
      }
      destinationTags = List<String>.unmodifiable(
        destinationTagsRaw.map((e) {
          if (e is! String) {
            throw const FormatException(
              'EntryTypeDefinition: "destination_tags" entries must be Strings',
            );
          }
          return e;
        }),
      );
    }

    return EntryTypeDefinition(
      id: id,
      version: version,
      name: name,
      widgetId: widgetId,
      widgetConfig: widgetConfig,
      effectiveDatePath: effectiveDatePathRaw as String?,
      destinationTags: destinationTags,
    );
  }

  /// Matches `event.entry_type` for every event of this entry type.
  final String id;

  /// Schema version under which events of this type are written.
  final String version;

  /// Display name used by UI and operational tooling.
  final String name;

  /// Key into the Flutter widget registry selecting the renderer.
  final String widgetId;

  /// Widget-specific JSON payload. Shape determined by the widget.
  final Map<String, Object?> widgetConfig;

  /// JSON path into `event.data.answers` that the materializer may use to
  /// extract the entry's effective date. Null means: no fixed path; the
  /// materializer falls back to the client timestamp of the aggregate's
  /// first event (enforced in Phase 3).
  final String? effectiveDatePath;

  /// Tags a destination's `SubscriptionFilter` may match on. Null means
  /// this entry type declares no routing-hint tags.
  final List<String>? destinationTags;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'version': version,
    'name': name,
    'widget_id': widgetId,
    'widget_config': widgetConfig,
    'effective_date_path': effectiveDatePath,
    'destination_tags': destinationTags,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntryTypeDefinition &&
          id == other.id &&
          version == other.version &&
          name == other.name &&
          widgetId == other.widgetId &&
          _deepEq.equals(widgetConfig, other.widgetConfig) &&
          effectiveDatePath == other.effectiveDatePath &&
          _deepEq.equals(destinationTags, other.destinationTags);

  @override
  int get hashCode => Object.hash(
    id,
    version,
    name,
    widgetId,
    _deepEq.hash(widgetConfig),
    effectiveDatePath,
    _deepEq.hash(destinationTags),
  );

  @override
  String toString() =>
      'EntryTypeDefinition('
      'id: $id, version: $version, name: $name, '
      'widgetId: $widgetId, widgetConfig: $widgetConfig, '
      'effectiveDatePath: $effectiveDatePath, '
      'destinationTags: $destinationTags)';
}

const DeepCollectionEquality _deepEq = DeepCollectionEquality();

String _requireString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('EntryTypeDefinition: missing or non-string "$key"');
  }
  return value;
}
