# frozen_string_literal: true

# Minimal host-owned Ractor integration example. The host creates and joins
# Ractors; each Ractor constructs its own middleware runtime and owns its pool.

require 'sidekiq/ratomic/pool'

HostResource = Data.define(:ractor_index)
HostFactory = Data.define(:ractor_index) do
  def call
    HostResource.new(ractor_index)
  end
end
HostInput = Data.define(:index, :threads, :jobs, :pool_size)

ractor_count = Integer(ENV.fetch('RACTOR_NATIVE_COUNT', '4'))
threads_per_ractor = Integer(ENV.fetch('RACTOR_NATIVE_THREADS', '20'))
pool_size = Integer(ENV.fetch('RATOMIC_POOL_SIZE', '20'))
jobs_per_ractor = Integer(ENV.fetch('BENCHMARK_JOBS_PER_RACTOR', '20'))

ractors = ractor_count.times.map do |index|
  input = Ractor.make_shareable(HostInput.new(index, threads_per_ractor, jobs_per_ractor, pool_size))
  Ractor.new(input) do |ractor_input|
    factory = HostFactory.new(ractor_input.index)
    pool = Sidekiq::Ratomic::Pool.new(
      pool_name: :resource,
      size: ractor_input.pool_size,
      factory:
    )
    jobs = Queue.new
    ractor_input.jobs.times { |job| jobs << job }
    threads = ractor_input.threads.times.map do
      Thread.new do
        loop do
          jobs.pop(true)
        rescue ThreadError
          break
        else
          pool.with do |resource|
            raise 'invalid resource' unless resource.ractor_index == ractor_input.index
          end
        end
      end
    end
    threads.each(&:value)
    pool.close
    { index: ractor_input.index, jobs: ractor_input.jobs, threads: ractor_input.threads }
  end
end

results = ractors.map(&:value)
puts "Host-owned Ractor example passed: #{results.inspect}"
