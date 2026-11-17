require 'spec_helper'
require 'upfluence/stats'

RSpec.describe Upfluence::Stats::Scope do
  let(:collector) { Upfluence::Stats::Collector::Static.new }
  let(:root) { Upfluence::Stats::RootScope.new(collector) }

  def value(name, labels, v)
    Upfluence::Stats::Collector::Static::ValueSnapshot.new(name: name, labels: labels, value: v)
  end

  describe '#counter' do
    it 'registers the counter under the root namespace' do
      root.counter('requests_total').add(3)

      expect(collector.snapshot.counters).to eq([value('requests_total', {}, 3)])
    end

    it 'returns the same counter when registered twice' do
      root.counter('requests_total').inc
      root.counter('requests_total').inc

      expect(collector.snapshot.counters).to eq([value('requests_total', {}, 2)])
    end
  end

  describe '#scope' do
    it 'nests namespaces and merges tags, the child overriding the parent' do
      db = root.scope('database', service: 'user-api', env: 'staging')
      redis = db.scope('redis', cluster: 'cache-01', env: 'production')

      redis.counter('queries_total').inc

      expect(redis.namespace).to eq('database_redis')
      expect(collector.snapshot.counters).to eq(
        [
          value(
            'database_redis_queries_total',
            { service: 'user-api', env: 'production', cluster: 'cache-01' },
            1
          )
        ]
      )
    end

    it 'keeps the parent namespace when the child namespace is empty' do
      root.scope('database').scope('', shard: 1).gauge('connections').update(4)

      expect(collector.snapshot.gauges).to eq(
        [value('database_connections', { shard: '1' }, 4)]
      )
    end

    it 'shares the registry with the parent scope' do
      root.scope('', region: 'eu').counter('jobs_total').inc
      root.scope('', region: 'us').counter('jobs_total').add(2)

      expect(collector.snapshot.counters).to eq(
        [value('jobs_total', { region: 'eu' }, 1), value('jobs_total', { region: 'us' }, 2)]
      )
    end
  end

  describe '#root_scope' do
    it 'drops the namespace and tags' do
      root.scope('database', service: 'api').root_scope.counter('requests_total').inc

      expect(collector.snapshot.counters).to eq([value('requests_total', {}, 1)])
    end
  end

  describe '#counter_vector' do
    it 'appends the label values to the scope tags' do
      vector = root.scope('http', env: 'test').counter_vector('requests_total', %w[method status])

      vector.with_labels(method: 'GET', status: 200).inc
      vector.with_labels(method: 'POST', status: 201).add(2)

      expect(collector.snapshot.counters).to eq(
        [
          value('http_requests_total', { env: 'test', method: 'GET', status: '200' }, 1),
          value('http_requests_total', { env: 'test', method: 'POST', status: '201' }, 2)
        ]
      )
    end

    it 'accepts the same labels in a different order' do
      root.counter_vector('requests_total', %w[method status]).with_labels(method: 'GET', status: 200).inc
      root.counter_vector('requests_total', %i[status method]).with_labels('status' => 200, method: 'GET').inc

      expect(collector.snapshot.counters).to eq(
        [value('requests_total', { method: 'GET', status: '200' }, 2)]
      )
    end

    context 'with invalid label values' do
      let(:vector) { root.counter_vector('requests_total', %w[method status]) }

      shared_examples 'an invalid label set' do
        it 'raises an ArgumentError' do
          expect { with_labels }.to raise_error(ArgumentError)
        end
      end

      context 'when a label is missing' do
        subject(:with_labels) { vector.with_labels(method: 'GET') }

        it_behaves_like 'an invalid label set'
      end

      context 'when a label is unknown' do
        subject(:with_labels) { vector.with_labels(method: 'GET', code: '200') }

        it_behaves_like 'an invalid label set'
      end

      context 'when an extra label is given' do
        subject(:with_labels) { vector.with_labels(method: 'GET', status: '200', code: '200') }

        it_behaves_like 'an invalid label set'
      end

      context 'when the values are positional' do
        subject(:with_labels) { vector.with_labels('GET', '200') }

        it_behaves_like 'an invalid label set'
      end
    end
  end

  describe '#histogram' do
    it 'records the values in the given buckets' do
      histogram = root.scope('http').histogram('duration_seconds', buckets: [0.1, 1])

      [0.05, 0.5, 5].each { |v| histogram.record(v) }

      expect(collector.snapshot.histograms).to eq(
        [
          Upfluence::Stats::Collector::Static::HistogramSnapshot.new(
            name:    'http_duration_seconds',
            labels:  {},
            count:   3,
            sum:     5.55,
            buckets: [[0.1, 1], [1, 1], [Float::INFINITY, 1]].map do |upper_bound, count|
              Upfluence::Stats::Collector::Static::Bucket.new(upper_bound: upper_bound, count: count)
            end
          )
        ]
      )
    end
  end

  describe 'registration conflicts' do
    it 'raises when the name is used by another metric type' do
      root.counter('requests')

      expect { root.gauge('requests') }.to raise_error(ArgumentError, /counter with the same name/)
    end

    it 'raises when the name is used with different labels' do
      root.counter('requests')

      expect { root.scope('', env: 'test').counter('requests') }.to raise_error(
        ArgumentError, /different labels/
      )
    end

    it 'raises when a label collides with a scope tag' do
      expect do
        root.scope('', env: 'test').counter_vector('requests', %w[env])
      end.to raise_error(ArgumentError, /duplicated labels/)
    end
  end
end
