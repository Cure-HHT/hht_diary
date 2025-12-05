/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00079: Linking Code Pattern Matching interfaces

import 'package:json_annotation/json_annotation.dart';

part 'sponsor_pattern.g.dart';

/// Pattern-to-sponsor mapping for linking code identification.
///
/// Stored in Firestore `sponsor_patterns` collection.
/// Patterns are matched using prefix comparison (similar to credit card BIN ranges).
@JsonSerializable()
class SponsorPattern {
  /// Pattern prefix (e.g., "HHT-CUR-" or "1234")
  final String patternPrefix;

  /// Unique sponsor identifier
  final String sponsorId;

  /// Human-readable sponsor name
  final String sponsorName;

  /// Sponsor Portal base URL
  final String portalUrl;

  /// Sponsor's GCP Firestore project ID
  final String firestoreProject;

  /// Whether sponsor is active (accepts new linking codes)
  final bool active;

  /// Pattern creation timestamp
  final DateTime createdAt;

  /// Decommission timestamp (null if active)
  final DateTime? decommissionedAt;

  const SponsorPattern({
    required this.patternPrefix,
    required this.sponsorId,
    required this.sponsorName,
    required this.portalUrl,
    required this.firestoreProject,
    required this.active,
    required this.createdAt,
    this.decommissionedAt,
  });

  /// Creates an instance from JSON data.
  factory SponsorPattern.fromJson(Map<String, dynamic> json) =>
      _$SponsorPatternFromJson(json);

  /// Converts this instance to JSON.
  Map<String, dynamic> toJson() => _$SponsorPatternToJson(this);

  /// Creates a copy of this pattern with the specified fields replaced.
  SponsorPattern copyWith({
    String? patternPrefix,
    String? sponsorId,
    String? sponsorName,
    String? portalUrl,
    String? firestoreProject,
    bool? active,
    DateTime? createdAt,
    DateTime? decommissionedAt,
  }) {
    return SponsorPattern(
      patternPrefix: patternPrefix ?? this.patternPrefix,
      sponsorId: sponsorId ?? this.sponsorId,
      sponsorName: sponsorName ?? this.sponsorName,
      portalUrl: portalUrl ?? this.portalUrl,
      firestoreProject: firestoreProject ?? this.firestoreProject,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      decommissionedAt: decommissionedAt ?? this.decommissionedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SponsorPattern &&
          runtimeType == other.runtimeType &&
          patternPrefix == other.patternPrefix &&
          sponsorId == other.sponsorId &&
          sponsorName == other.sponsorName &&
          portalUrl == other.portalUrl &&
          firestoreProject == other.firestoreProject &&
          active == other.active &&
          createdAt == other.createdAt &&
          decommissionedAt == other.decommissionedAt;

  @override
  int get hashCode =>
      patternPrefix.hashCode ^
      sponsorId.hashCode ^
      sponsorName.hashCode ^
      portalUrl.hashCode ^
      firestoreProject.hashCode ^
      active.hashCode ^
      createdAt.hashCode ^
      decommissionedAt.hashCode;

  @override
  String toString() {
    return 'SponsorPattern(patternPrefix: $patternPrefix, sponsorId: $sponsorId, '
        'sponsorName: $sponsorName, active: $active, createdAt: $createdAt)';
  }
}
