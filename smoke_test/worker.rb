# frozen_string_literal: true

module SmokeTest
  COUNT_KEY = 'sidekiq-ratomic-pool:smoke:processed'
  RESULTS_KEY = 'sidekiq-ratomic-pool:smoke:results'

  # Sidekiq job that performs real Redis work through the injected pool.
  class RedisSmokeWorker
    include Sidekiq::Job

    sidekiq_options queue: 'smoke', retry: 2

    attr_accessor :redis_pool

    def perform(job_id)
      redis_pool.with do |redis|
        redis.call('INCR', SmokeTest::COUNT_KEY)
        redis.call('HSET', SmokeTest::RESULTS_KEY, job_id, 'processed')
        work_seconds = Float(ENV.fetch('SMOKE_WORK_SECONDS', '0.05'))
        sleep work_seconds if work_seconds.positive?
      end
    end
  end
end
