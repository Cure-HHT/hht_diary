// IMPLEMENTS REQUIREMENTS:
//   REQ-p00009: Sponsor-Specific Web Portals
//   REQ-d00028: Portal Frontend Framework

/// Callisto Sponsor Configuration
///
/// This file defines the configuration for the Callisto sponsor.
/// It extends the base SponsorConfig interface (to be implemented in core platform).
class CallistoConfig {
  static const String sponsorId = 'callisto';
  static const String displayName = 'Callisto Clinical Trials';
  static const String primaryColor = '#0175C2';
  static const String secondaryColor = '#4CAF50';

  // Portal configuration
  static const String portalUrl = 'https://callisto-portal.example.com';
  static const String supportEmail = 'support@callisto-trials.example.com';

  // Branding
  static const String logoPath = 'assets/logo.png';
  static const String iconPath = 'assets/icon.png';

  // Features
  static const bool enableOfflineMode = true;
  static const bool enableQuestionnaires = true;
  static const bool enableEdcSync = false; // Endpoint mode (no EDC sync)
}
