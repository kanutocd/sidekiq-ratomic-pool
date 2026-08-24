# Redis and Sidekiq smoke test

This is an end-to-end example of the gem using a real Redis server, real
`RedisClient` connections, a standalone Sidekiq server, and a separate Sidekiq
client process.

The server middleware creates a frozen, Ractor-shareable factory. Each
`Ratomic::LocalPool` context lazily creates and reuses Redis clients, validates
them with `PING`, and exposes the pool as `redis_pool` to `RedisSmokeWorker`.

## Run

Requirements: Ruby 4+, Bundler, Docker, and Docker Compose.

```bash
cd smoke_test
./run.sh
```

The script starts Redis, launches Sidekiq as a separate process, enqueues jobs
from a separate client process, waits for all jobs to be processed, and cleans
up the Redis container and Sidekiq process.

While jobs are running, it prints:

- a **`ps -L`** snapshot showing the Sidekiq process,
- worker thread IDs,
- **`PSR`** (the CPU core on which each thread was most recently scheduled),
- **CPU usage**
- **thread count**

CPU scheduling is controlled by the operating system, so `PSR` is an
observation rather than a guarantee that every core is used on every run.
Set `KEEP_REDIS=1` to leave Redis running for inspection. Useful overrides include:

```bash
SMOKE_JOB_COUNT=100 SIDEKIQ_CONCURRENCY=8 ./run.sh
```

Increase `SMOKE_WORK_SECONDS` if the process snapshot is too brief:

```bash
SMOKE_JOB_COUNT=100 SMOKE_WORK_SECONDS=0.25 SIDEKIQ_CONCURRENCY=8 ./run.sh
```

The smoke test uses only the local gem plus its example dependencies; it does
not add Sidekiq or Redis as production dependencies of `sidekiq-ratomic-pool`.
The harness uses host port `6380` by default to avoid colliding with a local
Redis on port `6379`; override it with `REDIS_PORT` or provide a complete
`REDIS_URL`.

## Benchmark

For comparative throughput measurements, see [`benchmark/`](benchmark/). The
Sidekiq-backed benchmark runners use the same real Redis and standalone Sidekiq
setup, while the host-owned Ractor adapter performs host-scheduled work against
real Redis. They report end-to-end elapsed time and jobs per second:

```bash
cd smoke_test/benchmark
./run.sh
```
