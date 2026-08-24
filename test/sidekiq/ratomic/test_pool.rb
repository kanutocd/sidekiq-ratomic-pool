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
            pool_timeout: 2,
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
        assert_equal 2, pool.pool_timeout
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
        first = Pool.new(pool_name: :redis_pool, pool_timeout: 2, factory: ResourceFactory.new.freeze)
        second = Pool.new({ pool_name: :redis_pool, factory: ResourceFactory.new.freeze })

        assert_same config, (first.config = config)
        assert_same config, (second.config = config)
        assert_same first.instance_variable_get(:@local_pool), second.instance_variable_get(:@local_pool)
        assert_equal first.pool_timeout, second.pool_timeout
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

      def test_ractor_local_health_failure_retries_and_recovers
        factory = Ractor.make_shareable(RactorFactory.new(:health))
        ractor = Ractor.new(factory) do |ractor_factory|
          attempts = 0
          validator = lambda do |_resource|
            attempts += 1
            attempts > 1
          end
          pool = Pool.new(pool_name: :redis_pool, max_retries: 1, retry_delay: 0,
                          validator:, factory: ractor_factory)
          result = pool.with { :ok }
          [result, attempts, pool.state]
        end

        result, attempts, state = ractor.value

        assert_equal :ok, result
        assert_equal 2, attempts
        assert_equal :closed, state
      end

      def test_ractor_local_circuit_opens_and_fast_fails
        factory = Ractor.make_shareable(RactorFactory.new(:circuit))
        ractor = Ractor.new(factory) do |ractor_factory|
          pool = Pool.new(pool_name: :redis_pool, max_retries: 0, cb_threshold: 1,
                          cb_timeout: 60, validator: ->(_resource) { false }, factory: ractor_factory)
          first_error = begin
            pool.with { :unreachable }
          rescue StandardError => e
            e.class.name
          end
          second_error = begin
            pool.with { :unreachable }
          rescue StandardError => e
            e.class.name
          end
          [first_error, second_error, pool.state]
        end

        first_error, second_error, state = ractor.value

        assert_equal 'Sidekiq::Ratomic::Pool::CheckoutError', first_error
        assert_equal 'Sidekiq::Ratomic::Pool::CircuitOpenError', second_error
        assert_equal :open, state
      end

      def test_ractor_local_half_open_probe_recovers_the_circuit
        factory = Ractor.make_shareable(RactorFactory.new(:half_open))
        ractor = Ractor.new(factory) do |ractor_factory|
          attempts = 0
          validator = lambda do |_resource|
            attempts += 1
            attempts > 1
          end
          pool = Pool.new(pool_name: :redis_pool, max_retries: 0, cb_threshold: 1,
                          cb_timeout: 0, validator:, factory: ractor_factory)
          first_error = begin
            pool.with { :unreachable }
          rescue StandardError => e
            e.class.name
          end
          half_open_state = pool.state
          result = pool.with { :recovered }
          [first_error, half_open_state, result, pool.state]
        end

        first_error, half_open_state, result, final_state = ractor.value

        assert_equal 'Sidekiq::Ratomic::Pool::CheckoutError', first_error
        assert_equal :half_open, half_open_state
        assert_equal :recovered, result
        assert_equal :closed, final_state
      end

      def test_half_open_allows_only_one_concurrent_probe
        attempts = 0
        probe_started = Queue.new
        release_probe = Queue.new
        validator = lambda do |_resource|
          attempts += 1
          if attempts == 2
            probe_started << true
            release_probe.pop
          end
          attempts > 1
        end
        pool = Pool.new(pool_name: :redis_pool, max_retries: 0, cb_threshold: 1,
                        cb_timeout: 0, validator:, factory: ResourceFactory.new.freeze)

        begin
          assert_raises(Pool::CheckoutError) { pool.with { :unreachable } }
          pool.state
          threads = 8.times.map do
            Thread.new do
              pool.with { :recovered }
            rescue StandardError => e
              e.class.name
            end
          end
          probe_started.pop
          sleep 0.01
          release_probe << true
          results = threads.map(&:value)

          assert_equal 2, attempts
          assert_equal 1, results.count(:recovered)
          assert_equal 7, results.count('Sidekiq::Ratomic::Pool::CircuitOpenError')
          assert_equal :closed, pool.state
        ensure
          pool.close
        end
      end

      def test_half_open_probe_lease_releases_after_non_retryable_worker_failure
        attempts = 0
        validator = lambda do |_resource|
          attempts += 1
          attempts > 1
        end
        pool = Pool.new(pool_name: :redis_pool, max_retries: 0, cb_threshold: 1,
                        cb_timeout: 0, validator:, factory: ResourceFactory.new.freeze)

        begin
          assert_raises(Pool::CheckoutError) { pool.with { :unreachable } }
          pool.state
          assert_raises(RuntimeError) { pool.with { raise 'worker failure' } }
          assert_equal :half_open, pool.state
          recovered = pool.with { :recovered }

          assert_equal :recovered, recovered
          assert_equal :closed, pool.state
        ensure
          pool.close
        end
      end

      def test_host_coordinates_cancellation_when_a_ractor_fails
        parent = Ractor.current
        factory = Ractor.make_shareable(RactorFactory.new(:cancellation))
        ractors = 2.times.map do |index|
          Ractor.new(index, factory, parent) do |ractor_index, ractor_factory, host|
            cancelled = false
            cancellation = Thread.new do
              Ractor.receive
              cancelled = true
            end
            pool = Pool.new(pool_name: :redis_pool, factory: ractor_factory)

            if ractor_index.zero?
              begin
                pool.with { raise 'ractor failure' }
              rescue RuntimeError => e
                host.send([:failed, ractor_index, e.message])
              end
            else
              sleep 0.001 until cancelled
            end

            cancellation.join
            pool.close
            [ractor_index, cancelled]
          end
        end

        failure = Ractor.receive
        ractors.each { |ractor| ractor.send(:cancel) }
        results = ractors.map(&:value)

        assert_equal [:failed, 0, 'ractor failure'], failure
        assert_equal [[0, true], [1, true]], results.sort
      end

      def test_simultaneous_failures_remain_isolated_across_ractors
        factory = Ractor.make_shareable(RactorFactory.new(:failure_stress))
        ractors = 4.times.map do |index|
          Ractor.new(index, factory) do |ractor_index, ractor_factory|
            pool = Pool.new(pool_name: :redis_pool, size: 8, max_retries: 0, cb_threshold: 1,
                            cb_timeout: 60, validator: lambda do |_resource|
                              sleep 0.001
                              false
                            end,
                            factory: ractor_factory)
            start = Queue.new
            threads = 8.times.map do
              Thread.new do
                start.pop
                pool.with { :unreachable }
              rescue StandardError => e
                e.class.name
              end
            end
            8.times { start << true }
            results = threads.map(&:value)
            state = pool.state
            pool.close
            [ractor_index, results, state]
          end
        end

        results = ractors.map(&:value)

        assert_equal [0, 1, 2, 3], results.map(&:first)
        results.each do |_index, errors, state|
          assert_equal 8, errors.size
          assert(errors.all? { |error| error.end_with?('CheckoutError', 'CircuitOpenError') })
          assert_equal :open, state
        end
      end

      def test_ractor_local_worker_failure_policy_is_preserved
        factory = Ractor.make_shareable(RactorFactory.new(:worker_failure))
        ractor = Ractor.new(factory) do |ractor_factory|
          pool = Pool.new(pool_name: :redis_pool, max_retries: 1, retry_delay: 0,
                          cb_threshold: 1, factory: ractor_factory)
          attempts = 0
          error_class = begin
            pool.with do
              attempts += 1
              raise 'worker failure'
            end
          rescue StandardError => e
            e.class.name
          end
          [error_class, attempts, pool.state]
        end

        error_class, attempts, state = ractor.value

        assert_equal 'RuntimeError', error_class
        assert_equal 1, attempts
        assert_equal :closed, state
      end

      def test_rejects_invalid_configuration
        invalid_options = [
          { size: 0 },
          { pool_timeout: -1 },
          { pool_timeout: Object.new },
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
