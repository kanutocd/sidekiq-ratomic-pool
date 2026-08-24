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

`REDIS_PORT`, `REDIS_URL`, `RATOMIC_POOL_SIZE`, `RATOMIC_POOL_TIMEOUT`, and
`KEEP_REDIS=1` have the same meaning as in the parent smoke-test harness.

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

To demonstrate `Ratomic::LocalPool` directly—not the Sidekiq middleware—run
four Ractors with 20 local resources and 20 threads per Ractor:

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
1 second. The default simulated work is `BENCHMARK_WORK_SECONDS=0.05`, matching
the Sidekiq worker benchmark.

## Four independent Sidekiq servers

To benchmark the real `Sidekiq::Ratomic::Pool` middleware across independent
Ruby processes, run four standalone Sidekiq processes with 20 worker threads
and pool resources each:

```bash
cd smoke_test/benchmark
SIDEKIQ_SERVER_COUNT=4 \
BENCHMARK_CONCURRENCY=20 \
RATOMIC_POOL_SIZE=20 \
RATOMIC_POOL_TIMEOUT=1 \
BENCHMARK_WORK_SECONDS=0.05 \
BENCHMARK_JOB_COUNT=400 \
./run_four_sidekiq_servers.sh
```

The runner reports 80 total worker threads and 80 total pool capacity. Each
process owns its own middleware runtime and runs Sidekiq threads in its main
Ractor; this benchmark does not create four Ractors per Sidekiq process.
Operating-system scheduling still determines which CPU runs each thread; the
four processes do not imply one process is permanently pinned to one CPU core.

## Host-owned `Sidekiq::Ratomic::Pool` Ractors

To demonstrate the gem’s Ractor-local middleware runtime with real Redis, use
the opt-in host adapter. The host creates the Ractors, constructs one
`Sidekiq::Ratomic::Pool` inside each Ractor, dispatches bounded work, and
reports per-Ractor activity, elapsed time, and aggregate throughput:

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

This is a host-owned adapter demonstration, not Sidekiq queue processing. It
performs real Redis `PING`, `INCR`, and `HSET` operations through one
Ractor-local pool per Ractor. The gem provides the pool and middleware runtime;
the host remains responsible for Ractor creation, dispatch, supervision, and
shutdown. Stop Redis after the run with `docker compose down` when appropriate.

These settings match the comparison topology and workload: 4 Ractors × 20
threads × 20 resources, 20,000 total jobs, 0.05 seconds of work per job, and
a 1-second checkout timeout. `BENCHMARK_JOBS_PER_RACTOR` is multiplied by the
Ractor count, so use `5000` to produce 20,000 total jobs.

All three runners print the visible CPU count, runtime versions, Redis version,
run ID, topology, checkout timeout, workload, elapsed time, and throughput. The
host adapter also prints per-Ractor results and queue capacity. For repeatable
comparisons, run each command multiple times with the same explicit environment
and compare the median or the full set of results. The native benchmark measures
direct Redis work inside host-owned Ractors; the Sidekiq benchmark additionally
includes queue polling, job fetch, middleware, acknowledgment, and server
lifecycle overhead.

## Run more samples

Keep Redis running while collecting a sample set, and use a unique
`BENCHMARK_RUN_ID` for every run. The following commands use the same real-Redis
workload across the process, native, and host-owned Ractor examples:

```bash
cd smoke_test
docker compose up -d redis

SIDEKIQ_SERVER_COUNT=4 \
BENCHMARK_CONCURRENCY=20 \
RATOMIC_POOL_SIZE=20 \
RATOMIC_POOL_TIMEOUT=1 \
BENCHMARK_WORK_SECONDS=0.05 \
BENCHMARK_JOB_COUNT=20000 \
BENCHMARK_RUN_ID=sidekiq-$(date +%s%N) \
./benchmark/run_four_sidekiq_servers.sh | tee /tmp/sidekiq-ratomic-four.out

RACTOR_NATIVE_COUNT=4 \
RACTOR_NATIVE_THREADS=20 \
RATOMIC_POOL_SIZE=20 \
RATOMIC_POOL_TIMEOUT=1 \
BENCHMARK_WORK_SECONDS=0.05 \
BENCHMARK_JOB_COUNT=20000 \
BENCHMARK_RUN_ID=native-$(date +%s%N) \
./benchmark/run_ractor_native.sh | tee /tmp/sidekiq-ratomic-native.out

RACTOR_NATIVE_COUNT=4 \
RACTOR_NATIVE_THREADS=20 \
RATOMIC_POOL_SIZE=20 \
RATOMIC_POOL_TIMEOUT=1 \
RACTOR_QUEUE_CAPACITY=40 \
BENCHMARK_JOBS_PER_RACTOR=5000 \
BENCHMARK_WORK_SECONDS=0.05 \
BENCHMARK_RUN_ID=host-ractor-$(date +%s%N) \
REDIS_URL="${REDIS_URL:-redis://127.0.0.1:6380/0}" \
bundle exec ruby ./benchmark/ractor_host_adapter.rb | tee /tmp/sidekiq-ratomic-host-ractor.out

docker compose down
```

Repeat each command several times on an otherwise idle host. Compare elapsed
time and jobs/sec using the median, and retain the complete output when sharing
results. The host adapter’s 5,000 jobs are per Ractor, producing 20,000 total
jobs with four Ractors.
