import 'package:flutter/foundation.dart';

/// One selectable / displayable site, resolved by the wiring layer from
/// the `sites_index` projection.
///
/// Snapshot value type — `portal_screens` never reads projections; the
/// binding maps `{site_id, site_number, site_name}` rows into these for
/// the user dialogs (assigned-sites list, site checklists).
@immutable
class SiteOptionView {
  const SiteOptionView({
    required this.id,
    required this.number,
    required this.name,
  });

  /// Backend site aggregate id (what role/site assignments bind to).
  final String id;

  /// Sponsor-facing site number (e.g. "001"). Used as the leading label
  /// and as the sort key in checklists.
  final String number;

  /// Human site name (e.g. "Memorial Hospital"). May be empty when the
  /// EDC sync hasn't provided one.
  final String name;

  /// "001 - Memorial Hospital" (Figma), falling back to the raw id when
  /// no number/name came through the sync.
  String get label {
    if (number.isEmpty && name.isEmpty) return id;
    if (name.isEmpty) return number;
    if (number.isEmpty) return name;
    return '$number - $name';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SiteOptionView &&
          id == other.id &&
          number == other.number &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, number, name);

  @override
  String toString() => 'SiteOptionView($id, $number, $name)';
}
