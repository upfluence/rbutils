require 'spec_helper'
require 'upfluence/stats'

RSpec.describe Upfluence::Stats::Timer do
  let(:collector) { Upfluence::Stats::Collector::Static.new }
  let(:scope) { Upfluence::Stats::RootScope.new(collector) }

  def durations
    collector.snapshot.histograms.map { |s| [s.name, s.labels, s.count] }
  end

  describe '#time' do
    it 'records the duration and returns the block value' do
      expect(described_class.new(scope, 'op').time { :done }).to eq(:done)

      expect(durations).to eq([['op_seconds', {}, 1]])
    end

    it 'records the duration when the block raises' do
      timer = described_class.new(scope, 'op', suffix: '_duration', buckets: [1])

      expect { timer.time { raise 'boom' } }.to raise_error(RuntimeError)

      expect(durations).to eq([['op_duration', {}, 1]])
    end
  end

  describe '#start' do
    it 'records the duration once stopped' do
      stop_watch = described_class.new(scope, 'op').start

      expect(durations).to eq([['op_seconds', {}, 0]])

      stop_watch.stop

      expect(durations).to eq([['op_seconds', {}, 1]])
    end
  end

  describe Upfluence::Stats::TimerVector do
    it 'adds the label values as tags' do
      vector = described_class.new(scope, 'op', %w[kind])

      vector.with_labels(kind: 'a').time { nil }
      vector.with_labels(kind: 'a').time { nil }
      vector.with_labels(kind: 'b').time { nil }

      expect(durations).to eq([['op_seconds', { kind: 'a' }, 2], ['op_seconds', { kind: 'b' }, 1]])
    end
  end
end
