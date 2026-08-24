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

## Features

- **Ractor-Local Isolation**: Each Ractor lazily owns its resources through `Ratomic::LocalPool`; threads within the same Ractor share that Ractor-local pool.
- **Circuit Breaker Pattern**: Trips open after a configurable error threshold to fast-fail jobs and protect downstream databases.
- **Exponential Backoff**: Linear-to-exponential delay paths on transient network flakes.
- **Automated Health Probes**: Validates socket states transparently before routing workloads.

## Usage

Factories must be Ractor-shareable because `Ratomic::LocalPool` creates resources lazily
inside each Ractor. A small frozen factory object is suitable for production use:

```ruby
RedisFactory = Data.define(:url) do
  def call
    RedisClient.new(url:)
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
