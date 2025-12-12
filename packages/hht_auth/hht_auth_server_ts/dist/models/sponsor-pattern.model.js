/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00079: Linking Code Pattern Matching
 *
 * Pattern-to-sponsor mapping for linking code identification.
 * Must match Dart SponsorPattern model exactly.
 */
/**
 * Finds matching sponsor pattern for a linking code.
 * Patterns are matched using prefix comparison.
 */
export function findMatchingPattern(linkingCode, patterns) {
    // Sort by prefix length descending for most specific match first
    const sortedPatterns = [...patterns].sort((a, b) => b.patternPrefix.length - a.patternPrefix.length);
    for (const pattern of sortedPatterns) {
        if (pattern.active &&
            linkingCode.toUpperCase().startsWith(pattern.patternPrefix.toUpperCase())) {
            return pattern;
        }
    }
    return null;
}
//# sourceMappingURL=sponsor-pattern.model.js.map