import 'package:flutter/foundation.dart';
import 'package:limit/limit.dart';

/// Example usage of the `limit` package.
///
/// Run this file in a Flutter or Dart console project after adding the package.
/// It demonstrates how to use the Cooldown and RateLimiter utilities.
Future<void> main() async {
  // Example 1: Cooldown
  final cooldown = Cooldown('daily_reward', duration: Duration(seconds: 10));
  final isCooldownActive = await cooldown.isCooldownActive();

  if (isCooldownActive) {
    final remaining = await cooldown.timeRemaining();
    debugPrint(
        '⏲ Cooldown active, please wait ${remaining.inSeconds} seconds.');
  } else {
    await cooldown.activateCooldown();
    debugPrint('🎉 Cooldown activated! You can now claim your reward.');
  }

  // Example 2: RateLimiter
  final rateLimiter = RateLimiter(
    'api_calls',
    maxTokens: 5,
    refillDuration: Duration(seconds: 30),
  );

  for (int i = 1; i <= 7; i++) {
    final allowed = await rateLimiter.tryConsume();

    if (allowed) {
      debugPrint('✅ API call $i allowed.');
    } else {
      final wait = await rateLimiter.timeUntilNextToken();
      debugPrint(
          '❌ API call $i blocked. Try again in ${wait.inSeconds} seconds.');
    }
  }
}
