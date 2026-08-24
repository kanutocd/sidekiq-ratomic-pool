```sh
❯ RACTOR_NATIVE_COUNT=4 \
RACTOR_NATIVE_THREADS=20 \
RATOMIC_POOL_SIZE=20 \
BENCHMARK_WORK_SECONDS=0.05 \
BENCHMARK_JOB_COUNT=20000 \
./run_ractor_native.sh > run-ractor-native-out.md
```

```output
[+] up 2/2
 ✔ Network smoke_test_default   Created                                     0.1s
 ✔ Container smoke_test-redis-1 Started                                     1.6s


CPU cores visible to the benchmark: 4
Ractor benchmark PID: 2191374
Ractors: 4, threads per Ractor: 20, pool size per Ractor: 20

[22:43:26] Ractor benchmark process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2191374 2191374   1  0.0    2 Rl+  ruby
2191374 2191389   2  0.0    2 Sl+  ruby

[22:43:27] Ractor benchmark process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2191374 2191374   2 35.8   13 Sl+  ruby
2191374 2191389   0  0.0   13 Sl+  ruby
2191374 2191391   2  3.7   13 Sl+  ractor_native.*
2191374 2191392   2  4.9   13 Sl+  ractor_native.*
2191374 2191393   2  3.7   13 Sl+  ractor_native.*
2191374 2191394   2  3.7   13 Sl+  ractor_native.*
2191374 2191396   0  3.7   13 Sl+  ractor_native.*
2191374 2191398   2  3.7   13 Rl+  ractor_native.*
2191374 2191399   0  3.8   13 Sl+  ruby
2191374 2191400   0  3.0   13 Sl+  ruby
2191374 2191401   2  3.3   13 Sl+  ruby
2191374 2191421   0  3.7   13 Sl+  ruby
2191374 2191423   0  3.9   13 Sl+  ruby

[22:43:28] Ractor benchmark process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2191374 2191374   2 17.9   16 Sl+  ruby
2191374 2191389   1  1.2   16 Sl+  ruby
2191374 2191391   0  3.3   16 Sl+  ractor_native.*
2191374 2191392   1  3.7   16 Sl+  ractor_native.*
2191374 2191393   1  3.7   16 Sl+  ractor_native.*
2191374 2191394   0  3.3   16 Sl+  ractor_native.*
2191374 2191396   1  3.3   16 Sl+  ractor_native.*
2191374 2191398   3  3.3   16 Sl+  ractor_native.*
2191374 2191399   0  3.3   16 Sl+  ruby
2191374 2191400   0  3.0   16 Sl+  ruby
2191374 2191401   0  3.1   16 Sl+  ruby
2191374 2191421   3  3.2   16 Sl+  ruby
2191374 2191423   1  3.8   16 Sl+  ruby
2191374 2191449   1  3.2   16 Sl+  ruby
2191374 2191450   1  1.6   16 Sl+  ruby
2191374 2191456   0 12.5   16 Sl+  ruby

[22:43:30] Ractor benchmark process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2191374 2191374   2 11.8   25 Sl+  ruby
2191374 2191389   2  1.8   25 Sl+  ruby
2191374 2191391   3  3.7   25 Sl+  ractor_native.*
2191374 2191392   0  4.0   25 Sl+  ractor_native.*
2191374 2191393   3  4.0   25 Sl+  ractor_native.*
2191374 2191394   2  4.0   25 Sl+  ractor_native.*
2191374 2191396   0  3.7   25 Sl+  ractor_native.*
2191374 2191398   0  3.7   25 Sl+  ractor_native.*
2191374 2191399   2  3.7   25 Sl+  ruby
2191374 2191400   2  3.3   25 Sl+  ruby
2191374 2191401   2  3.6   25 Sl+  ruby
2191374 2191421   0  3.7   25 Sl+  ruby
2191374 2191423   2  3.7   25 Sl+  ruby
2191374 2191449   2  4.0   25 Sl+  ruby
2191374 2191450   3  4.0   25 Sl+  ruby
2191374 2191456   0  4.1   25 Sl+  ruby
2191374 2191511   0  3.9   25 Sl+  ruby
2191374 2191519   2  3.3   25 Sl+  ruby
2191374 2191520   3  0.0   25 Sl+  ruby
2191374 2191529   0  0.0   25 Sl+  ruby
2191374 2191530   0  0.0   25 Sl+  ruby
2191374 2191535   2  0.0   25 Sl+  ruby
2191374 2191538   2  0.0   25 Sl+  ruby
2191374 2191540   0  0.0   25 Sl+  ruby
2191374 2191548   3  0.0   25 Sl+  ruby

[22:43:31] Ractor benchmark process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2191374 2191374   2  8.8   27 Sl+  ruby
2191374 2191389   3  2.3   27 Sl+  ruby
2191374 2191391   2  3.5   27 Rl+  ractor_native.*
2191374 2191392   2  3.7   27 Sl+  ractor_native.*
2191374 2191393   1  3.5   27 Sl+  ractor_native.*
2191374 2191394   3  3.3   27 Sl+  ractor_native.*
2191374 2191396   3  3.5   27 Sl+  ractor_native.*
2191374 2191398   1  3.3   27 Sl+  ractor_native.*
2191374 2191399   3  3.5   27 Sl+  ruby
2191374 2191400   1  3.4   27 Sl+  ruby
2191374 2191401   1  3.2   27 Sl+  ruby
2191374 2191421   2  3.5   27 Sl+  ruby
2191374 2191423   3  3.3   27 Sl+  ruby
2191374 2191449   1  3.6   27 Sl+  ruby
2191374 2191450   1  3.3   27 Sl+  ruby
2191374 2191456   3  3.6   27 Sl+  ruby
2191374 2191511   3  3.3   27 Sl+  ruby
2191374 2191519   1  3.6   27 Sl+  ruby
2191374 2191520   3  2.8   27 Sl+  ruby
2191374 2191529   3  2.2   27 Sl+  ruby
2191374 2191530   2  2.2   27 Sl+  ruby
2191374 2191535   3  2.2   27 Sl+  ruby
2191374 2191538   3  2.9   27 Sl+  ruby
2191374 2191540   1  2.9   27 Sl+  ruby
2191374 2191548   2  3.0   27 Sl+  ruby
2191374 2191617   2  2.5   27 Sl+  ruby
2191374 2191646   1  0.0   27 Sl+  ruby

[22:43:32] Ractor benchmark process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2191374 2191374   2  7.0   30 Sl+  ruby
2191374 2191389   3  2.4   30 Sl+  ruby
2191374 2191391   1  3.4   30 Sl+  ractor_native.*
2191374 2191392   0  3.5   30 Sl+  ractor_native.*
2191374 2191393   0  3.4   30 Sl+  ractor_native.*
2191374 2191394   0  3.2   30 Sl+  ractor_native.*
2191374 2191396   1  3.4   30 Sl+  ractor_native.*
2191374 2191398   3  3.2   30 Sl+  ractor_native.*
2191374 2191399   1  3.2   30 Sl+  ruby
2191374 2191400   0  3.0   30 Sl+  ruby
2191374 2191401   0  3.2   30 Sl+  ruby
2191374 2191421   3  3.2   30 Sl+  ruby
2191374 2191423   1  3.2   30 Sl+  ruby
2191374 2191449   3  3.4   30 Sl+  ruby
2191374 2191450   1  3.2   30 Sl+  ruby
2191374 2191456   1  3.4   30 Sl+  ruby
2191374 2191511   0  2.9   30 Sl+  ruby
2191374 2191519   1  3.0   30 Sl+  ruby
2191374 2191520   0  2.9   30 Sl+  ruby
2191374 2191529   1  2.2   30 Sl+  ruby
2191374 2191530   1  2.2   30 Sl+  ruby
2191374 2191535   0  2.2   30 Sl+  ruby
2191374 2191538   1  2.6   30 Sl+  ruby
2191374 2191540   3  2.9   30 Sl+  ruby
2191374 2191548   1  2.6   30 Sl+  ruby
2191374 2191617   3  2.8   30 Sl+  ruby
2191374 2191646   1  1.9   30 Sl+  ruby
2191374 2191668   1  2.1   30 Sl+  ruby
2191374 2191669   3  2.1   30 Sl+  ruby
2191374 2191689   3  0.0   30 Sl+  ruby

[22:43:34] Ractor benchmark process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2191374 2191374   2  5.9   31 Sl+  ruby
2191374 2191389   0  2.5   31 Rl+  ruby
2191374 2191391   1  3.2   31 Sl+  ractor_native.*
2191374 2191392   0  3.2   31 Sl+  ractor_native.*
2191374 2191393   0  3.0   31 Rl+  ractor_native.*
2191374 2191394   1  3.0   31 Sl+  ractor_native.*
2191374 2191396   0  3.0   31 Sl+  ractor_native.*
2191374 2191398   0  3.1   31 Rl+  ractor_native.*
2191374 2191399   0  3.1   31 Rl+  ruby
2191374 2191400   2  2.8   31 Sl+  ruby
2191374 2191401   1  2.9   31 Sl+  ruby
2191374 2191421   2  2.9   31 Sl+  ruby
2191374 2191423   1  2.9   31 Sl+  ruby
2191374 2191449   0  3.0   31 Rl+  ruby
2191374 2191450   2  3.0   31 Sl+  ruby
2191374 2191456   1  2.9   31 Sl+  ruby
2191374 2191511   2  2.5   31 Sl+  ruby
2191374 2191519   0  2.8   31 Sl+  ruby
2191374 2191520   0  2.4   31 Sl+  ruby
2191374 2191529   1  2.0   31 Sl+  ruby
2191374 2191530   2  2.2   31 Sl+  ruby
2191374 2191535   2  2.0   31 Sl+  ruby
2191374 2191538   0  2.2   31 Sl+  ruby
2191374 2191540   2  2.5   31 Sl+  ruby
2191374 2191548   2  2.2   31 Sl+  ruby
2191374 2191617   2  2.3   31 Sl+  ruby
2191374 2191646   2  2.0   31 Sl+  ruby
2191374 2191668   0  2.2   31 Rl+  ruby
2191374 2191669   0  2.7   31 Sl+  ruby
2191374 2191689   2  2.2   31 Sl+  ruby
2191374 2191710   0  0.0   31 Sl+  ruby

[22:43:35] Ractor benchmark process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2191374 2191374   2  5.0   31 Sl+  ruby
2191374 2191389   0  2.4   31 Sl+  ruby
2191374 2191391   2  2.8   31 Sl+  ractor_native.*
2191374 2191392   2  2.8   31 Sl+  ractor_native.*
2191374 2191393   2  2.9   31 Sl+  ractor_native.*
2191374 2191394   0  2.7   31 Sl+  ractor_native.*
2191374 2191396   2  2.8   31 Sl+  ractor_native.*
2191374 2191398   2  2.8   31 Sl+  ractor_native.*
2191374 2191399   2  2.7   31 Sl+  ruby
2191374 2191400   0  2.5   31 Sl+  ruby
2191374 2191401   2  2.6   31 Sl+  ruby
2191374 2191421   2  2.7   31 Sl+  ruby
2191374 2191423   2  2.7   31 Sl+  ruby
2191374 2191449   0  2.7   31 Sl+  ruby
2191374 2191450   2  2.6   31 Sl+  ruby
2191374 2191456   0  2.5   31 Sl+  ruby
2191374 2191511   2  2.3   31 Sl+  ruby
2191374 2191519   2  2.3   31 Sl+  ruby
2191374 2191520   2  2.2   31 Sl+  ruby
2191374 2191529   2  1.8   31 Sl+  ruby
2191374 2191530   0  2.0   31 Sl+  ruby
2191374 2191535   0  1.8   31 Sl+  ruby
2191374 2191538   2  2.0   31 Sl+  ruby
2191374 2191540   2  2.2   31 Sl+  ruby
2191374 2191548   3  2.0   31 Sl+  ruby
2191374 2191617   2  2.1   31 Sl+  ruby
2191374 2191646   2  1.9   31 Sl+  ruby
2191374 2191668   0  1.9   31 Sl+  ruby
2191374 2191669   2  1.6   31 Sl+  ruby
2191374 2191689   2  1.6   31 Rl+  ruby
2191374 2191710   0  1.0   31 Sl+  ruby

[22:43:36] Ractor benchmark process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2191374 2191374   2  4.4   36 Sl+  ruby
2191374 2191389   0  2.5   36 Sl+  ruby
2191374 2191391   0  2.6   36 Sl+  ractor_native.*
2191374 2191392   0  2.6   36 Sl+  ractor_native.*
2191374 2191393   0  2.7   36 Sl+  ractor_native.*
2191374 2191394   0  2.5   36 Sl+  ractor_native.*
2191374 2191396   0  2.6   36 Sl+  ractor_native.*
2191374 2191398   0  2.6   36 Sl+  ractor_native.*
2191374 2191399   2  2.5   36 Sl+  ruby
2191374 2191400   0  2.4   36 Sl+  ruby
2191374 2191401   0  2.5   36 Sl+  ruby
2191374 2191421   0  2.5   36 Sl+  ruby
2191374 2191423   0  2.5   36 Sl+  ruby
2191374 2191449   0  2.5   36 Sl+  ruby
2191374 2191450   0  2.4   36 Sl+  ruby
2191374 2191456   0  2.3   36 Rl+  ruby
2191374 2191511   0  2.1   36 Sl+  ruby
2191374 2191519   0  2.2   36 Sl+  ruby
2191374 2191520   0  2.0   36 Sl+  ruby
2191374 2191529   0  1.8   36 Sl+  ruby
2191374 2191530   0  1.8   36 Sl+  ruby
2191374 2191535   0  1.9   36 Rl+  ruby
2191374 2191538   0  1.9   36 Rl+  ruby
2191374 2191540   0  2.1   36 Sl+  ruby
2191374 2191548   0  1.8   36 Sl+  ruby
2191374 2191617   0  1.9   36 Rl+  ruby
2191374 2191646   0  1.8   36 Sl+  ruby
2191374 2191668   2  1.6   36 Sl+  ruby
2191374 2191669   0  1.8   36 Sl+  ruby
2191374 2191689   0  1.5   36 Sl+  ruby
2191374 2191710   0  1.2   36 Sl+  ruby
2191374 2191866   0  0.0   36 Sl+  ruby
2191374 2191926   2  0.0   36 Sl+  ruby
2191374 2191927   0  0.0   36 Sl+  ruby
2191374 2191928   2  0.0   36 Sl+  ruby
2191374 2191929   0  0.0   36 Sl+  ruby

[22:43:37] Ractor benchmark process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2191374 2191374   2  3.9   36 Sl+  ruby
2191374 2191389   1  2.4   36 Sl+  ruby
2191374 2191391   1  2.6   36 Rl+  ractor_native.*
2191374 2191392   3  2.6   36 Sl+  ractor_native.*
2191374 2191393   1  2.6   36 Sl+  ractor_native.*
2191374 2191394   3  2.5   36 Sl+  ractor_native.*
2191374 2191396   3  2.5   36 Sl+  ractor_native.*
2191374 2191398   3  2.5   36 Rl+  ractor_native.*
2191374 2191399   3  2.4   36 Sl+  ruby
2191374 2191400   2  2.4   36 Sl+  ruby
2191374 2191401   2  2.4   36 Sl+  ruby
2191374 2191421   1  2.4   36 Sl+  ruby
2191374 2191423   2  2.4   36 Sl+  ruby
2191374 2191449   3  2.4   36 Sl+  ruby
2191374 2191450   1  2.4   36 Sl+  ruby
2191374 2191456   1  2.3   36 Sl+  ruby
2191374 2191511   3  2.0   36 Sl+  ruby
2191374 2191519   2  2.1   36 Sl+  ruby
2191374 2191520   1  2.0   36 Sl+  ruby
2191374 2191529   2  1.7   36 Sl+  ruby
2191374 2191530   2  1.8   36 Sl+  ruby
2191374 2191535   3  1.8   36 Sl+  ruby
2191374 2191538   3  1.8   36 Sl+  ruby
2191374 2191540   2  2.1   36 Sl+  ruby
2191374 2191548   2  1.8   36 Sl+  ruby
2191374 2191617   3  1.8   36 Sl+  ruby
2191374 2191646   3  1.7   36 Sl+  ruby
2191374 2191668   1  1.6   36 Sl+  ruby
2191374 2191669   2  1.7   36 Sl+  ruby
2191374 2191689   2  1.4   36 Sl+  ruby
2191374 2191710   2  1.5   36 Sl+  ruby
2191374 2191866   1  1.1   36 Sl+  ruby
2191374 2191926   1  0.7   36 Sl+  ruby
2191374 2191927   2  1.5   36 Sl+  ruby
2191374 2191928   2  1.5   36 Sl+  ruby
2191374 2191929   1  0.7   36 Sl+  ruby

[22:43:39] Ractor benchmark process/thread snapshot
    PID     TID PSR %CPU NLWP STAT COMMAND
2191374 2191374   2  3.5   36 Sl+  ruby
2191374 2191389   0  2.5   36 Sl+  ruby
2191374 2191391   2  2.5   36 Sl+  ractor_native.*
2191374 2191392   2  2.5   36 Sl+  ractor_native.*
2191374 2191393   0  2.5   36 Sl+  ractor_native.*
2191374 2191394   0  2.4   36 Sl+  ractor_native.*
2191374 2191396   3  2.4   36 Sl+  ractor_native.*
2191374 2191398   3  2.5   36 Sl+  ractor_native.*
2191374 2191399   0  2.4   36 Sl+  ruby
2191374 2191400   0  2.3   36 Sl+  ruby
2191374 2191401   3  2.4   36 Sl+  ruby
2191374 2191421   0  2.4   36 Sl+  ruby
2191374 2191423   3  2.4   36 Sl+  ruby
2191374 2191449   3  2.4   36 Sl+  ruby
2191374 2191450   0  2.3   36 Sl+  ruby
2191374 2191456   3  2.2   36 Sl+  ruby
2191374 2191511   3  2.1   36 Sl+  ruby
2191374 2191519   0  2.1   36 Sl+  ruby
2191374 2191520   3  2.0   36 Sl+  ruby
2191374 2191529   2  1.9   36 Sl+  ruby
2191374 2191530   0  1.8   36 Sl+  ruby
2191374 2191535   0  1.8   36 Sl+  ruby
2191374 2191538   0  1.8   36 Sl+  ruby
2191374 2191540   2  2.1   36 Sl+  ruby
2191374 2191548   3  1.9   36 Sl+  ruby
2191374 2191617   3  1.9   36 Sl+  ruby
2191374 2191646   3  1.8   36 Sl+  ruby
2191374 2191668   0  1.8   36 Sl+  ruby
2191374 2191669   2  1.8   36 Sl+  ruby
2191374 2191689   0  1.7   36 Sl+  ruby
2191374 2191710   3  1.6   36 Sl+  ruby
2191374 2191866   3  1.6   36 Sl+  ruby
2191374 2191926   3  1.5   36 Sl+  ruby
2191374 2191927   2  1.5   36 Sl+  ruby
2191374 2191928   3  1.5   36 Sl+  ruby
2191374 2191929   3  1.5   36 Sl+  ruby
./benchmark/ractor_native.rb:41: warning: Ractor API is experimental and may change in future versions of Ruby.
Ractor benchmark passed: 4 Ractors × 20 resources × 20 threads, 20000 jobs in 13.751 seconds (1454.49 jobs/sec)

[+] down 2/2
 ✔ Container smoke_test-redis-1 Removed                                     0.4s
 ✔ Network smoke_test_default   Removed                                     0.1s
```