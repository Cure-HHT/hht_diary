/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00078: HHT Diary Auth Service - Request validation
 *
 * Zod schemas for API request validation.
 * Must match Dart request models exactly.
 */

import { z } from 'zod';

// Validation constants matching Dart ValidationRules
export const VALIDATION_RULES = {
  USERNAME_MIN_LENGTH: 6,
  USERNAME_MAX_LENGTH: 50,
  PASSWORD_MIN_LENGTH: 8,
  PASSWORD_MAX_LENGTH: 128,
  LINKING_CODE_MIN_LENGTH: 3,
} as const;

/**
 * Login request schema.
 * Matches Dart LoginRequest model.
 */
export const loginSchema = z.object({
  username: z
    .string()
    .min(VALIDATION_RULES.USERNAME_MIN_LENGTH)
    .max(VALIDATION_RULES.USERNAME_MAX_LENGTH)
    .refine((s) => !s.includes('@'), {
      message: 'Username cannot contain @',
    }),
  password: z
    .string()
    .min(VALIDATION_RULES.PASSWORD_MIN_LENGTH)
    .max(VALIDATION_RULES.PASSWORD_MAX_LENGTH),
  appUuid: z.string().uuid(),
});

export type LoginRequest = z.infer<typeof loginSchema>;

/**
 * Registration request schema.
 * Matches Dart RegistrationRequest model.
 */
export const registrationSchema = z.object({
  username: z
    .string()
    .min(VALIDATION_RULES.USERNAME_MIN_LENGTH)
    .max(VALIDATION_RULES.USERNAME_MAX_LENGTH)
    .refine((s) => !s.includes('@'), {
      message: 'Username cannot contain @',
    }),
  passwordHash: z.string().min(1),
  salt: z.string().min(1),
  linkingCode: z.string().min(VALIDATION_RULES.LINKING_CODE_MIN_LENGTH),
  appUuid: z.string().uuid(),
});

export type RegistrationRequest = z.infer<typeof registrationSchema>;

/**
 * Linking code validation request schema.
 */
export const linkingCodeSchema = z.object({
  linkingCode: z.string().min(VALIDATION_RULES.LINKING_CODE_MIN_LENGTH),
});

export type LinkingCodeRequest = z.infer<typeof linkingCodeSchema>;

/**
 * Token refresh request schema.
 */
export const refreshTokenSchema = z.object({
  token: z.string().min(1),
});

export type RefreshTokenRequest = z.infer<typeof refreshTokenSchema>;

/**
 * Change password request schema.
 */
export const changePasswordSchema = z.object({
  username: z
    .string()
    .min(VALIDATION_RULES.USERNAME_MIN_LENGTH)
    .max(VALIDATION_RULES.USERNAME_MAX_LENGTH),
  currentPassword: z
    .string()
    .min(VALIDATION_RULES.PASSWORD_MIN_LENGTH)
    .max(VALIDATION_RULES.PASSWORD_MAX_LENGTH),
  newPasswordHash: z.string().min(1),
  newSalt: z.string().min(1),
});

export type ChangePasswordRequest = z.infer<typeof changePasswordSchema>;
