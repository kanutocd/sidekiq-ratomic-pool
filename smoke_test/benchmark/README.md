# Sidekiq/Ratomic benchmark

This benchmark runs a real standalone Sidekiq server against the Redis service
used by the smoke test. It measures end-to-end enqueue-to-completion time for
jobs that use the injected `Ratomic::LocalPool` to perform Redis operations.

It is intended for comparative measurements, not as a stable performance claim.
Run the same workload and environment when comparing changes.

## Run

From this directory:

```bash
cd smoke_test/benchmark
./run.sh
```

The runner prints elapsed time, jobs per second, and `ps -L` snapshots of the
Sidekiq worker threads. `PSR` shows the CPU core on which each thread was most
recently scheduled; it does not guarantee CPU-bound parallel execution.

Useful overrides:

```bash
BENCHMARK_JOB_COUNT=1000 BENCHMARK_CONCURRENCY=8 ./run.sh
BENCHMARK_JOB_COUNT=1000 BENCHMARK_WORK_SECONDS=0.05 ./run.sh
```

`REDIS_PORT`, `REDIS_URL`, `RATOMIC_POOL_SIZE`, and `KEEP_REDIS=1` have the same
meaning as in the parent smoke-test harness.

## `connection_pool` comparison

Run the same workload with the standard `connection_pool` gem:

```bash
cd smoke_test/benchmark
BENCHMARK_JOB_COUNT=1000 BENCHMARK_CONCURRENCY=8 ./run_connection_pool.sh
```

The comparison uses the same Redis service, Sidekiq concurrency, pool size,
worker, Redis health `PING`, and benchmark timing. It compares pooling and
throughput behavior only; `connection_pool` does not provide Ratomic's
Ractor-local ownership model, circuit breaker, or retry policy.

## Ractor-native `4 × 20` topology

To demonstrate `Ratomic::LocalPool` directly, run four Ractors with 20 local
resources and 20 threads per Ractor:

```bash
cd smoke_test/benchmark
RACTOR_NATIVE_COUNT=4 \
RACTOR_NATIVE_THREADS=20 \
RATOMIC_POOL_SIZE=20 \
BENCHMARK_JOB_COUNT=80 \
./run_ractor_native.sh
```

This creates four independent Ractor-local pools. The topology is therefore
`4 Ractors × 20 resources = 80` total resource capacity. Threads inside each
Ractor share that Ractor's local pool; resources are not shared across Ractors.
Each Ractor uses a fixed worker-thread count and queues additional jobs, so a
large `BENCHMARK_JOB_COUNT` does not create one Ruby thread per job. The local
checkout timeout is configurable with `RATOMIC_POOL_TIMEOUT` and defaults to
10 seconds for this benchmark.

## Four independent Sidekiq servers

To model four independent Sidekiq/Ractor-local runtimes, run four standalone
Sidekiq processes with 20 worker threads and pool resources each:

```bash
cd smoke_test/benchmark
SIDEKIQ_SERVER_COUNT=4 \
BENCHMARK_CONCURRENCY=20 \
RATOMIC_POOL_SIZE=20 \
BENCHMARK_JOB_COUNT=400 \ # or add BENCHMARK_WORK_SECONDS=0.1 
./run_four_sidekiq_servers.sh
```

The runner reports 80 total worker threads and 80 total pool capacity. Each
process owns its own middleware runtime and Ractor-local pool. Operating-system
scheduling still determines which CPU runs each thread; the four processes do
not imply one process is permanently pinned to one CPU core.

An illustrative result snapshot, interpretation, and captured output are
available in [`results/2026-08-24.md`](results/2026-08-24.md).
