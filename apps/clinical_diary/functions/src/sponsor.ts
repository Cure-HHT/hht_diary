/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00005: Sponsor Configuration Detection Implementation
 *   REQ-p00013: GDPR compliance - EU-only regions
 *
 * Firebase Cloud Functions v1 for sponsor configuration.
 * Returns sponsor-specific feature flags that control app behavior.
 * These settings are controlled by the sponsor (study administrator),
 * not by individual subjects in the study.
 */

import * as functions from "firebase-functions/v1";
import {corsHandlerFnc} from "./cors";
import {runtimeOpts} from "./index";

/**
 * Get the expected API key from environment variable.
 * Set via Doppler or Firebase Functions config.
 * @return {string | undefined} The expected API key, or undefined if not
 *   configured
 */
function getExpectedApiKey(): string | undefined {
  return process.env.CUREHHT_QA_API_KEY;
}

/**
 * Feature flags structure returned to the app.
 * All boolean flags control specific app behaviors.
 */
export interface SponsorFeatureFlags {
  // UI Features
  useReviewScreen: boolean;
  useAnimations: boolean;

  // Validation Features
  requireOldEntryJustification: boolean;
  enableShortDurationConfirmation: boolean;
  enableLongDurationConfirmation: boolean;
  longDurationThresholdMinutes: number;
}

/**
 * Default feature flags used when sponsor hasn't configured specific values.
 * These match the FeatureFlags.default* values in the Flutter app.
 */
const DEFAULT_FLAGS: SponsorFeatureFlags = {
  useReviewScreen: false,
  useAnimations: true,
  requireOldEntryJustification: false,
  enableShortDurationConfirmation: false,
  enableLongDurationConfirmation: false,
  longDurationThresholdMinutes: 60,
};

/**
 * Sponsor-specific feature flag configurations.
 * In production, these would be stored in Firestore and fetched dynamically.
 * For now, they are hardcoded for the two known sponsors.
 */
const SPONSOR_CONFIGS: Record<string, SponsorFeatureFlags> = {
  // CureHHT: Default configuration - minimal validation
  curehht: {
    ...DEFAULT_FLAGS,
    // CureHHT uses all defaults
  },

  // Callisto: All validations enabled
  callisto: {
    useReviewScreen: false,
    useAnimations: true,
    requireOldEntryJustification: true,
    enableShortDurationConfirmation: true,
    enableLongDurationConfirmation: true,
    longDurationThresholdMinutes: 60,
  },
};

/**
 * Get sponsor configuration HTTP function (v1)
 *
 * GET /sponsorConfig?sponsorId=curehht
 * Returns: { sponsorId: "...", flags: {...} } or error
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00005: Sponsor Configuration Detection Implementation
 */
export const sponsorConfig = functions
  .runWith(runtimeOpts)
  .region("europe-west1")
  .https.onRequest((req, res) => {
    corsHandlerFnc()(req, res, async () => {
      console.info("[SPONSOR_CONFIG] Request received", {
        method: req.method,
        query: req.query,
      });

      if (req.method !== "GET") {
        console.warn("[SPONSOR_CONFIG] Method not allowed", {
          method: req.method,
        });
        res.status(405).json({error: "Method not allowed"});
        return;
      }

      const sponsorId = (req.query.sponsorId as string)?.toLowerCase()?.trim();

      if (!sponsorId) {
        console.warn("[SPONSOR_CONFIG] Missing sponsorId parameter");
        res.status(400).json({error: "sponsorId parameter is required"});
        return;
      }

      const apiKey = (req.query.apiKey as string)?.trim();

      if (!apiKey) {
        console.warn("[SPONSOR_CONFIG] Missing apiKey parameter");
        res.status(401).json({error: "apiKey parameter is required"});
        return;
      }

      // Validate API key against stored secret
      const expectedApiKey = getExpectedApiKey();
      if (!expectedApiKey) {
        console.error(
          "[SPONSOR_CONFIG] CUREHHT_QA_API_KEY not configured - " +
          "rejecting request"
        );
        res.status(500).json({error: "Server configuration error"});
        return;
      }

      if (apiKey !== expectedApiKey) {
        console.warn("[SPONSOR_CONFIG] Invalid apiKey");
        res.status(401).json({error: "Invalid API key"});
        return;
      }

      console.info("[SPONSOR_CONFIG] Looking up sponsor", {sponsorId});

      // Look up sponsor configuration
      // In production, this would query Firestore
      const config = SPONSOR_CONFIGS[sponsorId];

      if (!config) {
        console.warn("[SPONSOR_CONFIG] Unknown sponsor", {sponsorId});
        // Return default flags for unknown sponsors
        // This allows the app to work even if sponsor ID is wrong
        res.json({
          sponsorId,
          flags: DEFAULT_FLAGS,
          isDefault: true,
        });
        return;
      }

      console.info("[SPONSOR_CONFIG] SUCCESS - Returning config", {
        sponsorId,
        flags: config,
      });

      res.json({
        sponsorId,
        flags: config,
        isDefault: false,
      });
    });
  });
