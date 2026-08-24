# frozen_string_literal: true

module SmokeBenchmark
  COUNT_KEY = 'sidekiq-ratomic-pool:benchmark:processed'
  RESULTS_KEY = 'sidekiq-ratomic-pool:benchmark:results'

  # Benchmark job that performs Redis work through the injected pool.
  class RedisBenchmarkWorker
    include Sidekiq::Job

    sidekiq_options queue: 'benchmark', retry: 0

    attr_accessor :redis_pool

    def perform(job_id)
      redis_pool.with do |redis|
        redis.call('INCR', COUNT_KEY)
        redis.call('HSET', RESULTS_KEY, job_id, 'processed')
        work_seconds = Float(ENV.fetch('BENCHMARK_WORK_SECONDS', '0.05'))
        sleep work_seconds if work_seconds.positive?
      end
    end
  end
end
