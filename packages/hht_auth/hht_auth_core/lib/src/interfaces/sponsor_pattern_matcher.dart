/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00079: Linking Code Pattern Matching interfaces

import 'package:hht_auth_core/src/models/sponsor_pattern.dart';

/// Pattern match result for sponsor identification.
sealed class PatternMatchResult {
  const PatternMatchResult();
}

/// Pattern matched successfully to a sponsor.
class PatternMatched extends PatternMatchResult {
  final SponsorPattern pattern;

  const PatternMatched(this.pattern);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatternMatched &&
          runtimeType == other.runtimeType &&
          pattern == other.pattern;

  @override
  int get hashCode => pattern.hashCode;
}

/// No matching pattern found for linking code.
class PatternNotMatched extends PatternMatchResult {
  const PatternNotMatched();
}

/// Interface for sponsor pattern matching from linking codes.
///
/// Implements prefix-based pattern matching similar to credit card BIN ranges.
abstract class SponsorPatternMatcher {
  /// Finds a sponsor by matching the linking code against known patterns.
  ///
  /// Patterns are matched by prefix, with longest patterns checked first.
  /// Only active (non-decommissioned) sponsors are returned.
  ///
  /// Returns [PatternMatched] if a matching pattern is found,
  /// or [PatternNotMatched] if no pattern matches.
  Future<PatternMatchResult> findSponsorByLinkingCode(String linkingCode);

  /// Refreshes the cached pattern table from the data source.
  ///
  /// Pattern cache typically has a 5-minute TTL.
  Future<void> refreshPatterns();

  /// Returns all active sponsor patterns (for testing/debugging).
  Future<List<SponsorPattern>> getActivePatterns();
}
