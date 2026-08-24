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

      class Worker
        attr_accessor :redis_pool
      end

      # rubocop:disable Naming/PredicateMethod
      class PingResource
        def ping
          true
        end
      end
      # rubocop:enable Naming/PredicateMethod

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

      def test_exhausted_retries_reraise_the_failure
        pool = build_pool(max_retries: 0, retry_delay: 0) { false }

        assert_raises(RuntimeError) { pool.with { :never_reached } }
      end

      def test_validator_exceptions_are_treated_as_unhealthy
        validator = ->(_resource) { raise 'validator failed' }
        pool = build_pool(max_retries: 0, retry_delay: 0, &validator)

        assert_raises(RuntimeError) { pool.with { :never_reached } }
      end

      # rubocop:disable Metrics/AbcSize
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
      # rubocop:enable Metrics/AbcSize

      def test_circuit_breaker_fast_fails_after_threshold
        pool = build_pool(max_retries: 0, cb_threshold: 2, retry_delay: 0) { false }

        2.times { assert_raises(RuntimeError) { pool.with { :never_reached } } }

        assert_raises(Pool::CircuitOpenError) { pool.with { flunk 'circuit was not open' } }
        assert_equal :open, pool.state
      end

      def test_open_circuit_transitions_to_half_open_and_closes_on_success
        pool = Pool.new(pool_name: :redis_pool, max_retries: 0, cb_threshold: 1,
                        cb_timeout: 0, factory: ResourceFactory.new.freeze)

        assert_raises(RuntimeError) { pool.with { raise 'temporary failure' } }
        assert_equal :half_open, pool.state
        resource = pool.with { |checked_out| checked_out }

        assert_instance_of Object, resource
        assert_equal :closed, pool.state
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end
  end
end
