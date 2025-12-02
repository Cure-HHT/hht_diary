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

// TODO JWT secret - in production this should be from Secret Manager
const JWT_SECRET = process.env.JWT_SECRET ||
  "mvp-development-secret-change-in-production";

// TODO: Valid enrollment code pattern: CUREHHT followed by a digit (0-9)
// Consider changing to 'C' or 'H' starter in future
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
 * Registers a user with an 8-character enrollment code
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

// Username validation constants
const MIN_USERNAME_LENGTH = 6;
const MIN_PASSWORD_LENGTH = 8;
const USERNAME_PATTERN = /^[a-zA-Z0-9_]+$/;

/**
 * Validate username format.
 * @param {string} username - The username to validate
 * @return {string | null} Error message if invalid, null if valid
 */
function validateUsername(username: string): string | null {
  if (!username || username.length < MIN_USERNAME_LENGTH) {
    return `Username must be at least ${MIN_USERNAME_LENGTH} characters`;
  }
  if (username.includes("@")) {
    return "Username cannot contain @ symbol";
  }
  if (!USERNAME_PATTERN.test(username)) {
    return "Username can only contain letters, numbers, and underscores";
  }
  return null;
}

/**
 * Validate password hash format (should be SHA-256 hex string).
 * @param {string} passwordHash - The password hash to validate
 * @return {string | null} Error message if invalid, null if valid
 */
function validatePasswordHash(passwordHash: string): string | null {
  if (!passwordHash || passwordHash.length !== 64) {
    return `Password must be at least ${MIN_PASSWORD_LENGTH} characters`;
  }
  // Check if it's a valid hex string
  if (!/^[a-f0-9]{64}$/i.test(passwordHash)) {
    return "Invalid password format";
  }
  return null;
}

/**
 * Register HTTP function (v1)
 * Creates a new user account with username/password
 *
 * Body: { username: "...", passwordHash: "...", appUuid: "..." }
 * Returns: { jwt: "...", userId: "..." } or error
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-p00008: User Account Management
 */
export const register = functions
  .runWith(runtimeOpts)
  .region("europe-west1")
  .https.onRequest((req, res) => {
    corsHandlerFnc()(req, res, async () => {
      console.info("[REGISTER] Request received", {
        method: req.method,
        contentType: req.headers["content-type"],
        bodyKeys: req.body ? Object.keys(req.body) : "no body",
      });

      if (req.method !== "POST") {
        console.warn("[REGISTER] Method not allowed", {method: req.method});
        res.status(405).json({error: "Method not allowed"});
        return;
      }

      const {username, passwordHash, appUuid} = req.body;

      console.info("[REGISTER] Parsed body", {
        username: username || "MISSING",
        passwordHashLength: passwordHash ? passwordHash.length : "MISSING",
        appUuid: appUuid || "MISSING",
      });

      // Validate username
      const usernameError = validateUsername(username);
      if (usernameError) {
        console.warn("[REGISTER] Username validation failed", {
          username,
          error: usernameError,
        });
        res.status(400).json({error: usernameError});
        return;
      }

      // Validate password hash
      const passwordError = validatePasswordHash(passwordHash);
      if (passwordError) {
        console.warn("[REGISTER] Password hash validation failed", {
          passwordHashLength: passwordHash ? passwordHash.length : 0,
          error: passwordError,
        });
        res.status(400).json({error: passwordError});
        return;
      }

      if (!appUuid || typeof appUuid !== "string") {
        console.warn("[REGISTER] App UUID missing or invalid", {appUuid});
        res.status(400).json({error: "App UUID is required"});
        return;
      }

      const normalizedUsername = username.toLowerCase();
      console.info("[REGISTER] Checking if username exists", {
        normalizedUsername,
      });

      // Check if username is already taken
      const existingUser = await db.collection("users")
        .doc(normalizedUsername)
        .get();

      if (existingUser.exists) {
        console.warn("[REGISTER] Username already taken", {normalizedUsername});
        res.status(409).json({error: "Username is already taken"});
        return;
      }

      // Generate user credentials
      const userId = generateUserId();
      const authCode = generateAuthCode();
      const now = admin.firestore.Timestamp.now();

      console.info("[REGISTER] Creating user document", {
        userId,
        normalizedUsername,
        authCodeLength: authCode.length,
      });

      // Create user document
      const userRef = db.collection("users").doc(normalizedUsername);
      await userRef.set({
        userId,
        authCode,
        username: normalizedUsername,
        passwordHash,
        appUuid,
        createdAt: now,
        updatedAt: now,
        lastActiveAt: now,
      });

      console.info("[REGISTER] User document created, generating JWT");

      // Generate JWT
      const jwtToken = jwt.sign(
        {
          authCode,
          userId,
          username: normalizedUsername,
          iat: Math.floor(Date.now() / 1000),
        },
        JWT_SECRET,
        {
          expiresIn: "365d",
          issuer: "hht-diary-mvp",
        }
      );

      console.info("[REGISTER] SUCCESS - User registered", {
        userId,
        username: normalizedUsername,
        jwtLength: jwtToken.length,
      });

      res.json({
        jwt: jwtToken,
        userId,
        username: normalizedUsername,
      });
    });
  });

