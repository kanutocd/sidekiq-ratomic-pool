```sh
BENCHMARK_JOB_COUNT=1000 BENCHMARK_CONCURRENCY=8 ./run.sh
```

```out
[+] up 2/2
 ✔ Network smoke_test_default   Created                                                                                                                                                                                                  0.1s
 ✔ Container smoke_test-redis-1 Started                                                                                                                                                                                                  0.6s

CPU cores visible to the benchmark: 4
Sidekiq server PID: 2042500

[21:38:34] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2042500 2042500   1 2500    2 Rl+  bundle
2042500 2042521   3  0.0    2 Sl+  bundle

[21:38:35] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2042500 2042500   1 31.7   12 Sl+  bundle
2042500 2042521   0  0.0   12 Sl+  bundle
2042500 2042526   3  0.0   12 Sl+  sidekiq.heartbe
2042500 2042527   0  0.0   12 Sl+  sidekiq.schedul
2042500 2042528   2  0.0   12 Sl+  sidekiq.default
2042500 2042529   0  1.1   12 Sl+  sidekiq.default
2042500 2042530   0  0.0   12 Sl+  sidekiq.default
2042500 2042531   0  0.0   12 Sl+  sidekiq.default
2042500 2042532   0  0.0   12 Sl+  sidekiq.default
2042500 2042533   3  0.0   12 Sl+  sidekiq.default
2042500 2042534   0  0.0   12 Sl+  sidekiq.default
2042500 2042535   2  0.0   12 Sl+  sidekiq.default

[21:38:36] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2042500 2042500   1 15.8   12 Sl+  bundle
2042500 2042521   0  0.0   12 Sl+  bundle
2042500 2042526   3  0.0   12 Sl+  sidekiq.heartbe
2042500 2042527   0  0.0   12 Sl+  sidekiq.schedul
2042500 2042528   0  0.9   12 Sl+  sidekiq.default
2042500 2042529   3  0.4   12 Sl+  sidekiq.default
2042500 2042530   3  0.9   12 Sl+  sidekiq.default
2042500 2042531   3  0.4   12 Sl+  sidekiq.default
2042500 2042532   0  0.9   12 Sl+  sidekiq.default
2042500 2042533   0  0.4   12 Sl+  sidekiq.default
2042500 2042534   0  0.9   12 Sl+  sidekiq.default
2042500 2042535   0  0.4   12 Sl+  sidekiq.default

[21:38:38] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2042500 2042500   1 10.5   12 Sl+  bundle
2042500 2042521   2  0.0   12 Sl+  bundle
2042500 2042526   3  0.0   12 Sl+  sidekiq.heartbe
2042500 2042527   0  0.0   12 Sl+  sidekiq.schedul
2042500 2042528   3  0.8   12 Sl+  sidekiq.default
2042500 2042529   1  0.5   12 Sl+  sidekiq.default
2042500 2042530   1  0.5   12 Sl+  sidekiq.default
2042500 2042531   1  0.8   12 Sl+  sidekiq.default
2042500 2042532   1  0.5   12 Sl+  sidekiq.default
2042500 2042533   1  0.5   12 Sl+  sidekiq.default
2042500 2042534   1  0.8   12 Sl+  sidekiq.default
2042500 2042535   3  0.5   12 Sl+  sidekiq.default

[21:38:39] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2042500 2042500   1  7.8   12 Sl+  bundle
2042500 2042521   1  0.0   12 Sl+  bundle
2042500 2042526   3  0.0   12 Sl+  sidekiq.heartbe
2042500 2042527   0  0.0   12 Sl+  sidekiq.schedul
2042500 2042528   1  0.8   12 Sl+  sidekiq.default
2042500 2042529   1  0.8   12 Sl+  sidekiq.default
2042500 2042530   2  0.6   12 Sl+  sidekiq.default
2042500 2042531   2  0.8   12 Sl+  sidekiq.default
2042500 2042532   0  1.0   12 Sl+  sidekiq.default
2042500 2042533   1  0.8   12 Sl+  sidekiq.default
2042500 2042534   0  0.8   12 Sl+  sidekiq.default
2042500 2042535   0  0.8   12 Sl+  sidekiq.default

[21:38:40] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2042500 2042500   1  6.2   12 Sl+  bundle
2042500 2042521   2  0.0   12 Sl+  bundle
2042500 2042526   3  0.0   12 Sl+  sidekiq.heartbe
2042500 2042527   0  0.0   12 Sl+  sidekiq.schedul
2042500 2042528   3  0.9   12 Sl+  sidekiq.default
2042500 2042529   3  0.9   12 Rl+  sidekiq.default
2042500 2042530   0  0.9   12 Sl+  sidekiq.default
2042500 2042531   0  0.9   12 Sl+  sidekiq.default
2042500 2042532   3  0.9   12 Sl+  sidekiq.default
2042500 2042533   3  0.9   12 Sl+  sidekiq.default
2042500 2042534   2  0.9   12 Sl+  sidekiq.default
2042500 2042535   2  0.9   12 Sl+  sidekiq.default

[21:38:42] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2042500 2042500   1  5.2   12 Sl+  bundle
2042500 2042521   3  0.0   12 Sl+  bundle
2042500 2042526   3  0.0   12 Sl+  sidekiq.heartbe
2042500 2042527   0  0.0   12 Sl+  sidekiq.schedul
2042500 2042528   0  1.2   12 Sl+  sidekiq.default
2042500 2042529   3  1.0   12 Sl+  sidekiq.default
2042500 2042530   3  1.0   12 Sl+  sidekiq.default
2042500 2042531   2  0.9   12 Sl+  sidekiq.default
2042500 2042532   3  1.0   12 Sl+  sidekiq.default
2042500 2042533   3  1.0   12 Sl+  sidekiq.default
2042500 2042534   2  1.2   12 Sl+  sidekiq.default
2042500 2042535   2  0.9   12 Sl+  sidekiq.default

[21:38:43] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2042500 2042500   1  4.4   12 Sl+  bundle
2042500 2042521   0  0.0   12 Sl+  bundle
2042500 2042526   3  0.0   12 Sl+  sidekiq.heartbe
2042500 2042527   0  0.0   12 Sl+  sidekiq.schedul
2042500 2042528   2  1.2   12 Sl+  sidekiq.default
2042500 2042529   1  1.1   12 Sl+  sidekiq.default
2042500 2042530   1  1.1   12 Sl+  sidekiq.default
2042500 2042531   0  1.1   12 Sl+  sidekiq.default
2042500 2042532   0  1.2   12 Sl+  sidekiq.default
2042500 2042533   0  1.1   12 Sl+  sidekiq.default
2042500 2042534   2  1.1   12 Sl+  sidekiq.default
2042500 2042535   2  1.1   12 Sl+  sidekiq.default

[21:38:44] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2042500 2042500   1  3.8   12 Sl+  bundle
2042500 2042521   3  0.0   12 Sl+  bundle
2042500 2042526   3  0.0   12 Sl+  sidekiq.heartbe
2042500 2042527   0  0.0   12 Sl+  sidekiq.schedul
2042500 2042528   3  1.1   12 Sl+  sidekiq.default
2042500 2042529   3  1.1   12 Sl+  sidekiq.default
2042500 2042530   3  1.1   12 Sl+  sidekiq.default
2042500 2042531   3  1.0   12 Sl+  sidekiq.default
2042500 2042532   3  1.1   12 Sl+  sidekiq.default
2042500 2042533   0  1.1   12 Sl+  sidekiq.default
2042500 2042534   3  1.1   12 Sl+  sidekiq.default
2042500 2042535   3  1.0   12 Sl+  sidekiq.default

[21:38:46] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2042500 2042500   1  3.4   12 Sl+  bundle
2042500 2042521   0  0.0   12 Sl+  bundle
2042500 2042526   3  0.0   12 Sl+  sidekiq.heartbe
2042500 2042527   0  0.0   12 Sl+  sidekiq.schedul
2042500 2042528   0  1.1   12 Sl+  sidekiq.default
2042500 2042529   3  1.0   12 Sl+  sidekiq.default
2042500 2042530   3  1.1   12 Sl+  sidekiq.default
2042500 2042531   3  1.0   12 Sl+  sidekiq.default
2042500 2042532   3  1.1   12 Sl+  sidekiq.default
2042500 2042533   3  1.1   12 Sl+  sidekiq.default
2042500 2042534   0  1.1   12 Sl+  sidekiq.default
2042500 2042535   0  1.0   12 Sl+  sidekiq.default

[21:38:47] Sidekiq process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2042500 2042500   1  3.1   12 Sl+  bundle
2042500 2042521   2  0.0   12 Sl+  bundle
2042500 2042526   3  0.0   12 Sl+  sidekiq.heartbe
2042500 2042527   0  0.0   12 Sl+  sidekiq.schedul
2042500 2042528   1  1.1   12 Sl+  sidekiq.default
2042500 2042529   3  1.1   12 Sl+  sidekiq.default
2042500 2042530   1  1.1   12 Sl+  sidekiq.default
2042500 2042531   3  1.1   12 Sl+  sidekiq.default
2042500 2042532   1  1.1   12 Sl+  sidekiq.default
2042500 2042533   3  1.1   12 Sl+  sidekiq.default
2042500 2042534   2  1.1   12 Sl+  sidekiq.default
2042500 2042535   3  1.1   12 Sl+  sidekiq.default
INFO  2026-08-24T13:38:34.731Z pid=2042502 tid=17rja: Sidekiq 8.1.7 connecting to Redis with options {size: 10, pool_name: "internal", url: "redis://127.0.0.1:6479/0"}
Benchmark passed: 1000 jobs in 13.301 seconds (75.18 jobs/sec)
[+] down 2/2
 ✔ Container smoke_test-redis-1 Removed                                     0.5s
 ✔ Network smoke_test_default   Removed                                     0.2s
```