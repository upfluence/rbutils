require 'spec_helper'
require 'upfluence/stats'

RSpec.describe Upfluence::Stats::Collector::Prometheus do
  let(:registry) { Prometheus::Client::Registry.new }
  let(:root) { Upfluence::Stats::RootScope.new(described_class.new(registry)) }

  it 'exports counters with the scope namespace and tags' do
    vector = root.scope('database', service: 'api').counter_vector('queries_total', %w[table])

    vector.with_labels(table: 'users').add(2)
    vector.with_labels(table: 'users').inc

    expect(registry.get(:database_queries_total).values).to eq(
      { { service: 'api', table: 'users' } => 3.0 }
    )
  end

  it 'exports gauges' do
    gauge = root.gauge('active_connections')

    gauge.update(42)

    expect(gauge.get).to eq(42.0)
    expect(registry.get(:active_connections).values).to eq({ {} => 42.0 })
  end

  it 'exports histograms with the given buckets' do
    root.scope('', env: 'test').histogram('duration_seconds', buckets: [0.1, 1]).record(0.5)

    expect(registry.get(:duration_seconds).values).to eq(
      { { env: 'test' } => { '0.1' => 0.0, '1' => 1.0, '+Inf' => 1.0, 'sum' => 0.5 } }
    )
  end

  it 'reuses a metric already registered with the same labels' do
    registry.counter(:requests_total, docstring: 'Requests', labels: %i[env])

    root.scope('', env: 'test').counter('requests_total').inc

    expect(registry.get(:requests_total).values).to eq({ { env: 'test' } => 1.0 })
  end

  it 'raises when a metric is already registered with different labels' do
    registry.counter(:requests_total, docstring: 'Requests', labels: %i[method])

    expect { root.counter('requests_total') }.to raise_error(ArgumentError)
  end

  it 'raises when a metric is already registered with another type' do
    registry.gauge(:requests_total, docstring: 'Requests')

    expect { root.counter('requests_total') }.to raise_error(ArgumentError)
  end
end