/**
 * Login HTTP function (v1)
 * Authenticates user with username/password
 *
 * Body: { username: "...", passwordHash: "..." }
 * Returns: { jwt: "...", userId: "..." } or error
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-p00008: User Account Management
 */
export const login = functions
  .runWith(runtimeOpts)
  .region("europe-west1")
  .https.onRequest((req, res) => {
    corsHandlerFnc()(req, res, async () => {
      console.info("[LOGIN] Request received", {
        method: req.method,
        contentType: req.headers["content-type"],
        bodyKeys: req.body ? Object.keys(req.body) : "no body",
      });

      if (req.method !== "POST") {
        console.warn("[LOGIN] Method not allowed", {method: req.method});
        res.status(405).json({error: "Method not allowed"});
        return;
      }

      const {username, passwordHash} = req.body;

      const hashPreview = passwordHash ?
        passwordHash.substring(0, 8) + "..." : "MISSING";
      console.info("[LOGIN] Parsed body", {
        username: username || "MISSING",
        passwordHashLength: passwordHash ? passwordHash.length : "MISSING",
        passwordHashPreview: hashPreview,
      });

      if (!username || typeof username !== "string") {
        console.warn("[LOGIN] Username missing or invalid", {username});
        res.status(400).json({error: "Username is required"});
        return;
      }

      if (!passwordHash || typeof passwordHash !== "string") {
        console.warn("[LOGIN] Password hash missing or invalid", {
          passwordHash: passwordHash ? "present but wrong type" : "MISSING",
        });
        res.status(400).json({error: "Password is required"});
        return;
      }

      const normalizedUsername = username.toLowerCase();
      console.info("[LOGIN] Looking up user", {normalizedUsername});

      // Fetch user document
      const userDoc = await db.collection("users")
        .doc(normalizedUsername)
        .get();

      if (!userDoc.exists) {
        console.warn("[LOGIN] User not found", {normalizedUsername});
        res.status(401).json({error: "Invalid username or password"});
        return;
      }

      const userData = userDoc.data();
      if (!userData) {
        res.status(401).json({error: "Invalid username or password"});
        return;
      }
      const storedHash = userData.passwordHash as string;
      const storedPreview = storedHash ?
        storedHash.substring(0, 8) + "..." : "MISSING";

      console.info("[LOGIN] User found, comparing password hashes", {
        normalizedUsername,
        storedHashLength: storedHash ? storedHash.length : "MISSING",
        storedHashPreview: storedPreview,
        providedHashLength: passwordHash.length,
        providedHashPreview: passwordHash.substring(0, 8) + "...",
        hashesMatch: storedHash === passwordHash,
      });

      // Verify password
      if (storedHash !== passwordHash) {
        console.warn("[LOGIN] Password mismatch", {
          normalizedUsername,
          storedHashLength: storedHash ? storedHash.length : 0,
          providedHashLength: passwordHash.length,
        });
        res.status(401).json({error: "Invalid username or password"});
        return;
      }

      console.info("[LOGIN] Password verified, updating last active timestamp");

      // Update last active timestamp
      await userDoc.ref.update({
        lastActiveAt: admin.firestore.Timestamp.now(),
      });

      console.info("[LOGIN] Generating JWT");

      // Generate new JWT
      const jwtToken = jwt.sign(
        {
          authCode: userData.authCode,
          userId: userData.userId,
          username: normalizedUsername,
          iat: Math.floor(Date.now() / 1000),
        },
        JWT_SECRET,
        {
          expiresIn: "365d",
          issuer: "hht-diary-mvp",
        }
      );

      console.info("[LOGIN] SUCCESS - User logged in", {
        userId: userData.userId,
        username: normalizedUsername,
        jwtLength: jwtToken.length,
      });

      res.json({
        jwt: jwtToken,
        userId: userData.userId,
        username: normalizedUsername,
      });
    });
  });

