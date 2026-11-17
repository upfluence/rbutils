require 'spec_helper'
require 'upfluence/instrumentation/periodic_instrumenter'

RSpec.describe Upfluence::Instrumentation::PeriodicInstrumenter do
  let(:collector) { Upfluence::Stats::Collector::Static.new }
  let(:scope) { Upfluence::Stats::RootScope.new(collector).scope('app', env: 'test') }

  let(:klass) do
    Class.new(described_class) do
      def prefix
        'queue'
      end

      def metrics
        { depth: { labels: %i[queue] }, workers: {} }
      end

      def values
        {
          depth:   [{ value: 3, labels: { queue: 'mail' } }, { value: 5, labels: { queue: 'sms' } }],
          workers: [{ value: 2 }]
        }
      end
    end
  end

  def gauge(name, labels, value)
    Upfluence::Stats::Collector::Static::ValueSnapshot.new(name: name, labels: labels, value: value)
  end

  describe '#collect' do
    it 'updates the gauges under the scope and prefix' do
      klass.new(scope: scope).collect

      expect(collector.snapshot.gauges).to eq(
        [
          gauge('app_queue_depth', { env: 'test', queue: 'mail' }, 3),
          gauge('app_queue_depth', { env: 'test', queue: 'sms' }, 5),
          gauge('app_queue_workers', { env: 'test' }, 2)
        ]
      )
    end
  end
end
