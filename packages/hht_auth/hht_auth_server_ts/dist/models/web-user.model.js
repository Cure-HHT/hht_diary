/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00081: User Document Schema
 *
 * Firestore user document model for web authentication.
 * Must match Dart WebUser model exactly for JSON compatibility.
 */
/**
 * Creates a new WebUser with required fields.
 */
export function createWebUser(params) {
    return {
        ...params,
        createdAt: new Date().toISOString(),
        lastLoginAt: null,
        failedAttempts: 0,
        lockedUntil: null,
    };
}
/**
 * Checks if user account is currently locked.
 */
export function isUserLocked(user) {
    if (!user.lockedUntil)
        return false;
    return new Date() < new Date(user.lockedUntil);
}
/**
 * Converts WebUser to safe JSON for API response.
 * Note: For API responses, we include passwordHash for compatibility
 * with Dart client, but in production you may want to exclude it.
 */
export function webUserToJson(user) {
    return {
        id: user.id,
        username: user.username,
        passwordHash: user.passwordHash,
        sponsorId: user.sponsorId,
        linkingCode: user.linkingCode,
        appUuid: user.appUuid,
        createdAt: user.createdAt,
        lastLoginAt: user.lastLoginAt,
        failedAttempts: user.failedAttempts,
        lockedUntil: user.lockedUntil,
    };
}
//# sourceMappingURL=web-user.model.js.map