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
      pool_timeout: 1,
      max_retries: 3,
      retry_delay: 0.2,
      cb_threshold: 5,
      cb_timeout: 30,
      factory: RedisFactory.new(ENV.fetch('REDIS_URL')).freeze
  end
end
```

The middleware injects the pool into a worker accessor matching `pool_name`.
For example, a Redis-backed worker can use `redis_pool.with` inside `perform`:

```ruby
class RedisWorker
  include Sidekiq::Job

  attr_accessor :redis_pool

  def perform(key, value)
    redis_pool.with do |redis|
      redis.call('SET', key, value)
    end
  end
end
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
PoolInput = Data.define(:pool_name, :size, :pool_timeout, :factory, :jobs)

ractor = Ractor.new(
  Ractor.make_shareable(
    PoolInput.new(:redis_pool, 20, 1, RedisFactory.new(ENV.fetch('REDIS_URL')), 100)
  )
) do |input|
  pool = Sidekiq::Ratomic::Pool.new(
    pool_name: input.pool_name,
    size: input.size,
    pool_timeout: input.pool_timeout,
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

Threads created by the host inside that Ractor use the same Ractor-local pool;
resources must never be returned to, or used by, another Ractor. The integration
contract is:

- The host owns Ractor creation, job routing, supervision, and shutdown. This
  gem provides pooling middleware, not a Ractor scheduler.
- Pool configuration and factories crossing a Ractor boundary must be
  shareable. Construct the mutable pool runtime and any stateful validator
  inside the destination Ractor.
- `Ratomic::LocalPool` lazily creates resources in their owning Ractor. Threads
  in that Ractor share its resources, while other Ractors receive independent
  pools and resources.
- Retry, health validation, circuit breaking, failure accounting, and explicit
  close/shutdown remain local to the runtime that owns the resources. A
  half-open circuit admits one recovery probe at a time.

The middleware runtime is ordinary mutable state and is not itself required to
be Ractor-shareable. Hosts must supervise failures and coordinate cancellation
across Ractors when their application topology requires it.

The opt-in host adapter example demonstrates bounded dispatch, real Redis
connections, and per-Ractor activity metrics without making Ractor scheduling
part of the gem:

```bash
cd smoke_test
docker compose up -d redis
REDIS_URL="${REDIS_URL:-redis://127.0.0.1:6380/0}" \
RACTOR_NATIVE_COUNT=4 \
RACTOR_NATIVE_THREADS=20 \
RATOMIC_POOL_SIZE=20 \
RATOMIC_POOL_TIMEOUT=1 \
RACTOR_QUEUE_CAPACITY=40 \
BENCHMARK_JOBS_PER_RACTOR=5000 \
BENCHMARK_WORK_SECONDS=0.05 \
bundle exec ruby ./benchmark/ractor_host_adapter.rb
```

The adapter defaults its Ractor count to `Etc.nprocessors` when the variable
is omitted. That CPU-based default belongs to the example only; production
applications remain responsible for choosing and supervising their topology.
The adapter performs real Redis `PING`, `INCR`, and `HSET` operations and
reports Ruby, Sidekiq, Ratomic, and Redis versions, elapsed time, throughput,
and per-Ractor results. With four Ractors, the command above processes 20,000
jobs and demonstrates four independent pools of 20 resources, shared by 20
threads inside each Ractor.

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
