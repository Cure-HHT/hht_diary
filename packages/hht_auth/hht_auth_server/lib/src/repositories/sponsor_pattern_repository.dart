/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00079: Linking Code Pattern Matching - Repository interface
///
/// Abstract repository interface for sponsor pattern data access.

import 'package:hht_auth_core/hht_auth_core.dart';

/// Repository interface for SponsorPattern persistence operations.
abstract class SponsorPatternRepository {
  /// Retrieves all active sponsor patterns.
  ///
  /// Results are cached for 5 minutes to improve performance.
  /// Patterns are sorted by prefix length descending (most specific first).
  Future<List<SponsorPattern>> getAllActivePatterns();

  /// Finds a sponsor pattern by linking code prefix match.
  ///
  /// Returns null if no matching pattern found or pattern is inactive.
  Future<SponsorPattern?> findByLinkingCode(String linkingCode);

  /// Creates a new sponsor pattern.
  Future<void> createPattern(SponsorPattern pattern);

  /// Decommissions a sponsor pattern (sets active=false).
  Future<void> decommissionPattern(String sponsorId);

  /// Refreshes the pattern cache.
  Future<void> refreshCache();
}
