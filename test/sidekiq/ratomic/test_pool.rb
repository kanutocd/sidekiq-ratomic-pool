# frozen_string_literal: true

require 'test_helper'

module Sidekiq
  module Ratomic
    class TestPool < Minitest::Test
      def test_that_it_has_a_version_number
        refute_nil ::Sidekiq::Ratomic::Pool::VERSION
      end

      class ResourceFactory
        def call
          Object.new
        end
      end

      class NonShareableFactory
        def initialize
          @mutex = Mutex.new
        end

        def call
          Object.new
        end
      end

      class Worker
        attr_accessor :redis_pool
      end

      class PingResource
        def ping # rubocop:disable Naming/PredicateMethod
          true
        end
      end

      class ActiveResource
        def active?
          true
        end
      end

      class PingFactory
        def call
          PingResource.new
        end
      end

      class ActiveFactory
        def call
          ActiveResource.new
        end
      end

      class PlainFactory
        def call
          Object.new
        end
      end

      RactorResource = Data.define(:owner)
      RactorFactory = Data.define(:owner) do
        def call
          RactorResource.new(owner)
        end
      end
      RactorInput = Data.define(:owner, :factory)

      def build_pool(**, &validator)
        factory = ResourceFactory.new.freeze
        Pool.new(pool_name: :redis_pool, size: 5, **, validator: validator, factory: factory)
      end

      def test_middleware_injects_pool_into_worker
        pool = Pool.new(pool_name: :redis_pool, factory: ResourceFactory.new.freeze)
        worker = Worker.new

        pool.call(worker, {}, 'default') do
          assert_same pool, worker.redis_pool
        end
      end

      def test_requires_a_resource_factory
        assert_raises(ArgumentError) { Pool.new(pool_name: :redis_pool) }
        assert_raises(ArgumentError) { Pool.new(factory: ResourceFactory.new.freeze) }
      end

      def test_rejects_a_non_shareable_resource_factory
        error = assert_raises(ArgumentError) do
          Pool.new(pool_name: :redis_pool, factory: NonShareableFactory.new)
        end

        assert_match(/resource factory must be Ractor-shareable/, error.message)
      end

      def test_accepts_sidekiq_style_positional_options
        validator = ->(_resource) { true }
        pool = Pool.new(
          {
            pool_name: :positional_pool,
            size: 2,
            max_retries: 1,
            retry_delay: 0,
            cb_threshold: 2,
            cb_timeout: 1,
            validator:,
            retryable_errors: [IOError],
            factory: ResourceFactory.new.freeze
          }
        )

        assert_equal :positional_pool, pool.pool_name
        assert_equal 2, pool.size
        assert_equal 1, pool.max_retries
        assert_equal 0, pool.retry_delay
        assert_equal 2, pool.cb_threshold
        assert_equal 1, pool.cb_timeout
        assert_same validator, pool.validator
        assert_equal [IOError], pool.retryable_errors
      end

      def test_rejects_invalid_middleware_options
        assert_raises(ArgumentError) { Pool.new(Object.new) }

        assert_raises(ArgumentError) do
          Pool.new(pool_name: :redis_pool, factory: ResourceFactory.new.freeze, validator: Object.new)
        end

        assert_raises(ArgumentError) do
          Pool.new({ pool_name: :redis_pool, factory: ResourceFactory.new.freeze, unknown: true })
        end
      end

      def test_config_shares_runtime_across_middleware_instances
        config = Object.new
        first = Pool.new(pool_name: :redis_pool, factory: ResourceFactory.new.freeze)
        second = Pool.new({ pool_name: :redis_pool, factory: ResourceFactory.new.freeze })

        assert_same config, (first.config = config)
        assert_same config, (second.config = config)
        assert_same first.instance_variable_get(:@local_pool), second.instance_variable_get(:@local_pool)
        assert_same first.instance_variable_get(:@state_mutex), second.instance_variable_get(:@state_mutex)
        assert_same first.instance_variable_get(:@failure_count), second.instance_variable_get(:@failure_count)
        assert_same first.instance_variable_get(:@state_holder), second.instance_variable_get(:@state_holder)
      end

      def test_configurations_keep_pool_runtimes_isolated
        first = Pool.new(pool_name: :redis_pool, factory: ResourceFactory.new.freeze)
        second = Pool.new(pool_name: :redis_pool, factory: ResourceFactory.new.freeze)

        first.config = Object.new
        second.config = Object.new

        refute_same first.instance_variable_get(:@local_pool), second.instance_variable_get(:@local_pool)
        refute_same first.instance_variable_get(:@state_mutex), second.instance_variable_get(:@state_mutex)
      end

      def test_middleware_runtime_is_not_ractor_shareable
        pool = Pool.new(pool_name: :redis_pool, factory: ResourceFactory.new.freeze)

        assert_raises(Ractor::Error) { Ractor.make_shareable(pool) }
      end

      def test_host_owned_ractors_receive_distinct_local_resources
        factory = Ractor.make_shareable(RactorFactory.new(:host))
        inputs = 4.times.map do |owner|
          Ractor.make_shareable(RactorInput.new(owner, factory))
        end
        ractors = inputs.map do |input|
          Ractor.new(input) do |ractor_input|
            pool = Pool.new(pool_name: :redis_pool, size: 1, factory: ractor_input.factory)
            resource = pool.with { |checked_out| checked_out }
            result = [ractor_input.owner, resource.owner, resource.object_id]
            pool.close
            result
          end
        end

        results = ractors.map(&:value)
        owners = results.map { |result| result[1] }

        assert_equal [0, 1, 2, 3], results.map(&:first)
        assert_equal %i[host host host host], owners
        assert_equal 4, results.map(&:last).uniq.size
      end

      def test_threads_share_the_pool_owned_by_their_ractor
        factory = Ractor.make_shareable(RactorFactory.new(:threaded))
        input = Ractor.make_shareable(RactorInput.new(:threaded, factory))
        ractor = Ractor.new(input) do |ractor_input|
          pool = Pool.new(pool_name: :redis_pool, size: 2, factory: ractor_input.factory)
          resources = Queue.new
          threads = 2.times.map do
            Thread.new do
              pool.with do |resource|
                resources << resource
                sleep 0.01
              end
            end
          end
          threads.each(&:value)
          checked_out = 2.times.map { resources.pop }
          pool.close
          [checked_out.map(&:owner), checked_out.map(&:object_id).uniq.size]
        end

        owners, distinct_resources = ractor.value

        assert_equal %i[threaded threaded], owners
        assert_equal 2, distinct_resources
      end

      def test_rejects_invalid_configuration
        invalid_options = [
          { size: 0 },
          { max_retries: -1 },
          { retry_delay: -1 },
          { cb_threshold: 0 },
          { cb_timeout: -1 }
        ]

        invalid_options.each do |options|
          assert_raises(ArgumentError) do
            Pool.new(pool_name: :redis_pool, factory: ResourceFactory.new.freeze, **options)
          end
        end
      end

      def test_middleware_yields_for_worker_without_pool_accessor
        pool = Pool.new(pool_name: :redis_pool, factory: ResourceFactory.new.freeze)

        assert_equal :yielded, pool.call(Object.new, {}, 'default') { :yielded }
      end

      def test_with_checks_out_a_resource
        pool = Pool.new(pool_name: :redis_pool, factory: ResourceFactory.new.freeze)

        assert_instance_of(Object, pool.with { |resource| resource })
      end

      def test_retries_after_health_check_failure
        attempts = 0
        validator = lambda { |_resource|
          attempts += 1
          attempts > 1
        }
        pool = build_pool(max_retries: 2, retry_delay: 0, &validator)

        assert_equal(:ok, pool.with { :ok })
        assert_equal 2, attempts
      end

      def test_retries_use_exponential_backoff
        attempts = 0
        sleeps = []
        validator = lambda { |_resource|
          attempts += 1
          attempts > 2
        }
        pool = build_pool(max_retries: 2, retry_delay: 0.01, &validator)

        pool.define_singleton_method(:sleep) { |delay| sleeps << delay }
        begin
          assert_equal(:ok, pool.with { :ok })
        ensure
          pool.singleton_class.send(:remove_method, :sleep)
        end

        assert_equal [0.01, 0.02], sleeps
      end

      def test_worker_errors_are_not_retried_or_recorded_as_connection_failures
        pool = build_pool(max_retries: 2, cb_threshold: 1, retry_delay: 0.01)
        sleeps = []

        pool.define_singleton_method(:sleep) { |delay| sleeps << delay }
        begin
          assert_raises(RuntimeError) { pool.with { raise 'worker failure' } }
        ensure
          pool.singleton_class.send(:remove_method, :sleep)
        end

        assert_empty sleeps
        assert_equal :closed, pool.state
      end

      def test_retryable_worker_errors_are_retried
        attempts = 0
        pool = build_pool(max_retries: 1, retry_delay: 0)

        result = pool.with do
          attempts += 1
          raise IOError, 'socket dropped' if attempts == 1

          :ok
        end

        assert_equal :ok, result
        assert_equal 2, attempts
      end

      def test_exhausted_retries_reraise_the_failure
        pool = build_pool(max_retries: 0, retry_delay: 0) { false }

        assert_raises(Pool::CheckoutError) { pool.with { :never_reached } }
      end

      def test_validator_exceptions_are_treated_as_unhealthy
        validator = ->(_resource) { raise 'validator failed' }
        pool = build_pool(max_retries: 0, retry_delay: 0, &validator)

        assert_raises(Pool::CheckoutError) { pool.with { :never_reached } }
      end

      def test_default_validator_supports_ping_active_and_plain_resources
        ping_pool = Pool.new(pool_name: :redis_pool, factory: PingFactory.new.freeze)
        active_pool = Pool.new(pool_name: :redis_pool, factory: ActiveFactory.new.freeze)
        plain_pool = Pool.new(pool_name: :redis_pool, factory: PlainFactory.new.freeze)

        ping_resource = ping_pool.with { |resource| resource }
        active_resource = active_pool.with { |resource| resource }
        plain_resource = plain_pool.with { |resource| resource }

        assert_instance_of PingResource, ping_resource
        assert_instance_of ActiveResource, active_resource
        assert_instance_of Object, plain_resource
      end

      def test_circuit_breaker_fast_fails_after_threshold
        pool = build_pool(max_retries: 0, cb_threshold: 2, retry_delay: 0) { false }

        2.times { assert_raises(Pool::CheckoutError) { pool.with { :never_reached } } }

        assert_raises(Pool::CircuitOpenError) { pool.with { flunk 'circuit was not open' } }
        assert_equal :open, pool.state
      end

      def test_open_circuit_transitions_to_half_open_and_closes_on_success
        attempts = 0
        validator = lambda do |_resource|
          attempts += 1
          attempts > 1
        end
        pool = Pool.new(pool_name: :redis_pool, max_retries: 0, cb_threshold: 1,
                        cb_timeout: 0, validator:, factory: ResourceFactory.new.freeze)

        assert_raises(Pool::CheckoutError) { pool.with { :never_reached } }
        assert_equal :half_open, pool.state
        resource = pool.with { |checked_out| checked_out }

        assert_instance_of Object, resource
        assert_equal :closed, pool.state
      end

      def test_close_shuts_down_the_current_ractor_pool
        pool = Pool.new(pool_name: :redis_pool, factory: ResourceFactory.new.freeze)

        assert_nil pool.close
        assert_nil pool.shutdown
      end

      def test_threads_receive_distinct_resources_when_pool_is_contended
        pool = Pool.new(pool_name: :redis_pool, size: 5, factory: ResourceFactory.new.freeze)
        resources = []
        mutex = Mutex.new
        threads = 5.times.map do
          Thread.new do
            pool.with do |resource|
              mutex.synchronize { resources << resource.object_id }
              sleep 0.01
            end
          end
        end

        threads.each(&:join)

        assert_equal resources.size, resources.uniq.size
      end
    end
  end
end
