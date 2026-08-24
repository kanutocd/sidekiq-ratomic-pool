# frozen_string_literal: true

# Minimal host-owned Ractor integration example. The host creates and joins
# Ractors; each Ractor constructs its own middleware runtime and owns its pool.

require 'etc'
require 'sidekiq/ratomic/pool'

HostResource = Data.define(:ractor_index)
HostFactory = Data.define(:ractor_index) do
  def call
    HostResource.new(ractor_index)
  end
end
HostInput = Data.define(:index, :threads, :jobs, :pool_size, :pool_timeout, :queue_capacity, :work_seconds)

ractor_count = Integer(ENV.fetch('RACTOR_NATIVE_COUNT', Etc.nprocessors.to_s))
threads_per_ractor = Integer(ENV.fetch('RACTOR_NATIVE_THREADS', '20'))
pool_size = Integer(ENV.fetch('RATOMIC_POOL_SIZE', '20'))
pool_timeout = Float(ENV.fetch('RATOMIC_POOL_TIMEOUT', '1'))
queue_capacity = Integer(ENV.fetch('RACTOR_QUEUE_CAPACITY', (threads_per_ractor * 2).to_s))
jobs_per_ractor = Integer(ENV.fetch('BENCHMARK_JOBS_PER_RACTOR', threads_per_ractor.to_s))
work_seconds = Float(ENV.fetch('BENCHMARK_WORK_SECONDS', '0.05'))

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

ractors = ractor_count.times.map do |index| # rubocop:disable Metrics/BlockLength
  input = Ractor.make_shareable(
    HostInput.new(index, threads_per_ractor, jobs_per_ractor, pool_size, pool_timeout, queue_capacity, work_seconds)
  )
  Ractor.new(input) do |ractor_input| # rubocop:disable Metrics/BlockLength
    factory = HostFactory.new(ractor_input.index)
    pool = Sidekiq::Ratomic::Pool.new(
      pool_name: :resource,
      size: ractor_input.pool_size,
      pool_timeout: ractor_input.pool_timeout,
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
          break if job.nil?
          break if cancelled

          metrics_mutex.synchronize do
            metrics[:active] += 1
            metrics[:max_active] = [metrics[:max_active], metrics[:active]].max
          end
          begin
            pool.with do |resource|
              raise 'invalid resource owner' unless resource.ractor_index == ractor_input.index

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
failures = results.filter_map { |result| result[:error] }
processed = results.sum { |result| result[:processed] }
expected = ractor_count * jobs_per_ractor
abort "Host-owned Ractor example failed: results=#{results.inspect}" unless failures.empty? && processed == expected

puts format(
  'Host-owned Ractor example passed: %<ractors>d Ractors × %<pool>d resources × %<threads>d threads, ' \
  '%<jobs>d jobs, max active=%<active>d',
  ractors: ractor_count, pool: pool_size, threads: threads_per_ractor, jobs: processed,
  active: results.sum { |result| result[:max_active] }
)
puts "Per-Ractor results: #{results.inspect}"
