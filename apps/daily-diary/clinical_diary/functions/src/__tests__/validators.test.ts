// IMPLEMENTS REQUIREMENTS:
//   REQ-d00005: Sponsor Configuration Detection Implementation

import * as jwt from "jsonwebtoken";
import {
  validateEnrollmentCode,
  normalizeEnrollmentCode,
  generateAuthCode,
  generateUserId,
  verifyAuthHeader,
  verifyJwtToken,
  createJwtToken,
  ENROLLMENT_CODE_PATTERN,
} from "../validators";

describe("Enrollment Code Validation", () => {
  describe("validateEnrollmentCode", () => {
    // Happy path tests
    it("accepts valid CUREHHT codes with digits 0-9", () => {
      for (let i = 0; i <= 9; i++) {
        expect(validateEnrollmentCode(`CUREHHT${i}`)).toBe(true);
      }
    });

    it("accepts lowercase codes", () => {
      expect(validateEnrollmentCode("curehht1")).toBe(true);
      expect(validateEnrollmentCode("CureHht5")).toBe(true);
    });

    it("accepts mixed case codes", () => {
      expect(validateEnrollmentCode("CuReHhT3")).toBe(true);
    });

    // Boundary condition tests
    it("rejects codes with letters instead of digits", () => {
      expect(validateEnrollmentCode("CUREHHTX")).toBe(false);
      expect(validateEnrollmentCode("CUREHHTA")).toBe(false);
    });

    it("rejects codes that are too short", () => {
      expect(validateEnrollmentCode("CUREHHT")).toBe(false);
      expect(validateEnrollmentCode("CURE")).toBe(false);
      expect(validateEnrollmentCode("")).toBe(false);
    });

    it("rejects codes that are too long", () => {
      expect(validateEnrollmentCode("CUREHHT12")).toBe(false);
      expect(validateEnrollmentCode("CUREHHT123")).toBe(false);
    });

    it("rejects codes with wrong prefix", () => {
      expect(validateEnrollmentCode("WRONGHT1")).toBe(false);
      expect(validateEnrollmentCode("CUREXXX1")).toBe(false);
      expect(validateEnrollmentCode("XXXXXXX1")).toBe(false);
    });

    it("rejects null and undefined", () => {
      expect(validateEnrollmentCode(null)).toBe(false);
      expect(validateEnrollmentCode(undefined)).toBe(false);
    });

    it("rejects non-string values", () => {
      expect(validateEnrollmentCode(123 as unknown as string)).toBe(false);
      expect(validateEnrollmentCode({} as unknown as string)).toBe(false);
    });

    it("rejects codes with special characters", () => {
      expect(validateEnrollmentCode("CUREHHT!")).toBe(false);
      expect(validateEnrollmentCode("CUREHHT@")).toBe(false);
      expect(validateEnrollmentCode("CUREHHT#")).toBe(false);
    });

    it("rejects codes with whitespace", () => {
      expect(validateEnrollmentCode(" CUREHHT1")).toBe(false);
      expect(validateEnrollmentCode("CUREHHT1 ")).toBe(false);
      expect(validateEnrollmentCode("CURE HHT1")).toBe(false);
    });
  });

  describe("normalizeEnrollmentCode", () => {
    it("converts lowercase to uppercase", () => {
      expect(normalizeEnrollmentCode("curehht1")).toBe("CUREHHT1");
    });

    it("trims whitespace", () => {
      expect(normalizeEnrollmentCode("  CUREHHT1  ")).toBe("CUREHHT1");
    });

    it("handles mixed case", () => {
      expect(normalizeEnrollmentCode("CuReHhT5")).toBe("CUREHHT5");
    });
  });

  describe("ENROLLMENT_CODE_PATTERN", () => {
    it("is a valid regex", () => {
      expect(ENROLLMENT_CODE_PATTERN instanceof RegExp).toBe(true);
    });

    it("is case insensitive", () => {
      expect(ENROLLMENT_CODE_PATTERN.flags).toContain("i");
    });
  });
});

describe("Auth Code Generation", () => {
  describe("generateAuthCode", () => {
    it("generates a 64-character hex string", () => {
      const authCode = generateAuthCode();
      expect(authCode).toHaveLength(64);
      expect(/^[0-9a-f]+$/.test(authCode)).toBe(true);
    });

    it("generates unique codes", () => {
      const codes = new Set<string>();
      for (let i = 0; i < 100; i++) {
        codes.add(generateAuthCode());
      }
      expect(codes.size).toBe(100);
    });
  });

  describe("generateUserId", () => {
    // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    const UUID_V4_REGEX = new RegExp(
      "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-" +
      "[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
      "i"
    );

    it("generates a valid UUID", () => {
      const userId = generateUserId();
      expect(UUID_V4_REGEX.test(userId)).toBe(true);
    });

    it("generates unique IDs", () => {
      const ids = new Set<string>();
      for (let i = 0; i < 100; i++) {
        ids.add(generateUserId());
      }
      expect(ids.size).toBe(100);
    });
  });
});

