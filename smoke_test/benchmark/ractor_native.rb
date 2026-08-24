# frozen_string_literal: true

require 'ratomic'
require 'redis-client'

RedisFactory = Data.define(:url) do
  def call
    RedisClient.config(url:).new_client
  end
end
RactorInput = Data.define(:pool, :jobs, :threads, :work_seconds, :count_key, :results_key, :run_id, :index)

ractor_count = Integer(ENV.fetch('RACTOR_NATIVE_COUNT', '4'))
threads_per_ractor = Integer(ENV.fetch('RACTOR_NATIVE_THREADS', '20'))
pool_size = Integer(ENV.fetch('RATOMIC_POOL_SIZE', '20'))
pool_timeout = Float(ENV.fetch('RATOMIC_POOL_TIMEOUT', '10'))
work_seconds = Float(ENV.fetch('BENCHMARK_WORK_SECONDS', '0.1'))
job_count = Integer(ENV.fetch('BENCHMARK_JOB_COUNT', (ractor_count * threads_per_ractor).to_s))

redis_url = ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6379/0').freeze
run_id = ENV.fetch('BENCHMARK_RUN_ID', Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond).to_s).freeze
count_key = "sidekiq-ratomic-pool:ractor-benchmark:#{run_id}:processed".freeze
results_key = "sidekiq-ratomic-pool:ractor-benchmark:#{run_id}:results".freeze
redis = RedisClient.config(url: redis_url).new_client
redis.call('DEL', count_key, results_key)

factory = Ractor.make_shareable(RedisFactory.new(redis_url))
pool = Ratomic::LocalPool.new(size: pool_size, timeout: pool_timeout, factory:)
jobs_per_ractor = job_count / ractor_count
unless jobs_per_ractor * ractor_count == job_count
  raise ArgumentError, 'BENCHMARK_JOB_COUNT must divide evenly across Ractors'
end

started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
ractors = ractor_count.times.map do |ractor_index| # rubocop:disable Metrics/BlockLength
  input = Ractor.make_shareable(
    RactorInput.new(
      pool, jobs_per_ractor, threads_per_ractor, work_seconds, count_key, results_key, run_id, ractor_index
    )
  )
  Ractor.new(input) do |ractor_input| # rubocop:disable Metrics/BlockLength
    local_pool = ractor_input.pool
    local_jobs = ractor_input.jobs
    local_thread_count = ractor_input.threads
    local_work_seconds = ractor_input.work_seconds
    processed_key = ractor_input.count_key
    result_key = ractor_input.results_key
    benchmark_run_id = ractor_input.run_id
    index = ractor_input.index
    jobs = Queue.new
    local_jobs.times { |job_index| jobs << job_index }
    threads = local_thread_count.times.map do
      Thread.new do
        loop do
          job_index = begin
            jobs.pop(true)
          rescue ThreadError
            break
          end
          job_id = "#{benchmark_run_id}-#{index}-#{job_index}"
          local_pool.with do |redis_client|
            raise 'Redis health check failed' unless redis_client.call('PING') == 'PONG'

            redis_client.call('INCR', processed_key)
            redis_client.call('HSET', result_key, job_id, 'processed')
            sleep local_work_seconds if local_work_seconds.positive?
          end
        end
      end
    end
    threads.each(&:value)
    local_pool.close
    [local_thread_count, local_jobs]
  end
end

ractor_results = ractors.map(&:value)
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
processed = Integer(redis.call('GET', count_key) || 0)
results = Integer(redis.call('HLEN', results_key) || 0)
abort "Benchmark mismatch (processed=#{processed}, results=#{results}, expected=#{job_count})" unless
  processed == job_count && results == job_count

puts format(
  'Ractor benchmark passed: %<ractors>d Ractors × %<pool>d resources × %<threads>d threads, ' \
  '%<jobs>d jobs in %<seconds>.3f seconds (%<rate>.2f jobs/sec)',
  ractors: ractor_results.size, pool: pool_size, threads: threads_per_ractor, jobs: job_count,
  seconds: elapsed, rate: job_count / elapsed
)
