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

export 'src/limit.dart';
