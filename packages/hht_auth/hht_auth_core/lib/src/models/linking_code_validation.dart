/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00079: Linking Code Pattern Matching interfaces

/// Sealed class representing the result of linking code validation.
sealed class LinkingCodeValidation {
  const LinkingCodeValidation();
}

/// Linking code is valid and matched to a sponsor.
class LinkingCodeValid extends LinkingCodeValidation {
  final String sponsorId;
  final String sponsorName;
  final String portalUrl;

  const LinkingCodeValid({
    required this.sponsorId,
    required this.sponsorName,
    required this.portalUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkingCodeValid &&
          runtimeType == other.runtimeType &&
          sponsorId == other.sponsorId &&
          sponsorName == other.sponsorName &&
          portalUrl == other.portalUrl;

  @override
  int get hashCode =>
      sponsorId.hashCode ^ sponsorName.hashCode ^ portalUrl.hashCode;
}

/// Linking code is invalid or not recognized.
class LinkingCodeInvalid extends LinkingCodeValidation {
  final String reason;

  const LinkingCodeInvalid(this.reason);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkingCodeInvalid &&
          runtimeType == other.runtimeType &&
          reason == other.reason;

  @override
  int get hashCode => reason.hashCode;
}
