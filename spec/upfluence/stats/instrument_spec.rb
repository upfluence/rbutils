require 'spec_helper'
require 'upfluence/stats'

RSpec.describe Upfluence::Stats::Instrument do
  let(:collector) { Upfluence::Stats::Collector::Static.new }
  let(:scope) { Upfluence::Stats::RootScope.new(collector).scope('worker') }
  let(:opts) { {} }

  subject(:instrument) { described_class.new(scope, 'job', **opts) }

  def counters
    collector.snapshot.counters.map { |s| [s.name, s.labels, s.value] }
  end

  def durations
    collector.snapshot.histograms.map { |s| [s.name, s.labels, s.count] }
  end

  describe '#exec' do
    it 'records a success and returns the block value' do
      expect(instrument.exec { 42 }).to eq(42)

      expect(counters).to eq(
        [
          ['worker_job_started_total', {}, 1],
          ['worker_job_total', { status: 'success' }, 1]
        ]
      )
      expect(durations).to eq([['worker_job_duration_seconds', {}, 1]])
    end

    it 'records a failure and re-raises the error' do
      expect { instrument.exec { raise 'boom' } }.to raise_error(RuntimeError, 'boom')

      expect(counters).to eq(
        [
          ['worker_job_started_total', {}, 1],
          ['worker_job_total', { status: 'failed' }, 1]
        ]
      )
    end

    context 'with custom options' do
      let(:opts) do
        {
          track_started:  false,
          track_duration: false,
          counter_label:  'result',
          formatter:      ->(error) { error ? error.class.name : 'ok' }
        }
      end

      it 'uses the formatter and label and skips the disabled metrics' do
        instrument.exec { nil }
        expect { instrument.exec { raise ArgumentError } }.to raise_error(ArgumentError)

        expect(counters).to eq(
          [
            ['worker_job_total', { result: 'ArgumentError' }, 1],
            ['worker_job_total', { result: 'ok' }, 1]
          ]
        )
        expect(durations).to eq([])
      end
    end
  end

  describe '#start' do
    it 'records the operation once finished' do
      operation = instrument.start

      expect(counters).to eq([['worker_job_started_total', {}, 1]])

      operation.finish(RuntimeError.new)

      expect(counters).to eq(
        [
          ['worker_job_started_total', {}, 1],
          ['worker_job_total', { status: 'failed' }, 1]
        ]
      )
    end
  end

  describe Upfluence::Stats::InstrumentVector do
    it 'adds the label values as tags' do
      vector = described_class.new(scope, 'query', %w[table])

      vector.with_labels(table: 'users').exec { nil }

      expect(counters).to eq(
        [
          ['worker_query_started_total', { table: 'users' }, 1],
          ['worker_query_total', { table: 'users', status: 'success' }, 1]
        ]
      )
    end
  end
end
