```sh
BENCHMARK_JOB_COUNT=100 \
BENCHMARK_WORK_SECONDS=0.1 \
BENCHMARK_TIMEOUT=30 \
BENCHMARK_CONCURRENCY=4 \
./run.sh
```

```out
[+] up 2/2
 ✔ Network smoke_test_default   Created                                                                                                                                                                                                  0.1s
 ✔ Container smoke_test-redis-1 Started                                                                                                                                                                                                  0.6s

CPU cores visible to the benchmark: 4
Sidekiq server PID: 1977628

[21:08:01] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
1977628 1977628   3 1850    2 Rl+  bundle
1977628 1977650   1  0.0    2 Sl+  bundle

[21:08:03] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
1977628 1977628   1 28.2    8 Sl+  bundle
1977628 1977650   3  0.0    8 Sl+  bundle
1977628 1977654   0  0.0    8 Sl+  sidekiq.heartbe
1977628 1977655   1  0.0    8 Sl+  sidekiq.schedul
1977628 1977656   3  0.0    8 Sl+  sidekiq.default
1977628 1977657   3  0.0    8 Sl+  sidekiq.default
1977628 1977658   3  0.0    8 Sl+  sidekiq.default
1977628 1977659   3  0.0    8 Sl+  sidekiq.default

[21:08:04] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
1977628 1977628   1 15.0    8 Sl+  bundle
1977628 1977650   1  0.0    8 Sl+  bundle
1977628 1977654   0  0.0    8 Sl+  sidekiq.heartbe
1977628 1977655   1  0.0    8 Sl+  sidekiq.schedul
1977628 1977656   0  0.4    8 Sl+  sidekiq.default
1977628 1977657   0  0.4    8 Sl+  sidekiq.default
1977628 1977658   0  0.4    8 Sl+  sidekiq.default
1977628 1977659   1  0.0    8 Sl+  sidekiq.default
INFO  2026-08-24T13:08:02.087Z pid=1977630 tid=16egu: Sidekiq 8.1.7 connecting to Redis with options {size: 10, pool_name: "internal", url: "redis://127.0.0.1:6479/0"}
Benchmark passed: 100 jobs in 2.577 seconds (38.80 jobs/sec)
[+] down 2/2
 ✔ Container smoke_test-redis-1 Removed                                     0.4s
 ✔ Network smoke_test_default   Removed                                     0.2s
```