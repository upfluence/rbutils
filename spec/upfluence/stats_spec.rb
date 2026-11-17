require 'spec_helper'
require 'upfluence/stats'

RSpec.describe Upfluence::Stats do
  describe '.root_scope' do
    around do |example|
      previous = described_class.instance_variable_get(:@root_scope)
      example.run
    ensure
      described_class.root_scope = previous
    end

    it 'defaults to a memoized scope backed by the prometheus registry' do
      described_class.root_scope = nil

      expect(described_class.root_scope).to be_a(Upfluence::Stats::RootScope)
      expect(described_class.root_scope).to be(described_class.root_scope)
    end

    it 'can be overridden' do
      scope = Upfluence::Stats::RootScope.new(Upfluence::Stats::Collector::Static.new)

      described_class.root_scope = scope

      expect(described_class.root_scope).to be(scope)
    end
  end

  describe 'NOOP_SCOPE' do
    it 'exposes the scope interface without recording anything' do
      scope = Upfluence::Stats::NOOP_SCOPE.scope('database', env: 'test').root_scope

      scope.counter('c').inc
      scope.counter_vector('c', %w[a]).with_labels(a: 'x').add(2)
      scope.gauge('g').update(1)
      scope.histogram_vector('h', %w[a]).with_labels(a: 'x').record(1)

      expect(scope.counter('c').get).to eq(0)
      expect(Upfluence::Stats::Instrument.new(scope, 'op').exec { 1 }).to eq(1)
    end
  end
end
