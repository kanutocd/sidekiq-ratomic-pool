# frozen_string_literal: true

# Host-owned Ractor integration example using real Redis. The host creates and
# joins Ractors; each Ractor constructs its own middleware runtime and owns its
# Redis connection pool.

require 'etc'
require 'redis-client'
require 'sidekiq'
require 'sidekiq/ratomic/pool'

RedisResource = Data.define(:ractor_index, :client) do
  def call(...)
    client.call(...)
  end
end
RedisFactory = Data.define(:ractor_index, :url) do
  def call
    RedisResource.new(ractor_index, RedisClient.config(url:).new_client)
  end
end
HostInput = Data.define(
  :index, :threads, :jobs, :pool_size, :pool_timeout, :queue_capacity, :work_seconds,
  :redis_url, :count_key, :results_key, :run_id
)

ractor_count = Integer(ENV.fetch('RACTOR_NATIVE_COUNT', Etc.nprocessors.to_s))
threads_per_ractor = Integer(ENV.fetch('RACTOR_NATIVE_THREADS', '20'))
pool_size = Integer(ENV.fetch('RATOMIC_POOL_SIZE', '20'))
pool_timeout = Float(ENV.fetch('RATOMIC_POOL_TIMEOUT', '1'))
queue_capacity = Integer(ENV.fetch('RACTOR_QUEUE_CAPACITY', (threads_per_ractor * 2).to_s))
jobs_per_ractor = Integer(ENV.fetch('BENCHMARK_JOBS_PER_RACTOR', threads_per_ractor.to_s))
work_seconds = Float(ENV.fetch('BENCHMARK_WORK_SECONDS', '0.05'))
redis_url = ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6380/0').freeze
run_id = ENV.fetch('BENCHMARK_RUN_ID', Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond).to_s).freeze
count_key = "sidekiq-ratomic-pool:host-ractor-benchmark:#{run_id}:processed".freeze
results_key = "sidekiq-ratomic-pool:host-ractor-benchmark:#{run_id}:results".freeze

configuration = [
  [ractor_count, 'RACTOR_NATIVE_COUNT'],
  [threads_per_ractor, 'RACTOR_NATIVE_THREADS'],
  [pool_size, 'RATOMIC_POOL_SIZE'],
  [queue_capacity, 'RACTOR_QUEUE_CAPACITY'],
  [jobs_per_ractor, 'BENCHMARK_JOBS_PER_RACTOR']
]
configuration.each do |value, name|
  raise ArgumentError, "#{name} must be positive" unless value.positive?
end
raise ArgumentError, 'RATOMIC_POOL_TIMEOUT must be non-negative' if pool_timeout.negative?
raise ArgumentError, 'BENCHMARK_WORK_SECONDS must be non-negative' if work_seconds.negative?

redis = RedisClient.config(url: redis_url).new_client
redis.call('DEL', count_key, results_key)
redis_info = redis.call('INFO', 'server')
redis_version = redis_info.lines.filter_map do |line|
  line.split(':', 2).last&.strip if line.start_with?('redis_version:')
end.first || 'unknown'

puts "Ruby: #{RUBY_DESCRIPTION}"
puts "Sidekiq: #{Sidekiq::VERSION}"
puts "Ratomic: #{Ratomic::VERSION}"
puts "Redis: #{redis_version}"
puts "Run ID: #{run_id}"
puts "CPU cores visible to the benchmark: #{Etc.nprocessors}"
puts "Redis URL: #{redis_url}"
puts "Ractors: #{ractor_count}, threads per Ractor: #{threads_per_ractor}, " \
     "pool size per Ractor: #{pool_size}, checkout timeout: #{pool_timeout}s"
puts "Jobs: #{ractor_count * jobs_per_ractor}, work per job: #{work_seconds}s, " \
     "queue capacity per Ractor: #{queue_capacity}"

started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
ractors = ractor_count.times.map do |index| # rubocop:disable Metrics/BlockLength
  input = Ractor.make_shareable(
    HostInput.new(
      index, threads_per_ractor, jobs_per_ractor, pool_size, pool_timeout, queue_capacity, work_seconds,
      redis_url, count_key, results_key, run_id
    )
  )
  Ractor.new(input) do |ractor_input| # rubocop:disable Metrics/BlockLength
    factory = RedisFactory.new(ractor_input.index, ractor_input.redis_url)
    validator = ->(resource) { resource.call('PING') == 'PONG' }
    pool = Sidekiq::Ratomic::Pool.new(
      pool_name: :redis_pool,
      size: ractor_input.pool_size,
      pool_timeout: ractor_input.pool_timeout,
      validator:,
      factory:
    )
    jobs = SizedQueue.new(ractor_input.queue_capacity)
    metrics = { active: 0, max_active: 0, processed: 0, error: nil }
    metrics_mutex = Mutex.new
    cancelled = false

    producer = Thread.new do
      ractor_input.jobs.times do |job|
        break if cancelled

        jobs << job
      end
    rescue ClosedQueueError
      nil
    ensure
      jobs.close
    end

    workers = ractor_input.threads.times.map do # rubocop:disable Metrics/BlockLength
      Thread.new do
        loop do
          job = jobs.pop
          break if job.nil? || cancelled

          metrics_mutex.synchronize do
            metrics[:active] += 1
            metrics[:max_active] = [metrics[:max_active], metrics[:active]].max
          end
          begin
            pool.with do |resource|
              job_id = "#{ractor_input.run_id}-#{ractor_input.index}-#{job}"
              resource.call('INCR', ractor_input.count_key)
              resource.call('HSET', ractor_input.results_key, job_id, 'processed')
              sleep ractor_input.work_seconds if ractor_input.work_seconds.positive?
            end
            metrics_mutex.synchronize { metrics[:processed] += 1 }
          rescue StandardError => e
            metrics_mutex.synchronize { metrics[:error] = "#{e.class}: #{e.message}" }
            cancelled = true
            jobs.close
          ensure
            metrics_mutex.synchronize { metrics[:active] -= 1 }
          end
        end
      rescue ClosedQueueError
        nil
      end
    end

    workers.each(&:value)
    producer.join
    pool.close
    metrics.merge(index: ractor_input.index, jobs: ractor_input.jobs, threads: ractor_input.threads)
  end
end

results = ractors.map(&:value)
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
failures = results.filter_map { |result| result[:error] }
processed = Integer(redis.call('GET', count_key) || 0)
result_count = Integer(redis.call('HLEN', results_key) || 0)
expected = ractor_count * jobs_per_ractor
unless failures.empty? && processed == expected && result_count == expected
  abort "Host-owned Ractor example failed: results=#{results.inspect}, processed=#{processed}, " \
        "result_count=#{result_count}, expected=#{expected}"
end

puts format(
  'Host-owned Ractor example passed: %<ractors>d Ractors × %<pool>d resources × %<threads>d threads, ' \
  '%<jobs>d jobs in %<seconds>.3f seconds (%<rate>.2f jobs/sec), max active=%<active>d',
  ractors: ractor_count, pool: pool_size, threads: threads_per_ractor, jobs: processed,
  seconds: elapsed, rate: processed / elapsed, active: results.sum { |result| result[:max_active] }
)
puts "Per-Ractor results: #{results.inspect}"
