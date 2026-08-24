# frozen_string_literal: true

require 'sidekiq'
require 'redis-client'
require 'sidekiq_ratomic_pool'
require_relative 'worker'

RedisFactory = Data.define(:url) do
  def call
    RedisClient.config(url:).new_client
  end
end

redis_port = ENV.fetch('REDIS_PORT', '6379')
redis_url = ENV.fetch('REDIS_URL', "redis://127.0.0.1:#{redis_port}/0").freeze

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  config.server_middleware do |chain|
    chain.add(
      Sidekiq::Ratomic::Pool,
      pool_name: :redis_pool,
      size: Integer(ENV.fetch('RATOMIC_POOL_SIZE', '4')),
      max_retries: 3,
      retry_delay: 0.05,
      cb_threshold: 5,
      cb_timeout: 5,
      validator: ->(redis) { redis.call('PING') == 'PONG' },
      factory: RedisFactory.new(redis_url).freeze
    )
  end
end
