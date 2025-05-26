import 'dart:math';
import 'package:prf/prf.dart';
import 'package:synchronized/synchronized.dart';

/// A robust, industry-grade token bucket rate limiter using `prf`.
///
/// Limits actions to a defined number within a given duration,
/// using a refillable token system with persistent storage.
///
/// Example:
/// ```dart
/// final limiter = RateLimiter('chat_send', maxTokens: 100, refillDuration: Duration(minutes: 15));
/// final canSend = await limiter.tryConsume();
/// ```
class RateLimiter extends BaseServiceObject {
  /// The maximum number of tokens that can be accumulated.
  final int maxTokens;

  /// The time period over which tokens are fully replenished.
  final Duration refillDuration;

  final Prf<double> _tokenCountWithCache;
  final Prf<DateTime> _lastRefillWithCache;

  BasePrfObject<double> get _tokenCount =>
      useCache ? _tokenCountWithCache : _tokenCountWithCache.isolated;

  BasePrfObject<DateTime> get _lastRefill =>
      useCache ? _lastRefillWithCache : _lastRefillWithCache.isolated;

  final Lock _lock = Lock();

  /// Creates a new rate limiter with the specified prefix and configuration.
  ///
  /// - [prefix] is used to create unique keys for storing rate limiter data.
  /// - [maxTokens] defines the maximum number of operations allowed in the time period.
  /// - [refillDuration] specifies the time period over which tokens are fully replenished.
  RateLimiter(
    prefix, {
    required this.maxTokens,
    required this.refillDuration,
    super.useCache,
  })  : _tokenCountWithCache = Prf<double>(
          'prf_${prefix}_rate_tokens',
          defaultValue: maxTokens.toDouble(),
        ),
        _lastRefillWithCache = Prf<DateTime>(
          'prf_${prefix}_rate_last_refill',
          defaultValue: DateTime.now(),
        );

  /// Returns `true` if the limiter is currently rate-limited (no token available).
  ///
  /// This is equivalent to checking if `getAvailableTokens() < 1`.
  Future<bool> isLimitedNow() async {
    final available = await getAvailableTokens();
    return available < 1;
  }

  /// Returns `true` if the limiter has at least one token available.
  ///
  /// This is the opposite of [isLimitedNow] and is provided as a convenience method.
  Future<bool> isReady() async {
    return !(await isLimitedNow());
  }

  /// Attempts to consume 1 token.
  ///
  /// Returns `true` if the action is allowed (token consumed), or `false` if rate limited.
  ///
  /// This method automatically handles token refill based on elapsed time since the last check.
  /// Attempts to consume 1 token atomically.
  Future<bool> tryConsume() => _lock.synchronized(() async {
        final now = DateTime.now();

        final tokens = await _tokenCount.getOrFallback(maxTokens.toDouble());
        final last = await _lastRefill.getOrFallback(now);

        final elapsedMs = now.difference(last).inMilliseconds;
        final refillRatePerMs = maxTokens / refillDuration.inMilliseconds;
        final refilledTokens = tokens + (elapsedMs * refillRatePerMs);
        final newTokenCount = min(maxTokens.toDouble(), refilledTokens);

        if (newTokenCount >= 1) {
          await _tokenCount.set(newTokenCount - 1);
          await _lastRefill.set(now);
          return true;
        } else {
          await _tokenCount.set(newTokenCount);
          await _lastRefill.set(now);
          return false;
        }
      });

  /// Executes the provided action if a token is available, otherwise returns null.
  ///
  /// This is a convenience method that combines [tryConsume] with executing an action.
  /// If a token is available, it will be consumed and the action will be executed.
  /// If no token is available, null will be returned without executing the action.
  ///
  /// Example:
  /// ```dart
  /// final result = await limiter.runIfAllowed(() async {
  ///   return await api.sendMessage(text);
  /// });
  /// // result will be null if rate limited
  /// ```
  Future<T?> runIfAllowed<T>(Future<T> Function() action) async {
    if (await tryConsume()) {
      return await action();
    }
    return null;
  }

  /// Gets the number of tokens currently available.
  ///
  /// This method calculates the current token count based on the stored value
  /// plus any tokens that would have been refilled since the last check.
  /// The returned value is capped at [maxTokens].
  Future<double> getAvailableTokens() async {
    final now = DateTime.now();
    final tokens = await _tokenCount.getOrFallback(maxTokens.toDouble());
    final last = await _lastRefill.getOrFallback(now);

    final elapsedMs = now.difference(last).inMilliseconds;
    final refillRatePerMs = maxTokens / refillDuration.inMilliseconds;
    final refilledTokens = tokens + (elapsedMs * refillRatePerMs);

    return min(maxTokens.toDouble(), refilledTokens);
  }

