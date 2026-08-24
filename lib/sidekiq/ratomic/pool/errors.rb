# frozen_string_literal: true

# Sidekiq integration namespace.
module Sidekiq
  # Ratomic-backed Sidekiq middleware namespace.
  module Ratomic
    class Pool
      # Base error for pool failures.
      class Error < StandardError; end

      # Raised when the circuit breaker is open.
      class CircuitOpenError < Error; end
    end
  end
end
