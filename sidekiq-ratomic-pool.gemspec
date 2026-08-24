# frozen_string_literal: true

require_relative 'lib/sidekiq/ratomic/pool/version'

Gem::Specification.new do |spec|
  spec.name = 'sidekiq-ratomic-pool'
  spec.version = Sidekiq::Ratomic::Pool::VERSION
  spec.authors = ['Ken C. Demanawa']
  spec.email = ['kenneth.c.demanawa@gmail.com']

  spec.summary = "Ractor-safe connection pooling for Sidekiq utilizing Ratomic's LocalPool."
  spec.description = <<~DESC
    Thread and Ractor safe connection pooling utilizing Ratomic's LocalPool for Sidekiq middleware
    with health validation, exponential retries, and circuit breakers.
  DESC
  spec.homepage = 'https://kanutocd.github.io/sidekiq-ratomic-pool'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 4.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/kanutocd/sidekiq-ratomic-pool'
  spec.metadata['changelog_uri'] = "#{spec.metadata['source_code_uri']}/blob/main/CHANGELOG.md"
  spec.metadata['documentation_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir[
    'lib/**/*.rb',
    'sig/**/*.rbs',
    'smoke_test/**/*.rb',
    'README.md',
    'CHANGELOG.md',
    'LICENSE.txt'
  ]

  spec.add_dependency 'ratomic', '~> 0.4.3'
end
