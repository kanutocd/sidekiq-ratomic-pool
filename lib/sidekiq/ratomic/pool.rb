# frozen_string_literal: true

require 'ratomic'
require 'timeout'
require_relative 'pool/errors'
require_relative 'pool/version'

# Sidekiq integration namespace.
module Sidekiq
  # Ratomic-backed Sidekiq middleware namespace.
  module Ratomic
    # Sidekiq server middleware that exposes a Ractor-local resource pool.
    #
    # Resources are validated before checkout and transient failures are retried
    # with exponential backoff. Persistent failures open the circuit breaker.
    # rubocop:disable Metrics/ClassLength
    class Pool
      # Name of the worker accessor populated by the middleware.
      # @return [Symbol]
      attr_reader :pool_name

      # Maximum number of resources owned by each Ractor-local pool.
      # @return [Integer]
      attr_reader :size

      # Maximum time to wait for a resource checkout.
      # @return [Numeric, nil] seconds, or nil to wait indefinitely
      attr_reader :pool_timeout

      # Maximum number of retries for checkout and configured retryable failures.
      # @return [Integer]
      attr_reader :max_retries

      # Base delay used for exponential retry backoff.
      # @return [Numeric] seconds
      attr_reader :retry_delay

      # Callback used to validate a checked-out resource.
      # @return [#call]
      attr_reader :validator

      # Number of recorded failures required to open the circuit.
      # @return [Integer]
      attr_reader :cb_threshold

      # Time an open circuit remains open before a half-open probe.
      # @return [Numeric] seconds
      attr_reader :cb_timeout

      # Exception classes treated as retryable worker/resource failures.
      # @return [Array<Class>]
      attr_reader :retryable_errors

      # rubocop:disable Metrics/MethodLength
      def initialize(options = nil, pool_name: nil, size: 10, pool_timeout: 1.0, max_retries: 3, retry_delay: 0.2,
                     cb_threshold: 5, cb_timeout: 30, validator: nil,
                     retryable_errors: [IOError, SystemCallError, Timeout::Error], factory: nil, &block)
        normalize_options!(options) do |config|
          pool_name = config.fetch(:pool_name, pool_name)
          size = config.fetch(:size, size)
          pool_timeout = config.fetch(:pool_timeout, pool_timeout)
          max_retries = config.fetch(:max_retries, max_retries)
          retry_delay = config.fetch(:retry_delay, retry_delay)
          cb_threshold = config.fetch(:cb_threshold, cb_threshold)
          cb_timeout = config.fetch(:cb_timeout, cb_timeout)
          validator = config.fetch(:validator, validator)
          retryable_errors = config.fetch(:retryable_errors, retryable_errors)
          factory = config.fetch(:factory, factory)
        end

        factory ||= block
        raise ArgumentError, 'A pool_name must be provided' unless pool_name
        raise ArgumentError, 'A resource factory must be provided' unless factory

        validate_options!(
          size:, pool_timeout:, max_retries:, retry_delay:, cb_threshold:, cb_timeout:
        )

        @pool_name = pool_name.to_sym
        @size = size
        @pool_timeout = pool_timeout
        @max_retries = max_retries
        @retry_delay = retry_delay
        @cb_threshold = cb_threshold
        @cb_timeout = cb_timeout
        @validator = validator || method(:default_validator)
        @retryable_errors = retryable_errors.freeze
        @state_mutex = Mutex.new
        @failure_count = ::Ratomic::Counter.new
        @state_holder = { state: :closed, last_state_change: monotonic_time }

        raise ArgumentError, 'validator must respond to call' unless validator.nil? || validator.respond_to?(:call)

        shareable_factory = make_shareable_factory(factory)
        @local_pool = ::Ratomic::LocalPool.new(size: @size, timeout: @pool_timeout, factory: shareable_factory)
      end

      # Share one pool runtime across Sidekiq's per-job middleware instances.
      def config=(config)
        mutex = config.instance_variable_get(:@sidekiq_ratomic_pool_mutex)
        unless mutex
          mutex = Mutex.new
          config.instance_variable_set(:@sidekiq_ratomic_pool_mutex, mutex)
        end

        runtimes = config.instance_variable_get(:@sidekiq_ratomic_pool_runtimes)
        unless runtimes
          runtimes = {} # : Hash[Symbol, Pool]
          config.instance_variable_set(:@sidekiq_ratomic_pool_runtimes, runtimes)
        end

        mutex.synchronize do
          runtime = runtimes[@pool_name]
          if runtime
            adopt_runtime(runtime)
          else
            runtimes[@pool_name] = self
          end
        end
        @config = config
      end

      # Inject this pool into a worker's configured pool accessor.
      def call(job_instance, _job_payload, _queue)
        setter = "#{@pool_name}="
        job_instance.public_send(setter, self) if job_instance.respond_to?(setter)
        yield
      end

      # Close resources owned by the current Ractor.
      def close
        @local_pool.close
      end

      alias shutdown close

      # Check out a healthy resource and yield it to the caller.
      def with
        check_circuit_state!
        attempts = 0
        work_failed = false

        begin
          attempts += 1
          @local_pool.with do |resource|
            raise Pool::CheckoutError, 'Resource connection health check failed' unless verify_health(resource)

            begin
              result = yield resource
            rescue StandardError
              work_failed = true
              raise
            end
            record_success
            result
          end
        rescue StandardError => e
          raise unless !work_failed || retryable_error?(e)

          record_failure
          if attempts <= @max_retries && state != :open
            delay = @retry_delay * (2**(attempts - 1))
            sleep(delay) if delay.positive?
            retry
          end

          raise
        end
      end

      # Return the current circuit-breaker state.
      def state
        @state_mutex.synchronize do
          if @state_holder[:state] == :open && monotonic_time - @state_holder[:last_state_change] > @cb_timeout
            @state_holder[:state] = :half_open
            @state_holder[:last_state_change] = monotonic_time
          end
          @state_holder[:state]
        end
      end

      private

      def check_circuit_state!
        return unless state == :open

        raise Pool::CircuitOpenError, 'Circuit breaker is open'
      end

      def verify_health(resource)
        @validator.call(resource)
      rescue StandardError
        false
      end

      def retryable_error?(error)
        !work_error?(error) || @retryable_errors.any? { |error_class| error.is_a?(error_class) }
      end

      def work_error?(error)
        error.is_a?(StandardError) && !error.is_a?(Pool::CheckoutError)
      end

      def validate_options!(size:, pool_timeout:, max_retries:, retry_delay:, cb_threshold:, cb_timeout:)
        validations = [
          [size.is_a?(Integer) && size.positive?, 'size must be a positive Integer'],
          [pool_timeout.nil? || (pool_timeout.is_a?(Numeric) && pool_timeout >= 0),
           'pool_timeout must be numeric or nil and non-negative'],
          [max_retries.is_a?(Integer) && max_retries >= 0, 'max_retries must be a non-negative Integer'],
          [retry_delay.is_a?(Numeric) && retry_delay >= 0, 'retry_delay must be non-negative'],
          [cb_threshold.is_a?(Integer) && cb_threshold.positive?, 'cb_threshold must be a positive Integer'],
          [cb_timeout.is_a?(Numeric) && cb_timeout >= 0, 'cb_timeout must be non-negative']
        ]
        validations.each do |valid, message|
          raise ArgumentError, message unless valid
        end
      end

      def normalize_options!(options)
        return unless options
        raise ArgumentError, 'middleware options must be a Hash' unless options.is_a?(Hash)

        config = options.transform_keys(&:to_sym)
        allowed = %i[pool_name size pool_timeout max_retries retry_delay cb_threshold cb_timeout validator
                     retryable_errors factory]
        unknown = config.keys - allowed
        raise ArgumentError, "unknown middleware options: #{unknown.join(', ')}" unless unknown.empty?

        yield config
      end

      def adopt_runtime(runtime)
        @local_pool = runtime.instance_variable_get(:@local_pool)
        @pool_timeout = runtime.instance_variable_get(:@pool_timeout)
        @state_mutex = runtime.instance_variable_get(:@state_mutex)
        @failure_count = runtime.instance_variable_get(:@failure_count)
        @state_holder = runtime.instance_variable_get(:@state_holder)
      end

      def default_validator(resource)
        return resource.ping if resource.respond_to?(:ping)
        return resource.active? if resource.respond_to?(:active?)

        true
      end

      def record_success
        @state_mutex.synchronize do
          failure_count = @failure_count.value
          @failure_count.decrement(failure_count) unless failure_count.zero?
          @state_holder[:state] = :closed if @state_holder[:state] == :half_open
        end
      end

      def record_failure
        @state_mutex.synchronize do
          @failure_count.increment(1)
          if @failure_count.value >= @cb_threshold || @state_holder[:state] == :half_open
            @state_holder[:state] = :open
            @state_holder[:last_state_change] = monotonic_time
          end
        end
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def make_shareable_factory(factory)
        Ractor.make_shareable(factory)
      rescue Ractor::Error, TypeError => e
        raise ArgumentError, "resource factory must be Ractor-shareable: #{e.message}"
      end
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/ClassLength
  end
end
