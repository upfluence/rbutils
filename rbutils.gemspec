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

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_runtime_dependency 'upfluence-thrift', '~> 1.0', '>= 1.0.3'
  spec.add_runtime_dependency 'base-thrift', '>= 0.1.0'
  spec.add_runtime_dependency 'sinatra'
  spec.add_runtime_dependency 'redis'
  spec.add_runtime_dependency 'sentry-raven'
  spec.add_runtime_dependency 'sinatra-contrib'
  spec.add_runtime_dependency 'activesupport'
  spec.add_runtime_dependency 'puma'
  spec.add_runtime_dependency 'rack'
  spec.add_runtime_dependency 'stackprof'
  spec.add_runtime_dependency 'prometheus-client'
  spec.add_runtime_dependency 'active_model_serializers', '~> 0.9.0'
end