/**
 * Change password HTTP function (v1)
 * Authorization: Bearer <jwt>
 *
 * Body: { currentPasswordHash: "...", newPasswordHash: "..." }
 * Returns: { success: true } or error
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-p00008: User Account Management
 */
export const changePassword = functions
  .runWith(runtimeOpts)
  .region("europe-west1")
  .https.onRequest((req, res) => {
    corsHandlerFnc()(req, res, async () => {
      console.info("[CHANGE_PASSWORD] Request received", {
        method: req.method,
        contentType: req.headers["content-type"],
        hasAuthHeader: !!req.headers.authorization,
        bodyKeys: req.body ? Object.keys(req.body) : "no body",
      });

      if (req.method !== "POST") {
        console.warn("[CHANGE_PASSWORD] Method not allowed", {
          method: req.method,
        });
        res.status(405).json({error: "Method not allowed"});
        return;
      }

      // Verify JWT from Authorization header
      const auth = verifyAuthHeader(req.headers.authorization);
      if (!auth) {
        console.warn("[CHANGE_PASSWORD] Auth header invalid or missing", {
          authHeaderPresent: !!req.headers.authorization,
          authHeaderPreview: req.headers.authorization ?
            req.headers.authorization.substring(0, 20) + "..." : "MISSING",
        });
        res.status(401).json({error: "Invalid or missing authorization"});
        return;
      }

      console.info("[CHANGE_PASSWORD] Auth verified", {
        userId: auth.userId,
        authCodeLength: auth.authCode.length,
      });

      const {currentPasswordHash, newPasswordHash} = req.body;

      const currLen = currentPasswordHash ?
        currentPasswordHash.length : "MISSING";
      const newLen = newPasswordHash ? newPasswordHash.length : "MISSING";
      console.info("[CHANGE_PASSWORD] Parsed body", {
        currentHashLength: currLen,
        newHashLength: newLen,
      });

      // Validate new password hash
      const passwordError = validatePasswordHash(newPasswordHash);
      if (passwordError) {
        console.warn("[CHANGE_PASSWORD] New password hash validation failed", {
          newHashLength: newPasswordHash ? newPasswordHash.length : 0,
          error: passwordError,
        });
        res.status(400).json({error: passwordError});
        return;
      }

      console.info("[CHANGE_PASSWORD] Looking up user by authCode");

      // Look up user by authCode
      const user = await getUserByAuthCode(auth.authCode);
      if (!user) {
        console.warn("[CHANGE_PASSWORD] User not found by authCode", {
          authCodeLength: auth.authCode.length,
        });
        res.status(401).json({error: "User not found"});
        return;
      }

      console.info("[CHANGE_PASSWORD] User found", {userId: user.userId});

      // Get current password hash
      const userDoc = await user.userRef.get();
      const userData = userDoc.data();
      if (!userData) {
        res.status(401).json({error: "User data not found"});
        return;
      }
      const storedHash = userData.passwordHash as string;
      const storedLen = storedHash ? storedHash.length : "MISSING";
      const providedLen = currentPasswordHash ?
        currentPasswordHash.length : "MISSING";

      console.info("[CHANGE_PASSWORD] Comparing current password hashes", {
        storedHashLength: storedLen,
        providedHashLength: providedLen,
        hashesMatch: storedHash === currentPasswordHash,
      });

      // Verify current password
      if (storedHash !== currentPasswordHash) {
        const currProvidedLen = currentPasswordHash ?
          currentPasswordHash.length : 0;
        console.warn("[CHANGE_PASSWORD] Current password mismatch", {
          storedHashLength: storedHash ? storedHash.length : 0,
          providedHashLength: currProvidedLen,
        });
        res.status(401).json({error: "Current password is incorrect"});
        return;
      }

      console.info("[CHANGE_PASSWORD] Current password verified, updating");

      // Update password
      await user.userRef.update({
        passwordHash: newPasswordHash,
        updatedAt: admin.firestore.Timestamp.now(),
      });

      console.info("[CHANGE_PASSWORD] SUCCESS - Password changed", {
        userId: user.userId,
      });

      res.json({success: true});
    });
  });
