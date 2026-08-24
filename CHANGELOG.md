## [Unreleased]

- Added Sidekiq middleware with Ratomic `LocalPool` resource injection,
  health validation, exponential retries, and circuit-breaker fast failure.
- Added thread-boundary pool behavior tests and synchronized RBS signatures for the
  Ractor-local implementation.
- Added the `quality` Rake task covering tests, RuboCop, Steep, and YARD validation.
- Enforced at least 99% line and branch coverage through SimpleCov.
- Used Ratomic's native `Counter` primitive.
- Added YARD validation and documented the public pool API.
- Added argument validation and current-Ractor pool shutdown.
- Added configurable retryable I/O errors and real exponential backoff delays.
- Prevented non-retryable worker exceptions from affecting the circuit breaker.
