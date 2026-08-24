# frozen_string_literal: true

require 'sidekiq'
require 'redis-client'
require_relative 'worker'

redis_url = ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6379/0').freeze
job_count = Integer(ENV.fetch('SMOKE_JOB_COUNT', '20'))
timeout = Integer(ENV.fetch('SMOKE_TIMEOUT', '30'))
run_id = ENV.fetch('SMOKE_RUN_ID', Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond).to_s)
redis = RedisClient.config(url: redis_url).new_client
Sidekiq.configure_client { |config| config.redis = { url: redis_url } }

redis.call('DEL', SmokeTest::COUNT_KEY, SmokeTest::RESULTS_KEY)
job_ids = job_count.times.map do |index|
  job_id = "#{run_id}-#{index}"
  Sidekiq::Client.push('class' => SmokeTest::RedisSmokeWorker, 'args' => [job_id], 'queue' => 'smoke')
  job_id
end

deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
loop do
  processed = Integer(redis.call('GET', SmokeTest::COUNT_KEY) || 0)
  results = Integer(redis.call('HLEN', SmokeTest::RESULTS_KEY) || 0)
  break if processed >= job_count && results >= job_count

  if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    abort "Timed out waiting for #{job_count} jobs (processed=#{processed}, results=#{results})"
  end

  sleep 0.1
end

missing = job_ids.reject { |job_id| redis.call('HGET', SmokeTest::RESULTS_KEY, job_id) == 'processed' }
abort "Missing processed jobs: #{missing.join(', ')}" unless missing.empty?

puts "Smoke test passed: #{job_count} jobs processed by standalone Sidekiq through real Redis connections"
