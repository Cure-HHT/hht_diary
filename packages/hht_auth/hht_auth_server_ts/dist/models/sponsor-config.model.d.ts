/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00084: Sponsor Configuration Loading
 *
 * Sponsor-specific configuration.
 * Must match Dart SponsorConfig model exactly.
 */
export interface SponsorBranding {
    /** Logo URL */
    logoUrl: string;
    /** Primary color (hex string, e.g., "#FF5733") */
    primaryColor: string;
    /** Secondary color (hex string) */
    secondaryColor: string;
    /** Welcome message displayed after login (optional) */
    welcomeMessage?: string | null;
}
export interface SponsorConfig {
    /** Unique sponsor identifier */
    sponsorId: string;
    /** Human-readable sponsor name */
    sponsorName: string;
    /** Session timeout in minutes (default 2, range 1-30) */
    sessionTimeoutMinutes: number;
    /** Sponsor-specific branding */
    branding: SponsorBranding;
}
/**
 * Creates default branding for fallback.
 */
export declare function createDefaultBranding(): SponsorBranding;
/**
 * Creates default config for fallback when portal fetch fails.
 */
export declare function createDefaultSponsorConfig(sponsorId: string, sponsorName?: string): SponsorConfig;
//# sourceMappingURL=sponsor-config.model.d.ts.map