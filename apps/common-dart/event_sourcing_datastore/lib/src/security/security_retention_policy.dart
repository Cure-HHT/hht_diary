/// Retention-and-truncation policy applied by
/// `EventStore.applyRetentionPolicy` against the security-context sidecar
/// store. Separate from the event log's retention, which is permanent.
// Implements: REQ-d00138-A — policy value type with documented defaults
// and static `defaults` instance.
class SecurityRetentionPolicy {
  const SecurityRetentionPolicy({
    this.fullRetention = const Duration(days: 90),
    this.truncatedRetention = const Duration(days: 365),
    this.truncateIpv4LastOctet = true,
    this.truncateIpv6Suffix = true,
    this.dropUserAgentAfterFull = true,
    this.dropGeoAfterFull = false,
    this.dropAllAfterTruncated = true,
  });

  factory SecurityRetentionPolicy.fromJson(Map<String, Object?> json) =>
      SecurityRetentionPolicy(
        fullRetention: Duration(seconds: json['full_retention_seconds'] as int),
        truncatedRetention: Duration(
          seconds: json['truncated_retention_seconds'] as int,
        ),
        truncateIpv4LastOctet: json['truncate_ipv4_last_octet'] as bool,
        truncateIpv6Suffix: json['truncate_ipv6_suffix'] as bool,
        dropUserAgentAfterFull: json['drop_user_agent_after_full'] as bool,
        dropGeoAfterFull: json['drop_geo_after_full'] as bool,
        dropAllAfterTruncated: json['drop_all_after_truncated'] as bool,
      );

  final Duration fullRetention;
  final Duration truncatedRetention;
  final bool truncateIpv4LastOctet;
  final bool truncateIpv6Suffix;
  final bool dropUserAgentAfterFull;
  final bool dropGeoAfterFull;
  final bool dropAllAfterTruncated;

  /// The default retention policy as called out in the design doc:
  /// 90-day full retention, 365-day truncated retention, IPv4/IPv6
  /// truncation on, UA drop on, geo drop off, full drop after truncated.
  static const SecurityRetentionPolicy defaults = SecurityRetentionPolicy();

  Map<String, Object?> toJson() => <String, Object?>{
    'full_retention_seconds': fullRetention.inSeconds,
    'truncated_retention_seconds': truncatedRetention.inSeconds,
    'truncate_ipv4_last_octet': truncateIpv4LastOctet,
    'truncate_ipv6_suffix': truncateIpv6Suffix,
    'drop_user_agent_after_full': dropUserAgentAfterFull,
    'drop_geo_after_full': dropGeoAfterFull,
    'drop_all_after_truncated': dropAllAfterTruncated,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SecurityRetentionPolicy &&
          fullRetention == other.fullRetention &&
          truncatedRetention == other.truncatedRetention &&
          truncateIpv4LastOctet == other.truncateIpv4LastOctet &&
          truncateIpv6Suffix == other.truncateIpv6Suffix &&
          dropUserAgentAfterFull == other.dropUserAgentAfterFull &&
          dropGeoAfterFull == other.dropGeoAfterFull &&
          dropAllAfterTruncated == other.dropAllAfterTruncated);

  @override
  int get hashCode => Object.hash(
    fullRetention,
    truncatedRetention,
    truncateIpv4LastOctet,
    truncateIpv6Suffix,
    dropUserAgentAfterFull,
    dropGeoAfterFull,
    dropAllAfterTruncated,
  );
}
