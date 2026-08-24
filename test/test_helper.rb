# frozen_string_literal: true

require 'simplecov'

SimpleCov.start do
  enable_coverage :branch
  track_files 'lib/**/*.rb'
  add_filter '/test/'
  minimum_coverage line: 99, branch: 99
end

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'minitest/autorun'
require 'sidekiq/ratomic/pool'
