/// IMPLEMENTS REQUIREMENTS:
///   REQ-d00078: HHT Diary Auth Service - Rate limiting for brute force prevention
///
/// Rate limiter service for preventing brute force attacks.
///
/// Tracks request attempts per key (e.g., IP address + username combination)
/// within a sliding time window. Default configuration allows 5 attempts
/// per minute per key, with account lockout after exceeding the limit.

class RateLimiter {
  final int maxAttempts;
  final Duration windowDuration;
  final Map<String, _RateLimitEntry> _entries = {};

  /// Creates a rate limiter with specified limits.
  ///
  /// [maxAttempts] Maximum number of attempts allowed within the window
  /// [windowDuration] Time window for tracking attempts
  RateLimiter({
    required this.maxAttempts,
    required this.windowDuration,
  });

  /// Checks if a request is allowed for the given key.
  ///
  /// Returns true if within limits, false if rate limit exceeded.
  /// Automatically records the attempt if allowed.
  bool checkLimit(String key) {
    final entry = _getOrCreateEntry(key);

    // Remove expired attempts
    entry.removeExpiredAttempts(windowDuration);

    // Check if limit is exceeded
    if (entry.attemptCount >= maxAttempts) {
      return false;
    }

    // Record new attempt
    entry.recordAttempt();
    return true;
  }

  /// Gets the number of remaining attempts for a key.
  ///
  /// Returns the number of attempts remaining before rate limit is hit.
  int getRemainingAttempts(String key) {
    if (!_entries.containsKey(key)) {
      return maxAttempts;
    }

    final entry = _entries[key]!;
    entry.removeExpiredAttempts(windowDuration);

    final remaining = maxAttempts - entry.attemptCount;
    return remaining < 0 ? 0 : remaining;
  }

  /// Gets the time until the rate limit resets for a key.
  ///
  /// Returns null if the key has no recorded attempts.
  Duration? getTimeUntilReset(String key) {
    if (!_entries.containsKey(key)) {
      return null;
    }

    final entry = _entries[key]!;
    if (entry.attempts.isEmpty) {
      return null;
    }

    final oldestAttempt = entry.attempts.first;
    final resetTime = oldestAttempt.add(windowDuration);
    final now = DateTime.now();

    if (resetTime.isBefore(now)) {
      return null;
    }

    return resetTime.difference(now);
  }

  /// Resets the rate limit for a specific key.
  ///
  /// Useful for clearing failed login attempts after successful authentication.
  void reset(String key) {
    _entries.remove(key);
  }

  /// Removes expired entries from memory.
  ///
  /// Should be called periodically to prevent memory leaks.
  void cleanup() {
    final now = DateTime.now();
    _entries.removeWhere((key, entry) {
      entry.removeExpiredAttempts(windowDuration);
      return entry.attempts.isEmpty;
    });
  }

  _RateLimitEntry _getOrCreateEntry(String key) {
    return _entries.putIfAbsent(key, () => _RateLimitEntry());
  }
}

/// Internal class for tracking attempts per key.
class _RateLimitEntry {
  final List<DateTime> attempts = [];

  int get attemptCount => attempts.length;

  void recordAttempt() {
    attempts.add(DateTime.now());
  }

  void removeExpiredAttempts(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    attempts.removeWhere((timestamp) => timestamp.isBefore(cutoff));
  }
}
