## [Unreleased]

- Added a dedicated `smoke_test/benchmark/` harness for comparative end-to-end
  throughput measurements using real Redis, Sidekiq, and Ratomic pooling.
- Added configurable benchmark workloads with elapsed-time, jobs-per-second, and
  Sidekiq process/thread scheduling output.
- Added an illustrative benchmark result, interpretation, and captured output
  snapshot documenting the workload and its limitations.
- Added a matched `connection_pool` comparison runner using the same Redis,
  Sidekiq, pooling, health-check, and workload settings.
- Added a Ractor-native `4 × 20` benchmark and a four-process Sidekiq benchmark
  demonstrating 80 total worker/resource capacity across independent runtimes.
- Made the Ractor benchmark scalable for large job counts by using fixed worker
  threads with queued jobs instead of creating one Ruby thread per job.
- Linked the benchmark from the smoke-test documentation.

## [0.2.0] - 2026-08-25

- Added a real Redis-backed `smoke_test/` harness with standalone Sidekiq client
  and server examples, Docker Compose Redis, and process/thread scheduling output.
- Made the middleware compatible with Sidekiq's per-job middleware instantiation
  by sharing each configured pool runtime across middleware instances.
- Added support for Sidekiq-style positional middleware options and validation for
  unknown options.
- Added smoke coverage for multi-threaded job processing across visible CPUs.

## [0.1.0] - 2026-08-24

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
