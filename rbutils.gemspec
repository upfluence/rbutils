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
  spec.required_ruby_version = '>= 2.7.0'

  spec.add_development_dependency "bundler", ">= 2.2"
  spec.add_development_dependency "rake", ">= 13.0.0"
  spec.add_development_dependency "rspec", ">= 3.10"
  spec.add_runtime_dependency 'upfluence-thrift'
  spec.add_runtime_dependency 'sinatra'
  spec.add_runtime_dependency 'redis'
  spec.add_runtime_dependency 'sentry-ruby'
  spec.add_runtime_dependency 'sinatra-contrib'
  spec.add_runtime_dependency 'activesupport'
  spec.add_runtime_dependency 'puma'
  spec.add_runtime_dependency 'rack'
  spec.add_runtime_dependency 'stackprof'
  spec.add_runtime_dependency 'prometheus-client', '~> 2.1'
  spec.add_runtime_dependency 'userializer'
  spec.add_runtime_dependency 'activerecord'
  spec.add_runtime_dependency 'loofah'
end
