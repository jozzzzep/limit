## 1.0.6

- Added proper documentation to the library barrel file.
- Added example file for pub.dev

## 1.0.5

- Improved README navigation by adding **Back to Table of Contents** links.
- Clarified API notes and examples in README.
- Minor internal cleanup of unused private fields.

## 1.0.4

- **All limiters are now fully synchronized.**
- This version introduces **comprehensive internal locking** to all limits to prevent concurrent access issues in asynchronous or multi-call scenarios.
- Previously, state mutations were **not guarded**, which could cause race conditions, corrupted values, or inconsistent behavior — especially in rapid or concurrent calls.

## 1.0.3

- Improved documentation and examples in the README and comments to enhance clarity and usability.

## 1.0.2

- Enhanced the package with a suite of comprehensive tests to ensure reliability and robustness. Introduced testing utilities to facilitate easier test writing and maintenance.

## 1.0.1

### ✨ **`limit` initial release**

Persistent, plug-and-play utilities for managing cooldowns and rate limits across sessions, isolates, and app restarts — no boilerplate, no manual timers, no storage code.

**Features included:**

- ⏲ **Cooldown** — fixed-time cooldown utility (e.g. daily rewards, retry delays)
- 📊 **RateLimiter** — token bucket rate limiter (e.g. 1000 actions per 15 minutes)

**Highlights:**

- One-line setup (`Cooldown` / `RateLimiter`)
- Automatic persistence across app restarts
- Async-safe, isolate-friendly behavior
- Built-in usage stats and reset methods
- Optional caching for extra performance

> **Notes**: Originally was part of the **prf** package. Extracted into a standalone package for modularity, lighter dependencies, and focused use. Ideal for apps needing easy-to-integrate time-based limits without extra logic.
