/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service - Rate limiting for brute force prevention
///
/// Tests for rate limiter service (5 attempts per minute per key).

import 'package:hht_auth_server/src/services/rate_limiter.dart';
import 'package:test/test.dart';

void main() {
  group('RateLimiter', () {
    late RateLimiter rateLimiter;

    setUp(() {
      rateLimiter = RateLimiter(
        maxAttempts: 5,
        windowDuration: Duration(minutes: 1),
      );
    });

    group('checkLimit', () {
      test('allows requests within limit', () {
        for (var i = 0; i < 5; i++) {
          expect(rateLimiter.checkLimit('test-key'), isTrue);
        }
      });

      test('blocks requests after limit exceeded', () {
        // Use up the limit
        for (var i = 0; i < 5; i++) {
          rateLimiter.checkLimit('test-key');
        }

        // Next request should be blocked
        expect(rateLimiter.checkLimit('test-key'), isFalse);
      });

      test('tracks different keys independently', () {
        // Use up limit for key1
        for (var i = 0; i < 5; i++) {
          rateLimiter.checkLimit('key1');
        }

        // key2 should still be allowed
        expect(rateLimiter.checkLimit('key2'), isTrue);
      });

      test('resets counter after window expires', () async {
        final shortLimiter = RateLimiter(
          maxAttempts: 3,
          windowDuration: Duration(milliseconds: 100),
        );

        // Use up the limit
        for (var i = 0; i < 3; i++) {
          shortLimiter.checkLimit('test-key');
        }

        expect(shortLimiter.checkLimit('test-key'), isFalse);

        // Wait for window to expire
        await Future.delayed(Duration(milliseconds: 150));

        // Should be allowed again
        expect(shortLimiter.checkLimit('test-key'), isTrue);
      });

      test('handles empty key', () {
        expect(rateLimiter.checkLimit(''), isTrue);
      });
    });

    group('getRemainingAttempts', () {
      test('returns max attempts initially', () {
        expect(rateLimiter.getRemainingAttempts('test-key'), equals(5));
      });

      test('decrements after each attempt', () {
        rateLimiter.checkLimit('test-key');
        expect(rateLimiter.getRemainingAttempts('test-key'), equals(4));

        rateLimiter.checkLimit('test-key');
        expect(rateLimiter.getRemainingAttempts('test-key'), equals(3));
      });

      test('returns 0 when limit exceeded', () {
        for (var i = 0; i < 5; i++) {
          rateLimiter.checkLimit('test-key');
        }

        expect(rateLimiter.getRemainingAttempts('test-key'), equals(0));
      });
    });

    group('getTimeUntilReset', () {
      test('returns null for unused key', () {
        expect(rateLimiter.getTimeUntilReset('test-key'), isNull);
      });

      test('returns duration until window reset', () async {
        final shortLimiter = RateLimiter(
          maxAttempts: 3,
          windowDuration: Duration(milliseconds: 200),
        );

        shortLimiter.checkLimit('test-key');

        final resetTime = shortLimiter.getTimeUntilReset('test-key');
        expect(resetTime, isNotNull);
        expect(resetTime!.inMilliseconds, greaterThan(0));
        expect(resetTime.inMilliseconds, lessThanOrEqualTo(200));

        // Wait a bit
        await Future.delayed(Duration(milliseconds: 50));

        final resetTime2 = shortLimiter.getTimeUntilReset('test-key');
        expect(resetTime2, isNotNull);
        expect(resetTime2!.inMilliseconds, lessThan(resetTime.inMilliseconds));
      });
    });

    group('reset', () {
      test('resets counter for specific key', () {
        // Use up the limit
        for (var i = 0; i < 5; i++) {
          rateLimiter.checkLimit('test-key');
        }

        expect(rateLimiter.checkLimit('test-key'), isFalse);

        rateLimiter.reset('test-key');

        expect(rateLimiter.checkLimit('test-key'), isTrue);
        expect(rateLimiter.getRemainingAttempts('test-key'), equals(4));
      });

      test('does not affect other keys', () {
        rateLimiter.checkLimit('key1');
        rateLimiter.checkLimit('key2');

        rateLimiter.reset('key1');

        expect(rateLimiter.getRemainingAttempts('key1'), equals(5));
        expect(rateLimiter.getRemainingAttempts('key2'), equals(4));
      });
    });

    group('cleanup', () {
      test('removes expired entries', () async {
        final shortLimiter = RateLimiter(
          maxAttempts: 3,
          windowDuration: Duration(milliseconds: 100),
        );

        shortLimiter.checkLimit('key1');
        shortLimiter.checkLimit('key2');

        // Wait for expiry
        await Future.delayed(Duration(milliseconds: 150));

        shortLimiter.cleanup();

        // Should start fresh
        expect(shortLimiter.getRemainingAttempts('key1'), equals(3));
        expect(shortLimiter.getRemainingAttempts('key2'), equals(3));
      });
    });
  });
}
