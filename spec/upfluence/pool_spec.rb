# frozen_string_literal: true

require 'spec_helper'
require 'upfluence/pool'

RSpec.describe Upfluence::Pool do
  let(:spy_metrics) { instance_double(Upfluence::Pool::NullMetrics).as_null_object }
  let(:options) { {} }

  subject(:pool) { described_class.new(2, { metrics: spy_metrics }.merge(options), &method(:build_resource)) }

  def build_resource
    Object.new
  end

  describe 'initialize' do
    it 'calls set_size with the configured pool size' do
      pool # force evaluation
      expect(spy_metrics).to have_received(:set_size).with(2)
    end
  end

  describe '#pop' do
    context 'when a resource is available immediately (no wait)' do
      it 'calls observe_get once' do
        pool.pop
        expect(spy_metrics).to have_received(:observe_get).once
      end

      it 'does not call observe_wait' do
        pool.pop
        expect(spy_metrics).not_to have_received(:observe_wait)
      end

      it 'calls update_checkout after redeeming' do
        pool.pop
        expect(spy_metrics).to have_received(:update_checkout).with(1)
      end
    end

    context 'when a resource must be created (pool not exhausted)' do
      it 'calls observe_get once' do
        pool.pop
        expect(spy_metrics).to have_received(:observe_get).once
      end

      it 'does not call observe_wait' do
        pool.pop
        expect(spy_metrics).not_to have_received(:observe_wait)
      end
    end

    context 'when the pool is exhausted and a resource is returned while waiting' do
      it 'calls observe_wait with a positive duration' do
        r1 = pool.pop
        r2 = pool.pop

        Thread.new do
          sleep 0.05
          pool.push(r1)
        end

        pool.pop

        expect(spy_metrics).to have_received(:observe_wait).with(a_value > 0)
        pool.push(r2)
      end
    end

    context 'when the pool is exhausted and the timeout expires' do
      let(:options) { { timeout: 0.05 } }
      subject(:pool) { described_class.new(1, { metrics: spy_metrics }.merge(options), &method(:build_resource)) }
      it 'raises Timeout::Error' do
        pool.pop

        expect { pool.pop }.to raise_error(Timeout::Error)
      end

      it 'does not call observe_wait' do
        pool.pop

        expect { pool.pop }.to raise_error(Timeout::Error)
        expect(spy_metrics).not_to have_received(:observe_wait)
      end
    end
  end

  describe '#push' do
    it 'calls observe_put once' do
      r = pool.pop
      pool.push(r)
      expect(spy_metrics).to have_received(:observe_put).once
    end

    it 'calls update_idle with the new queue length' do
      r = pool.pop
      pool.push(r)
      expect(spy_metrics).to have_received(:update_idle).with(1)
    end

    it 'calls update_checkout reflecting the remaining redeemed count after each push' do
      r1 = pool.pop
      r2 = pool.pop
      pool.push(r1)
      expect(spy_metrics).to have_received(:update_checkout).with(1).at_least(:once)
      pool.push(r2)
      expect(spy_metrics).to have_received(:update_checkout).with(0).at_least(:once)
    end
  end

  describe '#discard' do
    it 'calls observe_discard once' do
      r = pool.pop
      pool.discard(r)
      expect(spy_metrics).to have_received(:observe_discard).once
    end

    it 'calls update_checkout reflecting the remaining redeemed count after each discard' do
      r1 = pool.pop
      r2 = pool.pop
      pool.discard(r1)
      expect(spy_metrics).to have_received(:update_checkout).with(1).at_least(:once)
      pool.discard(r2)
      expect(spy_metrics).to have_received(:update_checkout).with(0).at_least(:once)
    end
  end

  describe 'resource lifecycle' do
    it 'returns a newly created resource on first pop' do
      r = pool.pop
      expect(r).not_to be_nil
    end

    it 'returns the pushed resource on the next pop (LIFO)' do
      r = pool.pop
      pool.push(r)
      expect(pool.pop).to equal(r)
    end

    it 'raises UnknownResource when pushing a resource that was never redeemed' do
      expect { pool.push(Object.new) }.to raise_error(Upfluence::Pool::UnknownResource)
    end

    it 'raises UnknownResource when discarding a resource that was never redeemed' do
      expect { pool.discard(Object.new) }.to raise_error(Upfluence::Pool::UnknownResource)
    end
  end

  describe 'pool capacity' do
    it 'empty? returns false when slots are available' do
      pool.pop
      expect(pool).not_to be_empty
    end

    it 'empty? returns true when all slots are redeemed' do
      pool.pop
      pool.pop
      expect(pool).to be_empty
    end

    it 'empty? returns false after a resource is pushed back' do
      pool.pop
      r = pool.pop
      pool.push(r)
      expect(pool).not_to be_empty
    end

    it 'length decrements on each pop' do
      expect { pool.pop }.to change { pool.length }.by(-1)
    end

    it 'length increments on discard' do
      r = pool.pop
      expect { pool.discard(r) }.to change { pool.length }.by(1)
    end

    it 'raises Timeout::Error when exhausted and deadline expires' do
      exhausted_pool = described_class.new(1, timeout: 0.05, &method(:build_resource))
      exhausted_pool.pop
      expect { exhausted_pool.pop }.to raise_error(Timeout::Error)
    end
  end

  describe 'context timeout integration' do
    require 'upfluence/context'

    subject(:pool) { described_class.new(1, { metrics: spy_metrics }.merge(options), &method(:build_resource)) }

    context 'when the context timeout is shorter than the pool timeout' do
      let(:options) { { timeout: 5 } }

      it 'raises Timeout::Error within the context deadline' do
        pool.pop

        elapsed = nil

        Upfluence.context.with_timeout(0.05) do
          t0 = Time.now
          expect { pool.pop }.to raise_error(Timeout::Error)
          elapsed = Time.now - t0
        end

        expect(elapsed).to be < 1
      end
    end

    context 'when the pool timeout is shorter than the context timeout' do
      let(:options) { { timeout: 0.05 } }

      it 'raises Timeout::Error within the pool deadline' do
        pool.pop

        elapsed = nil

        Upfluence.context.with_timeout(5) do
          t0 = Time.now
          expect { pool.pop }.to raise_error(Timeout::Error)
          elapsed = Time.now - t0
        end

        expect(elapsed).to be < 1
      end
    end
  end
end