  /// Calculates the time remaining until the next token is available.
  ///
  /// Returns Duration.zero if a token is already available.
  /// This is useful for implementing retry mechanisms or displaying wait times to users.
  Future<Duration> timeUntilNextToken() async {
    final available = await getAvailableTokens();
    if (available >= 1) return Duration.zero;

    final refillRatePerMs = maxTokens / refillDuration.inMilliseconds;
    final needed = 1 - available;
    final msUntilNext = (needed / refillRatePerMs).ceil();
    return Duration(milliseconds: msUntilNext);
  }

  /// Fully resets the limiter to its initial state.
  ///
  /// This restores the token count to [maxTokens] and resets the refill timestamp
  /// to the current time. Useful for scenarios where you want to clear rate limits,
  /// such as after a user upgrade or payment.
  Future<void> reset() => _lock.synchronized(() async {
        await _tokenCount.set(maxTokens.toDouble());
        await _lastRefill.set(DateTime.now());
      });

  /// Removes all persisted state from storage.
  ///
  /// This completely clears all rate limiter data from persistent storage.
  /// Primarily intended for testing and debugging purposes.
  Future<void> removeAll() => _lock.synchronized(() async {
        await _tokenCount.remove();
        await _lastRefill.remove();
      });

  /// Checks if any rate limiter state exists in persistent storage.
  ///
  /// Returns true if either the token count or last refill timestamp
  /// exists in SharedPreferences. Useful for determining if this is
  /// the first time the rate limiter is being used.
  Future<bool> anyStateExists() async {
    return await _tokenCount.existsOnPrefs() ||
        await _lastRefill.existsOnPrefs();
  }

  /// Returns the `DateTime` when a token will be available.
  /// Returns `DateTime.now()` if already available.
  Future<DateTime> nextAllowedTime() async {
    final remaining = await timeUntilNextToken();
    return DateTime.now().add(remaining);
  }

  /// Returns detailed stats useful for debugging and logging.
  Future<RateLimiterStats> debugStats() async {
    final now = DateTime.now();
    final tokens = await _tokenCount.getOrFallback(maxTokens.toDouble());
    final last = await _lastRefill.getOrFallback(now);
    final elapsedMs = now.difference(last).inMilliseconds;
    final refillRatePerMs = maxTokens / refillDuration.inMilliseconds;
    final refilledTokens = tokens + (elapsedMs * refillRatePerMs);
    final cappedTokenCount = min(maxTokens.toDouble(), refilledTokens);

    return RateLimiterStats(
      tokens: tokens,
      lastRefill: last,
      maxTokens: maxTokens.toDouble(),
      refillDuration: refillDuration,
      now: now,
      refillRatePerMs: refillRatePerMs,
      refilledTokens: refilledTokens,
      cappedTokenCount: cappedTokenCount,
    );
  }
}

/// A data class representing the statistics of a rate limiter at a given point in time.
///
/// This class provides detailed information about the current state of the rate limiter,
/// which can be useful for debugging, logging, and monitoring purposes.
class RateLimiterStats {
  /// The current number of tokens available in the rate limiter.
  final double tokens;

  /// The `DateTime` when the rate limiter was last refilled.
  final DateTime lastRefill;

  /// The maximum number of tokens that the rate limiter can hold.
  final double maxTokens;

  /// The duration it takes to fully refill the rate limiter.
  final Duration refillDuration;

  /// The current `DateTime` when the stats were generated.
  final DateTime now;

  /// The rate at which tokens are refilled per millisecond.
  final double refillRatePerMs;

  /// The total number of tokens refilled since the last refill.
  final double refilledTokens;

  /// The number of tokens available, capped at the maximum token limit.
  final double cappedTokenCount;

  /// Constructs a [RateLimiterStats] instance with the provided values.
  ///
  /// All parameters are required to ensure a complete snapshot of the rate limiter's state.
  const RateLimiterStats({
    required this.tokens,
    required this.lastRefill,
    required this.maxTokens,
    required this.refillDuration,
    required this.now,
    required this.refillRatePerMs,
    required this.refilledTokens,
    required this.cappedTokenCount,
  });

  /// Returns a string representation of the rate limiter statistics.
  ///
  /// This includes detailed information about the tokens, refill times, and rates,
  /// formatted for easy reading and interpretation.
  @override
  String toString() {
    return '''
--- RateLimiterStats: ---
-------------------------
    tokens stored:       $tokens
    last refill:         $lastRefill
    now:                 $now
    elapsed ms:          ${now.difference(lastRefill).inMilliseconds}
    refill rate/ms:      $refillRatePerMs
    refilled tokens:     $refilledTokens
    capped token count:  $cappedTokenCount
    max tokens:          $maxTokens
    refill duration:     ${refillDuration.inMilliseconds} ms
''';
  }
}
