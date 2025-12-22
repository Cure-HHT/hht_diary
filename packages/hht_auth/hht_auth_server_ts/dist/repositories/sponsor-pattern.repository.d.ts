/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00079: Linking Code Pattern Matching
 *
 * Sponsor pattern repository interface and in-memory implementation.
 */
import { SponsorPattern } from '../models/sponsor-pattern.model.js';
/**
 * Repository interface for sponsor pattern operations.
 */
export interface SponsorPatternRepository {
    getAllActivePatterns(): Promise<SponsorPattern[]>;
    findByLinkingCode(linkingCode: string): Promise<SponsorPattern | null>;
    findBySponsorId(sponsorId: string): Promise<SponsorPattern | null>;
}
/**
 * In-memory sponsor pattern repository for testing.
 */
export declare class InMemorySponsorPatternRepository implements SponsorPatternRepository {
    private patterns;
    getAllActivePatterns(): Promise<SponsorPattern[]>;
    findByLinkingCode(linkingCode: string): Promise<SponsorPattern | null>;
    findBySponsorId(sponsorId: string): Promise<SponsorPattern | null>;
    /** Clear all patterns (for testing) */
    clear(): void;
    /** Seed patterns (for testing) */
    seed(patterns: SponsorPattern[]): void;
}
//# sourceMappingURL=sponsor-pattern.repository.d.ts.map