describe("JWT Handling", () => {
  const TEST_SECRET = "test-secret-key-for-testing";
  const TEST_AUTH_CODE = "test-auth-code-12345";
  const TEST_USER_ID = "test-user-id-12345";

  describe("createJwtToken", () => {
    it("creates a valid JWT token", () => {
      const token = createJwtToken(
        {authCode: TEST_AUTH_CODE, userId: TEST_USER_ID},
        TEST_SECRET
      );

      expect(typeof token).toBe("string");
      expect(token.split(".")).toHaveLength(3); // JWT has 3 parts
    });

    it("creates token with correct payload", () => {
      const token = createJwtToken(
        {authCode: TEST_AUTH_CODE, userId: TEST_USER_ID},
        TEST_SECRET
      );

      const decoded = verifyJwtToken(token, TEST_SECRET);
      expect(decoded?.authCode).toBe(TEST_AUTH_CODE);
      expect(decoded?.userId).toBe(TEST_USER_ID);
    });

    it("includes issuer in token", () => {
      const token = createJwtToken(
        {authCode: TEST_AUTH_CODE, userId: TEST_USER_ID},
        TEST_SECRET
      );

      const decoded = verifyJwtToken(token, TEST_SECRET);
      expect(decoded?.iss).toBe("hht-diary-mvp");
    });

    it("includes issued at timestamp", () => {
      const before = Math.floor(Date.now() / 1000);
      const token = createJwtToken(
        {authCode: TEST_AUTH_CODE, userId: TEST_USER_ID},
        TEST_SECRET
      );
      const after = Math.floor(Date.now() / 1000);

      const decoded = verifyJwtToken(token, TEST_SECRET);
      expect(decoded?.iat).toBeGreaterThanOrEqual(before);
      expect(decoded?.iat).toBeLessThanOrEqual(after);
    });
  });

  describe("verifyJwtToken", () => {
    it("returns payload for valid token", () => {
      const token = createJwtToken(
        {authCode: TEST_AUTH_CODE, userId: TEST_USER_ID},
        TEST_SECRET
      );

      const result = verifyJwtToken(token, TEST_SECRET);
      expect(result).not.toBeNull();
      expect(result?.authCode).toBe(TEST_AUTH_CODE);
      expect(result?.userId).toBe(TEST_USER_ID);
    });

    it("returns null for invalid token", () => {
      expect(verifyJwtToken("invalid-token", TEST_SECRET)).toBeNull();
    });

    it("returns null for wrong secret", () => {
      const token = createJwtToken(
        {authCode: TEST_AUTH_CODE, userId: TEST_USER_ID},
        TEST_SECRET
      );

      expect(verifyJwtToken(token, "wrong-secret")).toBeNull();
    });

    it("returns null for expired token", () => {
      const token = createJwtToken(
        {authCode: TEST_AUTH_CODE, userId: TEST_USER_ID},
        TEST_SECRET,
        "-1s" // Already expired
      );

      expect(verifyJwtToken(token, TEST_SECRET)).toBeNull();
    });

    it("returns null for tampered token", () => {
      const token = createJwtToken(
        {authCode: TEST_AUTH_CODE, userId: TEST_USER_ID},
        TEST_SECRET
      );

      // Tamper with the token
      const parts = token.split(".");
      parts[1] = "tampered" + parts[1];
      const tamperedToken = parts.join(".");

      expect(verifyJwtToken(tamperedToken, TEST_SECRET)).toBeNull();
    });

    it("returns null for token missing authCode", () => {
      const token = jwt.sign({userId: TEST_USER_ID}, TEST_SECRET);
      expect(verifyJwtToken(token, TEST_SECRET)).toBeNull();
    });

    it("returns null for token missing userId", () => {
      const token = jwt.sign({authCode: TEST_AUTH_CODE}, TEST_SECRET);
      expect(verifyJwtToken(token, TEST_SECRET)).toBeNull();
    });
  });

  describe("verifyAuthHeader", () => {
    it("extracts and verifies token from Bearer header", () => {
      const token = createJwtToken(
        {authCode: TEST_AUTH_CODE, userId: TEST_USER_ID},
        TEST_SECRET
      );

      const result = verifyAuthHeader(`Bearer ${token}`, TEST_SECRET);
      expect(result).not.toBeNull();
      expect(result?.authCode).toBe(TEST_AUTH_CODE);
    });

    it("returns null for missing header", () => {
      expect(verifyAuthHeader(undefined, TEST_SECRET)).toBeNull();
    });

    it("returns null for empty header", () => {
      expect(verifyAuthHeader("", TEST_SECRET)).toBeNull();
    });

    it("returns null for non-Bearer header", () => {
      const token = createJwtToken(
        {authCode: TEST_AUTH_CODE, userId: TEST_USER_ID},
        TEST_SECRET
      );

      expect(verifyAuthHeader(`Basic ${token}`, TEST_SECRET)).toBeNull();
      expect(verifyAuthHeader(token, TEST_SECRET)).toBeNull();
    });

    it("returns null for Bearer header with invalid token", () => {
      const invalidResult = verifyAuthHeader(
        "Bearer invalid-token",
        TEST_SECRET
      );
      expect(invalidResult).toBeNull();
    });

    it("returns null for Bearer header with only spaces", () => {
      expect(verifyAuthHeader("Bearer ", TEST_SECRET)).toBeNull();
    });
  });
});
