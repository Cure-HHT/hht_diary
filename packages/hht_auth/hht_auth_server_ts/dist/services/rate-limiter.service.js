/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00XXX: Rate limiting service for brute force attack prevention
 *
 * RateLimiterService provides sliding window rate limiting
 * to prevent brute force attacks on authentication endpoints.
 *
 * Uses in-memory storage with configurable limits and window duration.
 */
export class RateLimiterService {
    static DEFAULT_MAX_ATTEMPTS = 5;
    static DEFAULT_WINDOW_DURATION = 60000; // 1 minute in milliseconds
    maxAttempts;
    windowDuration;
    attempts;
    /**
     * Creates a new RateLimiterService
     * @param config Optional configuration for max attempts and window duration
     */
    constructor(config) {
        this.maxAttempts = config?.maxAttempts ?? RateLimiterService.DEFAULT_MAX_ATTEMPTS;
        this.windowDuration = config?.windowDuration ?? RateLimiterService.DEFAULT_WINDOW_DURATION;
        this.attempts = new Map();
    }
    /**
     * Checks if a request is within rate limits
     * @param key Unique identifier (typically "ipAddress:username")
     * @returns true if within limits, false if limit exceeded
     */
    checkLimit(key) {
        this.removeExpiredAttempts(key);
        const currentAttemptCount = this.getCurrentAttemptCount(key);
        // Check if limit would be exceeded
        if (currentAttemptCount >= this.maxAttempts) {
            return false;
        }
        // Record the attempt
        this.recordAttempt(key);
        return true;
    }
    /**
     * Gets the number of remaining attempts for a key
     * @param key Unique identifier
     * @returns Number of attempts remaining before limit
     */
    getRemainingAttempts(key) {
        this.removeExpiredAttempts(key);
        const currentAttemptCount = this.getCurrentAttemptCount(key);
        return Math.max(0, this.maxAttempts - currentAttemptCount);
    }
    /**
     * Gets time in milliseconds until the rate limit resets for a key
     * @param key Unique identifier
     * @returns Milliseconds until oldest attempt expires, or null if no attempts
     */
    getTimeUntilReset(key) {
        this.removeExpiredAttempts(key);
        const oldestTimestamp = this.getOldestAttemptTimestamp(key);
        if (oldestTimestamp === null) {
            return null;
        }
        const expirationTime = oldestTimestamp + this.windowDuration;
        const timeUntilReset = expirationTime - Date.now();
        return Math.max(0, timeUntilReset);
    }
    /**
     * Clears all attempts for a key
     * @param key Unique identifier
     */
    reset(key) {
        this.attempts.delete(key);
    }
    /**
     * Removes all expired entries from memory
     * Should be called periodically to prevent memory leaks
     */
    cleanup() {
        const keysToCleanup = Array.from(this.attempts.keys());
        for (const key of keysToCleanup) {
            this.removeExpiredAttempts(key);
        }
    }
    /**
     * Removes expired attempts for a specific key
     * @param key Unique identifier
     */
    removeExpiredAttempts(key) {
        const record = this.attempts.get(key);
        if (!record) {
            return;
        }
        const now = Date.now();
        record.timestamps = record.timestamps.filter(timestamp => this.isTimestampValid(timestamp, now));
        // Clean up empty records
        if (record.timestamps.length === 0) {
            this.attempts.delete(key);
        }
    }
    /**
     * Checks if a timestamp is still within the sliding window
     * @param timestamp The timestamp to check
     * @param now Current time (defaults to Date.now())
     * @returns true if timestamp is within window duration
     */
    isTimestampValid(timestamp, now = Date.now()) {
        return now - timestamp < this.windowDuration;
    }
    /**
     * Gets the current number of valid attempts for a key
     * @param key Unique identifier
     * @returns Number of attempts currently recorded
     */
    getCurrentAttemptCount(key) {
        const record = this.attempts.get(key);
        return record?.timestamps.length ?? 0;
    }
    /**
     * Gets the oldest attempt timestamp for a key
     * @param key Unique identifier
     * @returns Oldest timestamp, or null if no attempts exist
     */
    getOldestAttemptTimestamp(key) {
        const record = this.attempts.get(key);
        if (!record || record.timestamps.length === 0) {
            return null;
        }
        const oldestTimestamp = record.timestamps[0];
        return oldestTimestamp ?? null;
    }
    /**
     * Records a new attempt for a key
     * @param key Unique identifier
     */
    recordAttempt(key) {
        const now = Date.now();
        const record = this.attempts.get(key);
        if (record) {
            record.timestamps.push(now);
        }
        else {
            this.attempts.set(key, { timestamps: [now] });
        }
    }
}
//# sourceMappingURL=rate-limiter.service.js.map