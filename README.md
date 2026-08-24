# sidekiq-ratomic-pool

[![Gem Version](https://badge.fury.io/rb/sidekiq-ratomic-pool.svg)](https://badge.fury.io/rb/sidekiq-ratomic-pool)
[![CI](https://github.com/kanutocd/sidekiq-ratomic-pool/workflows/CI/badge.svg)](https://github.com/kanutocd/sidekiq-ratomic-pool/actions)
[![Ruby Version](https://img.shields.io/badge/ruby-%3E%3D%204.0-ruby.svg)](https://www.ruby-lang.org/en/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)


Sidekiq server middleware leveraging `Ratomic::LocalPool` for Ractor-local resource ownership. It includes automated connection health validation, exponential backoff retries, and an integrated **Circuit Breaker** to help prevent cascading resource failures.

## Installation

Add to your `Gemfile`:

```ruby
gem "sidekiq-ratomic-pool"
```

## Sidekiq dependency

Despite its name, this gem does not declare `sidekiq` as a runtime dependency.
It provides a `Sidekiq::Ratomic::Pool` middleware implementation using the
standard `call(job, payload, queue) { ... }` middleware contract. Sidekiq is the
primary supported integration and the reason for the gem name, but other
Sidekiq-compatible job frameworks can use it if they support the same contract
and worker pool accessor pattern.

## Features

- **Ractor-Local Isolation**: A pool runtime used inside a Ractor lazily owns
  its resources through `Ratomic::LocalPool`; threads within that Ractor share
  its Ractor-local pool.
- **Circuit Breaker Pattern**: Trips open after a configurable threshold of checkout, health-check, or configured retryable I/O failures.
- **Exponential Backoff**: Applies increasing retry delays to transient checkout and retryable resource-operation failures.
- **Automated Health Probes**: Validates resources with `ping`, `active?`, or a caller-supplied validator before use.
- **Configurable Failure Policy**: Non-retryable worker exceptions propagate without changing circuit state, avoiding accidental duplicate work.
- **Ratomic-Native Failure Accounting**: Tracks circuit-breaker failures with the Ractor-shareable `Ratomic::Counter` primitive instead of adding `concurrent-ruby`.

## Usage

Factories are made Ractor-shareable because `Ratomic::LocalPool` creates resources
lazily inside each Ractor. A small frozen factory object is suitable for production use:

```ruby
RedisFactory = Data.define(:url) do
  def call
    RedisClient.config(url:).new_client
  end
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Ratomic::Pool,
      pool_name: :redis_pool,
      size: 10,
      max_retries: 3,
      retry_delay: 0.2,
      cb_threshold: 5,
      cb_timeout: 30,
      factory: RedisFactory.new(ENV.fetch('REDIS_URL')).freeze
  end
end
```

Workers use the injected pool with `with`:

```ruby
redis_pool.with { |redis| redis.call('PING') }
```

Resource checkout/health failures and configured retryable I/O errors use exponential backoff.
Other exceptions raised by the worker block propagate without being retried, preventing
accidental duplication of non-idempotent work.

### Host-owned Ractor scheduling

This gem provides Ractor-safe, Ractor-local resource ownership; it does not
create Ractors or dispatch Sidekiq jobs into them. The host framework or
application owns Ractor creation, job routing, supervision, and shutdown.

`Sidekiq::Ratomic::Pool` contains mutable circuit-breaker coordination state and
is not itself required to be Ractor-shareable. A Ractor-aware host should pass
only shareable configuration and factory data into each Ractor, construct that
Ractor's pool runtime there, and execute the resource-backed work inside the
same Ractor:

```ruby
PoolInput = Data.define(:pool_name, :size, :factory, :jobs)

ractor = Ractor.new(
  Ractor.make_shareable(
    PoolInput.new(:redis_pool, 20, RedisFactory.new(ENV.fetch('REDIS_URL')), 100)
  )
) do |input|
  pool = Sidekiq::Ratomic::Pool.new(
    pool_name: input.pool_name,
    size: input.size,
    factory: input.factory
  )

  input.jobs.times do
    pool.with { |resource| resource.call('PING') }
  end

  pool.close
  :complete
end

ractor.value
```

Threads created by the host inside that Ractor use the same Ractor-local pool.
Resources must not be returned to, or used by, another Ractor. See the
[`Ractor-local pooling implementation plan`](docs/ractor-local-pooling-implementation-plan.md)
for the integration contract and rollout criteria.

The circuit breaker uses `Ratomic::Counter` for its failure count. This keeps the
counter aligned with Ratomic's Ractor-safe primitive model and avoids a separate
`concurrent-ruby` production dependency; the pool mutex still protects the
failure-count and circuit-state transition as one operation.

## Smoke test

The [`smoke_test/`](smoke_test/) harness runs Redis in Docker, starts a standalone
Sidekiq server, enqueues jobs from a separate client process, and verifies the
results through real Redis connections. It also prints `ps -L` snapshots showing
Sidekiq worker threads and the CPU core (`PSR`) on which they were recently scheduled:

```bash
cd smoke_test
./run.sh
```

For comparative throughput measurements, see the [`smoke_test/benchmark/`](smoke_test/benchmark/)
harness.
