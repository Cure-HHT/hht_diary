/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00079: Linking Code Pattern Matching
 *
 * Sponsor pattern repository interface and in-memory implementation.
 */
import { findMatchingPattern, } from '../models/sponsor-pattern.model.js';
/**
 * In-memory sponsor pattern repository for testing.
 */
export class InMemorySponsorPatternRepository {
    patterns = [];
    async getAllActivePatterns() {
        return this.patterns.filter((p) => p.active);
    }
    async findByLinkingCode(linkingCode) {
        return findMatchingPattern(linkingCode, this.patterns);
    }
    async findBySponsorId(sponsorId) {
        return (this.patterns.find((p) => p.sponsorId === sponsorId && p.active) ?? null);
    }
    /** Clear all patterns (for testing) */
    clear() {
        this.patterns = [];
    }
    /** Seed patterns (for testing) */
    seed(patterns) {
        this.patterns = [...patterns];
    }
}
//# sourceMappingURL=sponsor-pattern.repository.js.map