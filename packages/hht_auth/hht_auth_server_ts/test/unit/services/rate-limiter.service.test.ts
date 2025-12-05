/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-d00XXX: Rate limiting service for brute force attack prevention
 *
 * Unit tests for RateLimiterService
 * Following TDD methodology - tests written BEFORE implementation
 */

import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import { RateLimiterService } from '../../../src/services/rate-limiter.service.js';

describe('RateLimiterService', () => {
  let rateLimiter: RateLimiterService;
  const testKey = '192.168.1.1:testuser';

  beforeEach(() => {
    // Reset timers before each test
    vi.useFakeTimers();
    rateLimiter = new RateLimiterService();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe('checkLimit', () => {
    it('should allow requests within limit', () => {
      // Default max attempts is 5
      expect(rateLimiter.checkLimit(testKey)).toBe(true);
      expect(rateLimiter.checkLimit(testKey)).toBe(true);
      expect(rateLimiter.checkLimit(testKey)).toBe(true);
      expect(rateLimiter.checkLimit(testKey)).toBe(true);
      expect(rateLimiter.checkLimit(testKey)).toBe(true);
    });

    it('should block requests exceeding limit', () => {
      // Max out the attempts (5 allowed)
      for (let i = 0; i < 5; i++) {
        expect(rateLimiter.checkLimit(testKey)).toBe(true);
      }

      // 6th attempt should be blocked
      expect(rateLimiter.checkLimit(testKey)).toBe(false);
      // 7th attempt should also be blocked
      expect(rateLimiter.checkLimit(testKey)).toBe(false);
    });

    it('should record each allowed attempt', () => {
      // Initially should have 5 remaining
      expect(rateLimiter.getRemainingAttempts(testKey)).toBe(5);

      rateLimiter.checkLimit(testKey);
      expect(rateLimiter.getRemainingAttempts(testKey)).toBe(4);

      rateLimiter.checkLimit(testKey);
      expect(rateLimiter.getRemainingAttempts(testKey)).toBe(3);
    });

    it('should not record blocked attempts', () => {
      // Use up all attempts
      for (let i = 0; i < 5; i++) {
        rateLimiter.checkLimit(testKey);
      }

      expect(rateLimiter.getRemainingAttempts(testKey)).toBe(0);

      // Blocked attempt should not affect remaining count
      rateLimiter.checkLimit(testKey);
      expect(rateLimiter.getRemainingAttempts(testKey)).toBe(0);
    });

    it('should respect custom maxAttempts configuration', () => {
      const customLimiter = new RateLimiterService({ maxAttempts: 3 });

      expect(customLimiter.checkLimit(testKey)).toBe(true);
      expect(customLimiter.checkLimit(testKey)).toBe(true);
      expect(customLimiter.checkLimit(testKey)).toBe(true);
      expect(customLimiter.checkLimit(testKey)).toBe(false);
    });

    it('should track different keys independently', () => {
      const key1 = '192.168.1.1:user1';
      const key2 = '192.168.1.2:user2';

      // Use up key1
      for (let i = 0; i < 5; i++) {
        rateLimiter.checkLimit(key1);
      }

      // key1 should be blocked
      expect(rateLimiter.checkLimit(key1)).toBe(false);

      // key2 should still be allowed
      expect(rateLimiter.checkLimit(key2)).toBe(true);
    });
  });

  describe('getRemainingAttempts', () => {
    it('should return maxAttempts for unknown key', () => {
      expect(rateLimiter.getRemainingAttempts('unknown-key')).toBe(5);
    });

    it('should decrease as attempts are made', () => {
      expect(rateLimiter.getRemainingAttempts(testKey)).toBe(5);

      rateLimiter.checkLimit(testKey);
      expect(rateLimiter.getRemainingAttempts(testKey)).toBe(4);

      rateLimiter.checkLimit(testKey);
      expect(rateLimiter.getRemainingAttempts(testKey)).toBe(3);

      rateLimiter.checkLimit(testKey);
      expect(rateLimiter.getRemainingAttempts(testKey)).toBe(2);
    });

    it('should return 0 when limit is exceeded', () => {
      // Use up all attempts
      for (let i = 0; i < 5; i++) {
        rateLimiter.checkLimit(testKey);
      }

      expect(rateLimiter.getRemainingAttempts(testKey)).toBe(0);
    });

    it('should respect custom maxAttempts', () => {
      const customLimiter = new RateLimiterService({ maxAttempts: 10 });
      expect(customLimiter.getRemainingAttempts(testKey)).toBe(10);

      customLimiter.checkLimit(testKey);
      expect(customLimiter.getRemainingAttempts(testKey)).toBe(9);
    });
  });

  describe('getTimeUntilReset', () => {
    it('should return null for unknown key', () => {
      expect(rateLimiter.getTimeUntilReset('unknown-key')).toBeNull();
    });

    it('should return time until oldest attempt expires', () => {
      const startTime = Date.now();
      vi.setSystemTime(startTime);

      // Make first attempt at time 0
      rateLimiter.checkLimit(testKey);

      // Advance time by 30 seconds
      vi.advanceTimersByTime(30000);

      // Make second attempt at time 30000
      rateLimiter.checkLimit(testKey);

      // Time until reset should be ~30 seconds (60000 - 30000)
      const timeUntilReset = rateLimiter.getTimeUntilReset(testKey);
      expect(timeUntilReset).toBe(30000);
    });

    it('should update as time passes', () => {
      const startTime = Date.now();
      vi.setSystemTime(startTime);

      rateLimiter.checkLimit(testKey);

      // Initially should be 60 seconds (window duration)
      expect(rateLimiter.getTimeUntilReset(testKey)).toBe(60000);

      // After 10 seconds, should be 50 seconds
      vi.advanceTimersByTime(10000);
      expect(rateLimiter.getTimeUntilReset(testKey)).toBe(50000);

      // After another 20 seconds (30 total), should be 30 seconds
      vi.advanceTimersByTime(20000);
      expect(rateLimiter.getTimeUntilReset(testKey)).toBe(30000);
    });

    it('should handle multiple attempts correctly', () => {
      const startTime = Date.now();
      vi.setSystemTime(startTime);

      // First attempt at t=0
      rateLimiter.checkLimit(testKey);

      vi.advanceTimersByTime(10000); // t=10000
      rateLimiter.checkLimit(testKey);

      vi.advanceTimersByTime(10000); // t=20000
      rateLimiter.checkLimit(testKey);

      // Time until reset should be based on oldest attempt (t=0)
      // Current time is 20000, oldest expires at 60000
      expect(rateLimiter.getTimeUntilReset(testKey)).toBe(40000);
    });
  });

  describe('reset', () => {
    it('should clear all attempts for a key', () => {
      // Make some attempts
      rateLimiter.checkLimit(testKey);
      rateLimiter.checkLimit(testKey);
      rateLimiter.checkLimit(testKey);

      expect(rateLimiter.getRemainingAttempts(testKey)).toBe(2);

      // Reset the key
      rateLimiter.reset(testKey);

      // Should be back to max attempts
      expect(rateLimiter.getRemainingAttempts(testKey)).toBe(5);
      expect(rateLimiter.getTimeUntilReset(testKey)).toBeNull();
    });

    it('should not affect other keys', () => {
      const key1 = '192.168.1.1:user1';
      const key2 = '192.168.1.2:user2';

      rateLimiter.checkLimit(key1);
      rateLimiter.checkLimit(key1);
      rateLimiter.checkLimit(key2);

      // Reset key1
      rateLimiter.reset(key1);

      // key1 should be reset
      expect(rateLimiter.getRemainingAttempts(key1)).toBe(5);

      // key2 should be unchanged
      expect(rateLimiter.getRemainingAttempts(key2)).toBe(4);
    });

    it('should allow requests after reset', () => {
      // Max out attempts
      for (let i = 0; i < 5; i++) {
        rateLimiter.checkLimit(testKey);
      }

      expect(rateLimiter.checkLimit(testKey)).toBe(false);

      // Reset
      rateLimiter.reset(testKey);

      // Should allow requests again
      expect(rateLimiter.checkLimit(testKey)).toBe(true);
    });
  });

  describe('cleanup', () => {
    it('should remove expired entries', () => {
      const startTime = Date.now();
      vi.setSystemTime(startTime);

      const key1 = '192.168.1.1:user1';
      const key2 = '192.168.1.2:user2';

      // Make attempts at t=0
      rateLimiter.checkLimit(key1);
      rateLimiter.checkLimit(key2);

      // Advance time past window duration (60 seconds + 1ms)
      vi.advanceTimersByTime(60001);

      // Cleanup should remove expired entries
      rateLimiter.cleanup();

      // Both keys should be back to max attempts
      expect(rateLimiter.getRemainingAttempts(key1)).toBe(5);
      expect(rateLimiter.getRemainingAttempts(key2)).toBe(5);
      expect(rateLimiter.getTimeUntilReset(key1)).toBeNull();
      expect(rateLimiter.getTimeUntilReset(key2)).toBeNull();
    });

    it('should keep non-expired entries', () => {
      const startTime = Date.now();
      vi.setSystemTime(startTime);

      const key1 = '192.168.1.1:user1';
      const key2 = '192.168.1.2:user2';

      // Make attempt for key1 at t=0
      rateLimiter.checkLimit(key1);

      // Advance time by 30 seconds
      vi.advanceTimersByTime(30000);

      // Make attempt for key2 at t=30000
      rateLimiter.checkLimit(key2);

      // Advance time by another 31 seconds (total 61 seconds)
      // key1's attempt is now expired (61s > 60s window)
      // key2's attempt is still valid (31s < 60s window)
      vi.advanceTimersByTime(31000);

      rateLimiter.cleanup();

      // key1 should be cleaned up
      expect(rateLimiter.getRemainingAttempts(key1)).toBe(5);
      expect(rateLimiter.getTimeUntilReset(key1)).toBeNull();

      // key2 should still have the recorded attempt
      expect(rateLimiter.getRemainingAttempts(key2)).toBe(4);
      expect(rateLimiter.getTimeUntilReset(key2)).toBeGreaterThan(0);
    });

    it('should partially clean expired attempts from a key', () => {
      const startTime = Date.now();
      vi.setSystemTime(startTime);

      // Make 3 attempts with time gaps
      rateLimiter.checkLimit(testKey); // t=0

      vi.advanceTimersByTime(10000);
      rateLimiter.checkLimit(testKey); // t=10000

      vi.advanceTimersByTime(55000);
      rateLimiter.checkLimit(testKey); // t=65000

      // At t=65000, first attempt (t=0) is now expired
      // but second (t=10000) and third (t=65000) are not

      rateLimiter.cleanup();

      // Should have 3 remaining (5 max - 2 valid attempts)
      expect(rateLimiter.getRemainingAttempts(testKey)).toBe(3);
    });
  });

  describe('sliding window behavior', () => {
    it('should allow new attempts after old ones expire', () => {
      const startTime = Date.now();
      vi.setSystemTime(startTime);

      // Use up all 5 attempts at t=0
      for (let i = 0; i < 5; i++) {
        rateLimiter.checkLimit(testKey);
      }

      // Should be blocked
      expect(rateLimiter.checkLimit(testKey)).toBe(false);

      // Advance time by window duration + 1ms
      vi.advanceTimersByTime(60001);

      // Run cleanup to remove expired attempts
      rateLimiter.cleanup();

      // Should allow requests again
      expect(rateLimiter.checkLimit(testKey)).toBe(true);
      expect(rateLimiter.getRemainingAttempts(testKey)).toBe(4);
    });

    it('should enforce limit within sliding window', () => {
      const startTime = Date.now();
      vi.setSystemTime(startTime);

      // Make 4 attempts at t=0
      for (let i = 0; i < 4; i++) {
        rateLimiter.checkLimit(testKey);
      }

      // Advance 30 seconds
      vi.advanceTimersByTime(30000);

      // Make 5th attempt at t=30000 - should succeed
      expect(rateLimiter.checkLimit(testKey)).toBe(true);

      // 6th attempt should fail (5 attempts in last 60 seconds)
      expect(rateLimiter.checkLimit(testKey)).toBe(false);

      // Advance another 31 seconds (total 61 seconds from start)
      vi.advanceTimersByTime(31000);
      rateLimiter.cleanup();

      // First 4 attempts are now expired
      // Only the 5th attempt (at t=30000) is still in window
      expect(rateLimiter.getRemainingAttempts(testKey)).toBe(4);
      expect(rateLimiter.checkLimit(testKey)).toBe(true);
    });
  });

  describe('custom configuration', () => {
    it('should respect custom window duration', () => {
      const customLimiter = new RateLimiterService({
        maxAttempts: 3,
        windowDuration: 30000 // 30 seconds
      });

      const startTime = Date.now();
      vi.setSystemTime(startTime);

      customLimiter.checkLimit(testKey);

      // Should expire after 30 seconds, not 60
      expect(customLimiter.getTimeUntilReset(testKey)).toBe(30000);

      vi.advanceTimersByTime(31000);
      customLimiter.cleanup();

      expect(customLimiter.getRemainingAttempts(testKey)).toBe(3);
    });
  });

  describe('edge cases', () => {
    it('should handle empty string keys', () => {
      expect(rateLimiter.checkLimit('')).toBe(true);
      expect(rateLimiter.getRemainingAttempts('')).toBe(4);
    });

    it('should handle rapid successive calls', () => {
      // All calls happen at same timestamp
      const results = [];
      for (let i = 0; i < 7; i++) {
        results.push(rateLimiter.checkLimit(testKey));
      }

      // First 5 should succeed, last 2 should fail
      expect(results).toEqual([true, true, true, true, true, false, false]);
    });

    it('should handle cleanup with no entries', () => {
      expect(() => rateLimiter.cleanup()).not.toThrow();
    });

    it('should handle reset of non-existent key', () => {
      expect(() => rateLimiter.reset('non-existent')).not.toThrow();
      expect(rateLimiter.getRemainingAttempts('non-existent')).toBe(5);
    });
  });
});
