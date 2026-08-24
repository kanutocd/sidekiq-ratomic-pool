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

An illustrative result snapshot, interpretation, and captured output are
available in [`results/2026-08-24.md`](results/2026-08-24.md).
