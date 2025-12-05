/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00079: Linking Code Pattern Matching
 *
 * Pattern-to-sponsor mapping for linking code identification.
 * Must match Dart SponsorPattern model exactly.
 */
export interface SponsorPattern {
    /** Pattern prefix (e.g., "HHT-CUR-" or "1234") */
    patternPrefix: string;
    /** Unique sponsor identifier */
    sponsorId: string;
    /** Human-readable sponsor name */
    sponsorName: string;
    /** Sponsor Portal base URL */
    portalUrl: string;
    /** Sponsor's GCP Firestore project ID */
    firestoreProject: string;
    /** Whether sponsor is active (accepts new linking codes) */
    active: boolean;
    /** Pattern creation timestamp (ISO 8601) */
    createdAt: string;
    /** Decommission timestamp (ISO 8601 or null if active) */
    decommissionedAt: string | null;
}
/**
 * Finds matching sponsor pattern for a linking code.
 * Patterns are matched using prefix comparison.
 */
export declare function findMatchingPattern(linkingCode: string, patterns: SponsorPattern[]): SponsorPattern | null;
//# sourceMappingURL=sponsor-pattern.model.d.ts.map