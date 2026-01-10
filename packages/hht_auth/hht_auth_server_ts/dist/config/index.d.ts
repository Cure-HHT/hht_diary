/**
 * Server configuration module.
 */
export declare const TOKEN_CONFIG: {
    /** Token expiry for web clients in minutes */
    readonly WEB_TOKEN_EXPIRY_MINUTES: 15;
    /** Default session timeout in minutes */
    readonly DEFAULT_SESSION_TIMEOUT_MINUTES: 2;
};
export declare const RATE_LIMIT_CONFIG: {
    /** Maximum login attempts before rate limiting */
    readonly MAX_ATTEMPTS: 5;
    /** Rate limit window in milliseconds (1 minute) */
    readonly WINDOW_MS: 60000;
};
export declare const ACCOUNT_LOCKOUT_CONFIG: {
    /** Failed attempts before account lockout */
    readonly MAX_FAILED_ATTEMPTS: 5;
    /** Account lockout duration in minutes */
    readonly LOCKOUT_MINUTES: 15;
};
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
export declare function loadConfig(): ServerConfig;
//# sourceMappingURL=index.d.ts.map