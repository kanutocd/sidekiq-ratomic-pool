```sh
BENCHMARK_JOB_COUNT=1000 BENCHMARK_CONCURRENCY=8 ./run_connection_pool.sh
```

```out
[+] up 2/2
 ✔ Network smoke_test_default   Created                                                                                                                                                                                                  0.1s
 ✔ Container smoke_test-redis-1 Started                                                                                                                                                                                                  1.0s

CPU cores visible to the benchmark: 4
Sidekiq server PID: 2047921

[21:40:55] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2047921 2047921   2 3100    2 Rl+  bundle
2047921 2047942   0  0.0    2 Sl+  bundle

[21:40:57] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2047921 2047921   2 30.9   12 Sl+  bundle
2047921 2047942   0  0.0   12 Sl+  bundle
2047921 2048006   2  0.0   12 Sl+  sidekiq.heartbe
2047921 2048007   2  0.0   12 Sl+  sidekiq.schedul
2047921 2048008   0  0.0   12 Sl+  sidekiq.default
2047921 2048009   2  0.0   12 Sl+  sidekiq.default
2047921 2048010   0  0.0   12 Sl+  sidekiq.default
2047921 2048011   3  0.0   12 Sl+  sidekiq.default
2047921 2048012   0  1.1   12 Sl+  sidekiq.default
2047921 2048013   0  0.0   12 Sl+  sidekiq.default
2047921 2048014   3  0.0   12 Sl+  sidekiq.default
2047921 2048015   3  1.1   12 Sl+  sidekiq.default

[21:40:58] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2047921 2047921   2 15.8   12 Sl+  bundle
2047921 2047942   1  0.0   12 Sl+  bundle
2047921 2048006   2  0.0   12 Sl+  sidekiq.heartbe
2047921 2048007   2  0.0   12 Sl+  sidekiq.schedul
2047921 2048008   0  0.9   12 Sl+  sidekiq.default
2047921 2048009   0  1.3   12 Sl+  sidekiq.default
2047921 2048010   2  0.9   12 Sl+  sidekiq.default
2047921 2048011   0  0.9   12 Sl+  sidekiq.default
2047921 2048012   2  0.9   12 Sl+  sidekiq.default
2047921 2048013   0  1.3   12 Sl+  sidekiq.default
2047921 2048014   0  0.9   12 Sl+  sidekiq.default
2047921 2048015   1  1.3   12 Sl+  sidekiq.default

[21:40:59] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2047921 2047921   2 10.7   12 Sl+  bundle
2047921 2047942   2  0.0   12 Sl+  bundle
2047921 2048006   2  0.0   12 Sl+  sidekiq.heartbe
2047921 2048007   2  0.0   12 Sl+  sidekiq.schedul
2047921 2048008   0  1.4   12 Sl+  sidekiq.default
2047921 2048009   2  1.4   12 Sl+  sidekiq.default
2047921 2048010   3  1.1   12 Sl+  sidekiq.default
2047921 2048011   2  1.4   12 Sl+  sidekiq.default
2047921 2048012   0  1.4   12 Sl+  sidekiq.default
2047921 2048013   0  1.4   12 Sl+  sidekiq.default
2047921 2048014   3  1.4   12 Sl+  sidekiq.default
2047921 2048015   3  1.4   12 Sl+  sidekiq.default

[21:41:00] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2047921 2047921   2  8.1   12 Sl+  bundle
2047921 2047942   0  0.0   12 Sl+  bundle
2047921 2048006   2  0.0   12 Sl+  sidekiq.heartbe
2047921 2048007   2  0.0   12 Sl+  sidekiq.schedul
2047921 2048008   3  1.2   12 Sl+  sidekiq.default
2047921 2048009   2  1.4   12 Sl+  sidekiq.default
2047921 2048010   0  1.4   12 Sl+  sidekiq.default
2047921 2048011   2  1.4   12 Sl+  sidekiq.default
2047921 2048012   2  1.4   12 Sl+  sidekiq.default
2047921 2048013   2  1.4   12 Sl+  sidekiq.default
2047921 2048014   0  1.4   12 Sl+  sidekiq.default
2047921 2048015   2  1.4   12 Sl+  sidekiq.default

[21:41:02] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2047921 2047921   2  6.6   12 Sl+  bundle
2047921 2047942   2  0.0   12 Sl+  bundle
2047921 2048006   2  0.0   12 Sl+  sidekiq.heartbe
2047921 2048007   2  0.0   12 Sl+  sidekiq.schedul
2047921 2048008   0  1.3   12 Sl+  sidekiq.default
2047921 2048009   3  1.4   12 Sl+  sidekiq.default
2047921 2048010   0  1.3   12 Sl+  sidekiq.default
2047921 2048011   0  1.4   12 Sl+  sidekiq.default
2047921 2048012   3  1.3   12 Sl+  sidekiq.default
2047921 2048013   0  1.4   12 Sl+  sidekiq.default
2047921 2048014   0  1.4   12 Sl+  sidekiq.default
2047921 2048015   0  1.4   12 Sl+  sidekiq.default

[21:41:03] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2047921 2047921   2  5.5   12 Sl+  bundle
2047921 2047942   3  0.0   12 Sl+  bundle
2047921 2048006   2  0.0   12 Sl+  sidekiq.heartbe
2047921 2048007   2  0.0   12 Sl+  sidekiq.schedul
2047921 2048008   1  1.2   12 Sl+  sidekiq.default
2047921 2048009   1  1.3   12 Sl+  sidekiq.default
2047921 2048010   1  1.3   12 Sl+  sidekiq.default
2047921 2048011   1  1.4   12 Sl+  sidekiq.default
2047921 2048012   1  1.3   12 Sl+  sidekiq.default
2047921 2048013   1  1.2   12 Sl+  sidekiq.default
2047921 2048014   1  1.3   12 Sl+  sidekiq.default
2047921 2048015   1  1.3   12 Sl+  sidekiq.default

[21:41:04] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2047921 2047921   2  4.7   12 Sl+  bundle
2047921 2047942   0  0.0   12 Sl+  bundle
2047921 2048006   2  0.0   12 Sl+  sidekiq.heartbe
2047921 2048007   2  0.0   12 Sl+  sidekiq.schedul
2047921 2048008   3  1.1   12 Sl+  sidekiq.default
2047921 2048009   0  1.2   12 Sl+  sidekiq.default
2047921 2048010   0  1.1   12 Sl+  sidekiq.default
2047921 2048011   3  1.3   12 Sl+  sidekiq.default
2047921 2048012   3  1.2   12 Sl+  sidekiq.default
2047921 2048013   3  1.2   12 Sl+  sidekiq.default
2047921 2048014   3  1.2   12 Sl+  sidekiq.default
2047921 2048015   3  1.3   12 Sl+  sidekiq.default

[21:41:06] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2047921 2047921   2  4.1   12 Sl+  bundle
2047921 2047942   0  0.0   12 Sl+  bundle
2047921 2048006   2  0.0   12 Sl+  sidekiq.heartbe
2047921 2048007   2  0.0   12 Sl+  sidekiq.schedul
2047921 2048008   0  1.1   12 Sl+  sidekiq.default
2047921 2048009   0  1.2   12 Sl+  sidekiq.default
2047921 2048010   0  1.1   12 Sl+  sidekiq.default
2047921 2048011   1  1.2   12 Sl+  sidekiq.default
2047921 2048012   1  1.3   12 Sl+  sidekiq.default
2047921 2048013   0  1.2   12 Sl+  sidekiq.default
2047921 2048014   1  1.2   12 Sl+  sidekiq.default
2047921 2048015   0  1.2   12 Sl+  sidekiq.default

[21:41:07] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2047921 2047921   2  3.6   12 Sl+  bundle
2047921 2047942   3  0.0   12 Sl+  bundle
2047921 2048006   2  0.0   12 Sl+  sidekiq.heartbe
2047921 2048007   2  0.0   12 Sl+  sidekiq.schedul
2047921 2048008   0  1.2   12 Sl+  sidekiq.default
2047921 2048009   3  1.3   12 Sl+  sidekiq.default
2047921 2048010   2  1.3   12 Sl+  sidekiq.default
2047921 2048011   0  1.4   12 Sl+  sidekiq.default
2047921 2048012   0  1.4   12 Sl+  sidekiq.default
2047921 2048013   2  1.3   12 Sl+  sidekiq.default
2047921 2048014   3  1.3   12 Sl+  sidekiq.default
2047921 2048015   0  1.3   12 Sl+  sidekiq.default

[21:41:08] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2047921 2047921   2  3.3   12 Sl+  bundle
2047921 2047942   0  0.0   12 Sl+  bundle
2047921 2048006   2  0.0   12 Sl+  sidekiq.heartbe
2047921 2048007   2  0.0   12 Sl+  sidekiq.schedul
2047921 2048008   2  1.3   12 Sl+  sidekiq.default
2047921 2048009   2  1.4   12 Sl+  sidekiq.default
2047921 2048010   2  1.3   12 Sl+  sidekiq.default
2047921 2048011   2  1.4   12 Sl+  sidekiq.default
2047921 2048012   2  1.4   12 Sl+  sidekiq.default
2047921 2048013   2  1.4   12 Sl+  sidekiq.default
2047921 2048014   2  1.3   12 Sl+  sidekiq.default
2047921 2048015   2  1.3   12 Sl+  sidekiq.default
INFO  2026-08-24T13:40:56.324Z pid=2047923 tid=17vo3: Sidekiq 8.1.7 connecting to Redis with options {size: 10, pool_name: "internal", url: "redis://127.0.0.1:6479/0"}
Benchmark passed: 1000 jobs in 13.308 seconds (75.14 jobs/sec)
[+] down 2/2
 ✔ Container smoke_test-redis-1 Removed                                     0.5s
 ✔ Network smoke_test_default   Removed                                     0.1s
```