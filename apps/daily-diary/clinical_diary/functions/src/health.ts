/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00005: Sponsor Configuration Detection Implementation
 *   REQ-p00013: GDPR compliance - EU-only regions
 *
 * Health check endpoint for Firebase Cloud Functions.
 */

import * as functions from "firebase-functions/v1";
import {corsHandlerFnc} from "./cors";
import {runtimeOpts} from "./index";

/**
 * Health check HTTP function (v1)
 */
export const health = functions
  .runWith(runtimeOpts)
  .region("europe-west1")
  .https.onRequest((req, res) => {
    corsHandlerFnc()(req, res, async () => {
      res.json({
        status: "ok",
        timestamp: new Date().toISOString(),
        region: "europe-west1",
      });
    });
  });
