/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00079: Linking Code Pattern Matching - Fake repository for testing
///
/// In-memory fake implementation of SponsorPatternRepository for testing.

import 'package:hht_auth_core/hht_auth_core.dart';
import 'package:hht_auth_server/src/repositories/sponsor_pattern_repository.dart';

/// Fake in-memory SponsorPatternRepository for testing.
class FakeSponsorPatternRepository implements SponsorPatternRepository {
  final List<SponsorPattern> _patterns = [];

  @override
  Future<List<SponsorPattern>> getAllActivePatterns() async {
    final activePatterns = _patterns
        .where((p) => p.active)
        .toList()
      ..sort((a, b) => b.patternPrefix.length.compareTo(a.patternPrefix.length));

    return activePatterns;
  }

  @override
  Future<SponsorPattern?> findByLinkingCode(String linkingCode) async {
    final patterns = await getAllActivePatterns();

    for (final pattern in patterns) {
      if (linkingCode.startsWith(pattern.patternPrefix)) {
        return pattern;
      }
    }

    return null;
  }

  @override
  Future<void> createPattern(SponsorPattern pattern) async {
    _patterns.add(pattern);
  }

  @override
  Future<void> decommissionPattern(String sponsorId) async {
    for (var i = 0; i < _patterns.length; i++) {
      if (_patterns[i].sponsorId == sponsorId) {
        _patterns[i] = _patterns[i].copyWith(
          active: false,
          decommissionedAt: DateTime.now(),
        );
      }
    }
  }

  @override
  Future<void> refreshCache() async {
    // No-op for fake implementation (no actual cache)
  }

  /// Clears all stored patterns (for test cleanup).
  void clear() {
    _patterns.clear();
  }
}
