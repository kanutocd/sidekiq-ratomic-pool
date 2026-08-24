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

- **Ractor-Local Isolation**: Each Ractor lazily owns its resources through `Ratomic::LocalPool`; threads within the same Ractor share that Ractor-local pool.
- **Circuit Breaker Pattern**: Trips open after a configurable threshold of checkout, health-check, or configured retryable I/O failures.
- **Exponential Backoff**: Applies increasing retry delays to transient checkout and retryable resource-operation failures.
- **Automated Health Probes**: Validates resources with `ping`, `active?`, or a caller-supplied validator before use.
- **Configurable Failure Policy**: Non-retryable worker exceptions propagate without changing circuit state, avoiding accidental duplicate work.

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

## Smoke test

The [`smoke_test/`](smoke_test/) harness runs Redis in Docker, starts a standalone
Sidekiq server, enqueues jobs from a separate client process, and verifies the
results through real Redis connections. It also prints `ps -L` snapshots showing
Sidekiq worker threads and the CPU core (`PSR`) on which they were recently scheduled:

```bash
cd smoke_test
./run.sh
```
