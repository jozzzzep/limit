/// `limit` Package Barrel File
///
/// Provides a single import point for the core limit package features:
/// - [Cooldown] — manage fixed-duration cooldowns (e.g. daily rewards)
/// - [RateLimiter] — token bucket rate limiter (e.g. 1000 actions per 15 minutes)
///
/// Example usage:
/// ```dart
/// import 'package:limit/limit.dart';
///
/// final cooldown = Cooldown('daily_reward', duration: Duration(hours: 24));
/// final limiter = RateLimiter('api_calls', maxTokens: 100, refillDuration: Duration(minutes: 15));
/// ```
library;

/// A utility for managing cooldown logic using persisted DateTime and Activation Count.
///
/// Stores:
/// - the last activation time (`<prefix>_cd_date_time`)
/// - the total activation count (`<prefix>_cd_count`)
///
/// Example:
/// ```dart
/// final cooldown = Cooldown('daily_reward', duration: Duration(hours: 24));
/// if (!await cooldown.isCooldownActive()) {
///   await cooldown.activateCooldown();
/// }
/// ```
export 'services/cooldown.dart';

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
export 'services/rate_limiter.dart';
