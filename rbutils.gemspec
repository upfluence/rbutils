# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'upfluence/utils/version'

Gem::Specification.new do |spec|
  spec.name          = 'upfluence-utils'
  spec.version       = Upfluence::Utils::VERSION
  spec.authors       = ['Upfluence']
  spec.email         = ['dev@upfluence.com']

  spec.summary       = 'Upfluence common utils for Ruby projects'
  spec.homepage      = 'https://github.com/upfluence/rbutils'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_runtime_dependency 'upfluence-thrift', '~> 1.0', '>= 1.0.3'
  spec.add_runtime_dependency 'active_model_serializers'
end
