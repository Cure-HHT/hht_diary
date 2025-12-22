/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00084: Sponsor Configuration Loading
 *
 * Sponsor-specific configuration.
 * Must match Dart SponsorConfig model exactly.
 */
/**
 * Creates default branding for fallback.
 */
export function createDefaultBranding() {
    return {
        logoUrl: '',
        primaryColor: '#1976D2',
        secondaryColor: '#424242',
        welcomeMessage: null,
    };
}
/**
 * Creates default config for fallback when portal fetch fails.
 */
export function createDefaultSponsorConfig(sponsorId, sponsorName) {
    return {
        sponsorId,
        sponsorName: sponsorName ?? 'Clinical Diary',
        sessionTimeoutMinutes: 2,
        branding: createDefaultBranding(),
    };
}
//# sourceMappingURL=sponsor-config.model.js.map