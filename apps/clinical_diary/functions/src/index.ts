/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00005: Sponsor Configuration Detection Implementation
 *   REQ-p00013: GDPR compliance - EU-only regions
 *
 * Firebase Cloud Functions v1 for the Clinical Diary MVP.
 * Using v1 functions which are publicly accessible by default.
 * All functions run in europe-west1 for GDPR compliance.
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

// Runtime options for v1 functions
export const runtimeOpts: functions.RuntimeOptions = {
  timeoutSeconds: 60,
  memory: "256MB",
};

// Initialize Firebase Admin
admin.initializeApp();
export const db = admin.firestore();

// Re-export functions from split modules
export {health} from "./health";
export {register, login, changePassword} from "./auth";
export {enroll, sync, getRecords} from "./user";
