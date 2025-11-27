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
import * as jwt from "jsonwebtoken";
import * as crypto from "crypto";
import {corsHandlerFnc} from "./cors";

// Runtime options for v1 functions
const runtimeOpts: functions.RuntimeOptions = {
  timeoutSeconds: 60,
  memory: "256MB",
};

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();

// JWT secret - in production this should be from Secret Manager
const JWT_SECRET = process.env.JWT_SECRET ||
  "mvp-development-secret-change-in-production";

// Valid enrollment code pattern: CUREHHT followed by a digit (0-9)
const ENROLLMENT_CODE_PATTERN = /^CUREHHT[0-9]$/i;

/**
 * Generate a random authCode for user authentication.
 * @return {string} A 64-character hex string
 */
function generateAuthCode(): string {
  return crypto.randomBytes(32).toString("hex");
}

/**
 * Generate a unique userId.
 * @return {string} A UUID string
 */
function generateUserId(): string {
  return crypto.randomUUID();
}

/**
 * Verify JWT from Authorization header and return user data.
 * @param {string | undefined} authHeader - The Authorization header value
 * @return {object | null} Decoded token with authCode or null if invalid
 */
function verifyAuthHeader(
  authHeader: string | undefined
): {authCode: string; userId: string} | null {
  if (!authHeader?.startsWith("Bearer ")) {
    return null;
  }
  const token = authHeader.substring(7);
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as {
      authCode: string;
      userId: string;
    };
    if (!decoded.authCode || !decoded.userId) {
      return null;
    }
    return decoded;
  } catch {
    return null;
  }
}

/**
 * Look up user by authCode and verify it matches.
 * @param {string} authCode - The authCode from JWT
 * @return {Promise<object | null>} User data with userId and userRef
 */
async function getUserByAuthCode(authCode: string): Promise<{
  userId: string;
  userRef: FirebaseFirestore.DocumentReference;
} | null> {
  const usersSnapshot = await db.collection("users")
    .where("authCode", "==", authCode)
    .limit(1)
    .get();

  if (usersSnapshot.empty) {
    return null;
  }

  const userDoc = usersSnapshot.docs[0];
  return {
    userId: userDoc.data().userId,
    userRef: userDoc.ref,
  };
}

/**
 * Enrollment HTTP function (v1)
 * Registers a user with an 8-character enrollment code (CUREHHT#)
 * Returns a JWT token for subsequent API calls
 *
 * Body: { code: "CUREHHT1" }
 * Returns: { jwt: "...", userId: "..." } or error
 */
export const enroll = functions
  .runWith(runtimeOpts)
  .region("europe-west1")
  .https.onRequest((req, res) => {
    corsHandlerFnc()(req, res, async () => {
      if (req.method !== "POST") {
        res.status(405).json({error: "Method not allowed"});
        return;
      }

      const {code} = req.body;

      if (!code || typeof code !== "string") {
        res.status(400).json({error: "Enrollment code is required"});
        return;
      }

      // Validate code format (CUREHHT followed by digit)
      const normalizedCode = code.toUpperCase();
      if (!ENROLLMENT_CODE_PATTERN.test(normalizedCode)) {
        console.info("Invalid code format", {code: normalizedCode});
        res.status(400).json({error: "Invalid enrollment code"});
        return;
      }

      // Check if code has already been used
      const existingUser = await db.collection("users")
        .where("enrollmentCode", "==", normalizedCode)
        .limit(1)
        .get();

      if (!existingUser.empty) {
        console.info("Code already used", {code: normalizedCode});
        res.status(409).json({
          error: "This enrollment code has already been used",
        });
        return;
      }

      // Generate user credentials
      const userId = generateUserId();
      const authCode = generateAuthCode();
      const now = admin.firestore.Timestamp.now();

      // Create user document
      const userRef = db.collection("users").doc(userId);
      await userRef.set({
        userId,
        authCode,
        enrollmentCode: normalizedCode,
        createdAt: now,
        lastActiveAt: now,
      });

      // Generate JWT with authCode (not userId for security)
      const jwtToken = jwt.sign(
        {
          authCode,
          userId,
          iat: Math.floor(Date.now() / 1000),
        },
        JWT_SECRET,
        {
          expiresIn: "365d",
          issuer: "hht-diary-mvp",
        }
      );

      console.info("User enrolled", {userId, code: normalizedCode});

      res.json({
        jwt: jwtToken,
        userId,
      });
    });
  });

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

/**
 * Sync records HTTP function (v1)
 * Authorization: Bearer <jwt>
 * Body: { records: [...] }
 *
 * Appends records to Firestore (append-only pattern)
 */
export const sync = functions
  .runWith(runtimeOpts)
  .region("europe-west1")
  .https.onRequest((req, res) => {
    corsHandlerFnc()(req, res, async () => {
      if (req.method !== "POST") {
        res.status(405).json({error: "Method not allowed"});
        return;
      }

      // Verify JWT from Authorization header
      const auth = verifyAuthHeader(req.headers.authorization);
      if (!auth) {
        res.status(401).json({error: "Invalid or missing authorization"});
        return;
      }

      // Look up user by authCode
      const user = await getUserByAuthCode(auth.authCode);
      if (!user) {
        res.status(401).json({error: "User not found"});
        return;
      }

      const {records} = req.body;

      if (!Array.isArray(records)) {
        res.status(400).json({error: "Records must be an array"});
        return;
      }

      const batch = db.batch();
      const userRecordsRef = user.userRef.collection("records");

      for (const record of records) {
        if (!record.id) {
          continue;
        }

        const recordRef = userRecordsRef.doc(record.id);
        const existingDoc = await recordRef.get();

        if (!existingDoc.exists) {
          batch.set(recordRef, {
            ...record,
            syncedAt: admin.firestore.Timestamp.now(),
          });
        }
      }

      await batch.commit();

      // Update last active timestamp
      await user.userRef.update({
        lastActiveAt: admin.firestore.Timestamp.now(),
      });

      console.info("Records synced", {
        userId: user.userId,
        count: records.length,
      });

      res.json({success: true});
    });
  });

/**
 * Get records HTTP function (v1)
 * Authorization: Bearer <jwt>
 *
 * Returns all records for the user
 */
export const getRecords = functions
  .runWith(runtimeOpts)
  .region("europe-west1")
  .https.onRequest((req, res) => {
    corsHandlerFnc()(req, res, async () => {
      if (req.method !== "POST") {
        res.status(405).json({error: "Method not allowed"});
        return;
      }

      // Verify JWT from Authorization header
      const auth = verifyAuthHeader(req.headers.authorization);
      if (!auth) {
        res.status(401).json({error: "Invalid or missing authorization"});
        return;
      }

      // Look up user by authCode
      const user = await getUserByAuthCode(auth.authCode);
      if (!user) {
        res.status(401).json({error: "User not found"});
        return;
      }

      const recordsSnapshot = await user.userRef
        .collection("records")
        .orderBy("createdAt", "desc")
        .get();

      const records = recordsSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      res.json({records});
    });
  });
