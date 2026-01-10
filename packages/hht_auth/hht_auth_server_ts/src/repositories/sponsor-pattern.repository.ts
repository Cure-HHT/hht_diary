/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00079: Linking Code Pattern Matching
 *
 * Sponsor pattern repository interface and in-memory implementation.
 */

import {
  SponsorPattern,
  findMatchingPattern,
} from '../models/sponsor-pattern.model.js';

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
export class InMemorySponsorPatternRepository
  implements SponsorPatternRepository
{
  private patterns: SponsorPattern[] = [];

  async getAllActivePatterns(): Promise<SponsorPattern[]> {
    return this.patterns.filter((p) => p.active);
  }

  async findByLinkingCode(linkingCode: string): Promise<SponsorPattern | null> {
    return findMatchingPattern(linkingCode, this.patterns);
  }

  async findBySponsorId(sponsorId: string): Promise<SponsorPattern | null> {
    return (
      this.patterns.find(
        (p) => p.sponsorId === sponsorId && p.active
      ) ?? null
    );
  }

  /** Clear all patterns (for testing) */
  clear(): void {
    this.patterns = [];
  }

  /** Seed patterns (for testing) */
  seed(patterns: SponsorPattern[]): void {
    this.patterns = [...patterns];
  }
}
