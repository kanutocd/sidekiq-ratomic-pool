# frozen_string_literal: true

require 'connection_pool'
require 'redis-client'
require 'sidekiq'
require_relative 'worker'

module SmokeBenchmark
  # Connection-pool adapter with the same Redis health probe as the Ratomic run.
  class ValidatedConnectionPool
    def initialize(url:, size:, timeout:)
      @pool = ConnectionPool.new(size:, timeout:) do
        RedisClient.config(url:).new_client
      end
    end

    def with
      @pool.with do |redis|
        raise 'Redis health check failed' unless redis.call('PING') == 'PONG'

        yield redis
      end
    end
  end

  # Sidekiq middleware that injects the connection_pool-backed resource wrapper.
  class ConnectionPoolBenchmarkMiddleware
    def initialize(options = nil, pool_name: nil, size: 4, timeout: 5, redis_url: nil)
      options ||= {}
      pool_name = options.fetch(:pool_name, pool_name)
      size = options.fetch(:size, size)
      timeout = options.fetch(:timeout, timeout)
      redis_url = options.fetch(:redis_url, redis_url)
      @pool_name = pool_name
      @pool = ValidatedConnectionPool.new(url: redis_url, size:, timeout:)
    end

    def config=(config)
      mutex = config.instance_variable_get(:@connection_pool_benchmark_mutex)
      unless mutex
        mutex = Mutex.new
        config.instance_variable_set(:@connection_pool_benchmark_mutex, mutex)
      end

      runtimes = config.instance_variable_get(:@connection_pool_benchmark_runtimes)
      unless runtimes
        runtimes = {}
        config.instance_variable_set(:@connection_pool_benchmark_runtimes, runtimes)
      end

      mutex.synchronize do
        runtime = runtimes[@pool_name]
        if runtime
          @pool = runtime.instance_variable_get(:@pool)
        else
          runtimes[@pool_name] = self
        end
      end
      @config = config
    end

    def call(job, _payload, _queue)
      setter = "#{@pool_name}="
      job.public_send(setter, @pool) if job.respond_to?(setter)
      yield
    end
  end
end

redis_port = ENV.fetch('REDIS_PORT', '6379')
redis_url = ENV.fetch('REDIS_URL', "redis://127.0.0.1:#{redis_port}/0").freeze

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  config.server_middleware do |chain|
    chain.add(
      SmokeBenchmark::ConnectionPoolBenchmarkMiddleware,
      pool_name: :redis_pool,
      size: Integer(ENV.fetch('RATOMIC_POOL_SIZE', '4')),
      timeout: Float(ENV.fetch('RATOMIC_POOL_TIMEOUT', '1')),
      redis_url:
    )
  end
end
