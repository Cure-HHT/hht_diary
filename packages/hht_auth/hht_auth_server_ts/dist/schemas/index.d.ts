/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00078: HHT Diary Auth Service - Request validation
 *
 * Zod schemas for API request validation.
 * Must match Dart request models exactly.
 */
import { z } from 'zod';
export declare const VALIDATION_RULES: {
    readonly USERNAME_MIN_LENGTH: 6;
    readonly USERNAME_MAX_LENGTH: 50;
    readonly PASSWORD_MIN_LENGTH: 8;
    readonly PASSWORD_MAX_LENGTH: 128;
    readonly LINKING_CODE_MIN_LENGTH: 3;
};
/**
 * Login request schema.
 * Matches Dart LoginRequest model.
 */
export declare const loginSchema: z.ZodObject<{
    username: z.ZodEffects<z.ZodString, string, string>;
    password: z.ZodString;
    appUuid: z.ZodString;
}, "strip", z.ZodTypeAny, {
    username: string;
    appUuid: string;
    password: string;
}, {
    username: string;
    appUuid: string;
    password: string;
}>;
export type LoginRequest = z.infer<typeof loginSchema>;
/**
 * Registration request schema.
 * Matches Dart RegistrationRequest model.
 */
export declare const registrationSchema: z.ZodObject<{
    username: z.ZodEffects<z.ZodString, string, string>;
    passwordHash: z.ZodString;
    salt: z.ZodString;
    linkingCode: z.ZodString;
    appUuid: z.ZodString;
}, "strip", z.ZodTypeAny, {
    username: string;
    appUuid: string;
    passwordHash: string;
    linkingCode: string;
    salt: string;
}, {
    username: string;
    appUuid: string;
    passwordHash: string;
    linkingCode: string;
    salt: string;
}>;
export type RegistrationRequest = z.infer<typeof registrationSchema>;
/**
 * Linking code validation request schema.
 */
export declare const linkingCodeSchema: z.ZodObject<{
    linkingCode: z.ZodString;
}, "strip", z.ZodTypeAny, {
    linkingCode: string;
}, {
    linkingCode: string;
}>;
export type LinkingCodeRequest = z.infer<typeof linkingCodeSchema>;
/**
 * Token refresh request schema.
 */
export declare const refreshTokenSchema: z.ZodObject<{
    token: z.ZodString;
}, "strip", z.ZodTypeAny, {
    token: string;
}, {
    token: string;
}>;
export type RefreshTokenRequest = z.infer<typeof refreshTokenSchema>;
/**
 * Change password request schema.
 */
export declare const changePasswordSchema: z.ZodObject<{
    username: z.ZodString;
    currentPassword: z.ZodString;
    newPasswordHash: z.ZodString;
    newSalt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    username: string;
    currentPassword: string;
    newPasswordHash: string;
    newSalt: string;
}, {
    username: string;
    currentPassword: string;
    newPasswordHash: string;
    newSalt: string;
}>;
export type ChangePasswordRequest = z.infer<typeof changePasswordSchema>;
//# sourceMappingURL=index.d.ts.map