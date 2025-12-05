/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00XXX: Rate limiting service for brute force attack prevention
 *
 * RateLimiterService provides sliding window rate limiting
 * to prevent brute force attacks on authentication endpoints.
 *
 * Uses in-memory storage with configurable limits and window duration.
 */
export interface RateLimiterConfig {
    maxAttempts?: number;
    windowDuration?: number;
}
export declare class RateLimiterService {
    private static readonly DEFAULT_MAX_ATTEMPTS;
    private static readonly DEFAULT_WINDOW_DURATION;
    private readonly maxAttempts;
    private readonly windowDuration;
    private readonly attempts;
    /**
     * Creates a new RateLimiterService
     * @param config Optional configuration for max attempts and window duration
     */
    constructor(config?: RateLimiterConfig);
    /**
     * Checks if a request is within rate limits
     * @param key Unique identifier (typically "ipAddress:username")
     * @returns true if within limits, false if limit exceeded
     */
    checkLimit(key: string): boolean;
    /**
     * Gets the number of remaining attempts for a key
     * @param key Unique identifier
     * @returns Number of attempts remaining before limit
     */
    getRemainingAttempts(key: string): number;
    /**
     * Gets time in milliseconds until the rate limit resets for a key
     * @param key Unique identifier
     * @returns Milliseconds until oldest attempt expires, or null if no attempts
     */
    getTimeUntilReset(key: string): number | null;
    /**
     * Clears all attempts for a key
     * @param key Unique identifier
     */
    reset(key: string): void;
    /**
     * Removes all expired entries from memory
     * Should be called periodically to prevent memory leaks
     */
    cleanup(): void;
    /**
     * Removes expired attempts for a specific key
     * @param key Unique identifier
     */
    private removeExpiredAttempts;
    /**
     * Checks if a timestamp is still within the sliding window
     * @param timestamp The timestamp to check
     * @param now Current time (defaults to Date.now())
     * @returns true if timestamp is within window duration
     */
    private isTimestampValid;
    /**
     * Gets the current number of valid attempts for a key
     * @param key Unique identifier
     * @returns Number of attempts currently recorded
     */
    private getCurrentAttemptCount;
    /**
     * Gets the oldest attempt timestamp for a key
     * @param key Unique identifier
     * @returns Oldest timestamp, or null if no attempts exist
     */
    private getOldestAttemptTimestamp;
    /**
     * Records a new attempt for a key
     * @param key Unique identifier
     */
    private recordAttempt;
}
//# sourceMappingURL=rate-limiter.service.d.ts.map