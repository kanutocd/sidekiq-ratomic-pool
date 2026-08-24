# frozen_string_literal: true

require 'sidekiq'
require 'redis-client'
require_relative 'worker'

redis_url = ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6379/0').freeze
job_count = Integer(ENV.fetch('BENCHMARK_JOB_COUNT', '100'))
timeout = Integer(ENV.fetch('BENCHMARK_TIMEOUT', '120'))
run_id = ENV.fetch('BENCHMARK_RUN_ID', Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond).to_s)
redis = RedisClient.config(url: redis_url).new_client
Sidekiq.configure_client { |config| config.redis = { url: redis_url } }

redis.call('DEL', SmokeBenchmark::COUNT_KEY, SmokeBenchmark::RESULTS_KEY)
started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
job_ids = job_count.times.map do |index|
  job_id = "#{run_id}-#{index}"
  Sidekiq::Client.push('class' => SmokeBenchmark::RedisBenchmarkWorker, 'args' => [job_id], 'queue' => 'benchmark')
  job_id
end

deadline = started_at + timeout
loop do
  processed = Integer(redis.call('GET', SmokeBenchmark::COUNT_KEY) || 0)
  results = Integer(redis.call('HLEN', SmokeBenchmark::RESULTS_KEY) || 0)
  break if processed >= job_count && results >= job_count

  if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    abort "Timed out waiting for #{job_count} jobs (processed=#{processed}, results=#{results})"
  end

  sleep 0.1
end

elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
missing = job_ids.reject { |job_id| redis.call('HGET', SmokeBenchmark::RESULTS_KEY, job_id) == 'processed' }
abort "Missing processed jobs: #{missing.join(', ')}" unless missing.empty?

puts format('Benchmark passed: %<jobs>d jobs in %<seconds>.3f seconds (%<rate>.2f jobs/sec)',
            jobs: job_count, seconds: elapsed, rate: job_count / elapsed)
