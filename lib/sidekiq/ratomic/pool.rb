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
    class Pool
      attr_reader :pool_name, :size, :max_retries, :retry_delay, :validator, :cb_threshold, :cb_timeout,
                  :retryable_errors

      def initialize(pool_name:, size: 10, max_retries: 3, retry_delay: 0.2,
                     cb_threshold: 5, cb_timeout: 30, validator: nil,
                     retryable_errors: [IOError, SystemCallError, Timeout::Error], factory: nil, &block)
        factory ||= block
        raise ArgumentError, 'A resource factory must be provided' unless factory

        validate_options!(size, max_retries, retry_delay, cb_threshold, cb_timeout)

        @pool_name = pool_name.to_sym
        @size = size
        @max_retries = max_retries
        @retry_delay = retry_delay
        @cb_threshold = cb_threshold
        @cb_timeout = cb_timeout
        @validator = validator || method(:default_validator)
        @retryable_errors = retryable_errors.freeze
        @state_mutex = Mutex.new
        @failure_count = ::Ratomic::Counter.new
        @state = :closed
        @last_state_change = monotonic_time

        shareable_factory = Ractor.make_shareable(factory)
        @local_pool = ::Ratomic::LocalPool.new(size: @size, factory: shareable_factory)
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
          if @state == :open && monotonic_time - @last_state_change > @cb_timeout
            @state = :half_open
            @last_state_change = monotonic_time
          end
          @state
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

      def validate_options!(size, max_retries, retry_delay, cb_threshold, cb_timeout)
        validations = [
          [size.is_a?(Integer) && size.positive?, 'size must be a positive Integer'],
          [max_retries.is_a?(Integer) && max_retries >= 0, 'max_retries must be a non-negative Integer'],
          [retry_delay.is_a?(Numeric) && retry_delay >= 0, 'retry_delay must be non-negative'],
          [cb_threshold.is_a?(Integer) && cb_threshold.positive?, 'cb_threshold must be a positive Integer'],
          [cb_timeout.is_a?(Numeric) && cb_timeout >= 0, 'cb_timeout must be non-negative']
        ]
        validations.each do |valid, message|
          raise ArgumentError, message unless valid
        end
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
          @state = :closed if @state == :half_open
        end
      end

      def record_failure
        @state_mutex.synchronize do
          @failure_count.increment(1)
          if @failure_count.value >= @cb_threshold || @state == :half_open
            @state = :open
            @last_state_change = monotonic_time
          end
        end
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
