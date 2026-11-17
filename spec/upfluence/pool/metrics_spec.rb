require 'spec_helper'
require 'upfluence/pool'

RSpec.describe Upfluence::Pool::Metrics do
  let(:registry) { Prometheus::Client::Registry.new }
  let(:scope) { Upfluence::Stats::RootScope.new(Upfluence::Stats::Collector::Prometheus.new(registry)) }

  shared_examples 'pool metrics' do |prefix, labels|
    before do
      metrics.set_size(4)
      metrics.observe_get
      metrics.observe_put
      metrics.observe_discard
      metrics.observe_wait(0.25)
      metrics.update_idle(2)
      metrics.update_checkout(1)
    end

    it 'exports the pool metrics' do
      expect(
        %w[
          get_total put_total discard_total get_wait_total
          get_wait_millisecond_total idle checkout size
        ].to_h { |name| [name, registry.get(:"#{prefix}_#{name}").values] }
      ).to eq(
        'get_total'                  => { labels => 1.0 },
        'put_total'                  => { labels => 1.0 },
        'discard_total'              => { labels => 1.0 },
        'get_wait_total'             => { labels => 1.0 },
        'get_wait_millisecond_total' => { labels => 250.0 },
        'idle'                       => { labels => 2.0 },
        'checkout'                   => { labels => 1.0 },
        'size'                       => { labels => 4.0 }
      )
    end
  end

  describe '.standardized_metrics' do
    subject(:metrics) { described_class.standardized_metrics('redis', scope: scope) }

    it_behaves_like 'pool metrics', 'upfluence_iopool_pool', { pool: 'redis' }
  end

  describe Upfluence::Pool::PrometheusMetrics do
    subject(:metrics) { described_class.new(registry, 'uthrift_client_pool', { target: 'svc', incarnation: 1 }) }

    it_behaves_like 'pool metrics', 'uthrift_client_pool', { target: 'svc', incarnation: '1' }

    it 'reuses the metrics already registered for the same prefix' do
      metrics.observe_get
      described_class.new(registry, 'uthrift_client_pool', { target: 'svc', incarnation: 2 }).observe_get

      expect(registry.get(:uthrift_client_pool_get_total).values).to eq(
        { target: 'svc', incarnation: '1' } => 1.0,
        { target: 'svc', incarnation: '2' } => 1.0
      )
    end
  end
end
