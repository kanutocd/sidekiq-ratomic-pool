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

      def test_circuit_breaker_fast_fails_after_threshold
        pool = build_pool(max_retries: 0, cb_threshold: 2, retry_delay: 0) { false }

        2.times { assert_raises(RuntimeError) { pool.with { :never_reached } } }

        assert_raises(Pool::CircuitOpenError) { pool.with { flunk 'circuit was not open' } }
        assert_equal :open, pool.state
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
