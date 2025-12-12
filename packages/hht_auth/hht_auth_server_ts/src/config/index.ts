/**
 * Server configuration module.
 */

export const TOKEN_CONFIG = {
  /** Token expiry for web clients in minutes */
  WEB_TOKEN_EXPIRY_MINUTES: 15,
  /** Default session timeout in minutes */
  DEFAULT_SESSION_TIMEOUT_MINUTES: 2,
} as const;

export const RATE_LIMIT_CONFIG = {
  /** Maximum login attempts before rate limiting */
  MAX_ATTEMPTS: 5,
  /** Rate limit window in milliseconds (1 minute) */
  WINDOW_MS: 60_000,
} as const;

export const ACCOUNT_LOCKOUT_CONFIG = {
  /** Failed attempts before account lockout */
  MAX_FAILED_ATTEMPTS: 5,
  /** Account lockout duration in minutes */
  LOCKOUT_MINUTES: 15,
} as const;

export interface ServerConfig {
  host: string;
  port: number;
  jwtPrivateKey: string;
  jwtPublicKey: string;
  jwtIssuer: string;
}

/**
 * Load configuration from environment variables.
 */
export function loadConfig(): ServerConfig {
  const jwtPrivateKey = process.env['JWT_PRIVATE_KEY'];
  const jwtPublicKey = process.env['JWT_PUBLIC_KEY'];

  if (!jwtPrivateKey || !jwtPublicKey) {
    throw new Error('JWT_PRIVATE_KEY and JWT_PUBLIC_KEY must be set');
  }

  return {
    host: process.env['HOST'] ?? '0.0.0.0',
    port: parseInt(process.env['PORT'] ?? '8080', 10),
    jwtPrivateKey,
    jwtPublicKey,
    jwtIssuer: process.env['JWT_ISSUER'] ?? 'hht-auth-service',
  };
}
