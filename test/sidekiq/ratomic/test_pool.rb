# frozen_string_literal: true

require 'test_helper'

module Sidekiq
  module Ratomic
    class TestPool < Minitest::Test
      def test_that_it_has_a_version_number
        refute_nil ::Sidekiq::Ratomic::Pool::VERSION
      end
    end
  end
end
