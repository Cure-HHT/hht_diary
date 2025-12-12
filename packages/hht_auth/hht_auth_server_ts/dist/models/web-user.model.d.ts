/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00081: User Document Schema
 *
 * Firestore user document model for web authentication.
 * Must match Dart WebUser model exactly for JSON compatibility.
 */
export interface WebUser {
    /** UUID v4 document ID */
    id: string;
    /** User-chosen username (6+ chars, no @) */
    username: string;
    /** Argon2id password hash (base64-encoded) */
    passwordHash: string;
    /** Salt used for password hashing (base64-encoded) */
    salt: string;
    /** Sponsor identifier from linking code */
    sponsorId: string;
    /** Original linking code used during registration */
    linkingCode: string;
    /** App instance UUID at registration */
    appUuid: string;
    /** Account creation timestamp (ISO 8601) */
    createdAt: string;
    /** Last successful login timestamp (ISO 8601 or null) */
    lastLoginAt: string | null;
    /** Failed login attempt counter */
    failedAttempts: number;
    /** Account lockout expiry timestamp (ISO 8601 or null) */
    lockedUntil: string | null;
}
/**
 * Creates a new WebUser with required fields.
 */
export declare function createWebUser(params: {
    id: string;
    username: string;
    passwordHash: string;
    salt: string;
    sponsorId: string;
    linkingCode: string;
    appUuid: string;
}): WebUser;
/**
 * Checks if user account is currently locked.
 */
export declare function isUserLocked(user: WebUser): boolean;
/**
 * Converts WebUser to safe JSON for API response.
 * Note: For API responses, we include passwordHash for compatibility
 * with Dart client, but in production you may want to exclude it.
 */
export declare function webUserToJson(user: WebUser): Record<string, unknown>;
//# sourceMappingURL=web-user.model.d.ts.map