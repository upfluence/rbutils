# frozen_string_literal: true

require 'spec_helper'
require 'upfluence/context'

RSpec.describe Upfluence::Context do
  subject(:context) { described_class.new }

  describe '#deadline' do
    it { expect(context.deadline).to be_nil }
  end

  describe '#timeout' do
    it { expect(context.timeout).to be_nil }

    context 'with a deadline set' do
      before { context.with_deadline(Time.now + 10) { @timeout = context.timeout } }

      it { expect(@timeout).to be_within(0.1).of(10.0) }
    end
  end

  describe '#with_deadline' do
    let(:deadline) { Time.now + 30 }

    it 'sets the deadline within the block' do
      context.with_deadline(deadline) do
        expect(context.deadline).to eq(deadline)
      end
    end

    it 'restores the previous deadline after the block' do
      context.with_deadline(deadline) {}

      expect(context.deadline).to be_nil
    end

    it 'restores the deadline even when the block raises' do
      context.with_deadline(deadline) { raise 'boom' } rescue nil

      expect(context.deadline).to be_nil
    end

    context 'when a deadline is already set' do
      let(:outer) { Time.now + 60 }

      it 'uses the earlier deadline by default' do
        context.with_deadline(outer) do
          context.with_deadline(deadline) do
            expect(context.deadline).to eq(deadline)
          end
        end
      end

      it 'keeps the outer deadline when it is earlier' do
        context.with_deadline(deadline) do
          context.with_deadline(outer) do
            expect(context.deadline).to eq(deadline)
          end
        end
      end

      it 'overrides regardless when override: true' do
        context.with_deadline(deadline) do
          context.with_deadline(outer, override: true) do
            expect(context.deadline).to eq(outer)
          end
        end
      end

      it 'restores the outer deadline after the block' do
        context.with_deadline(outer) do
          context.with_deadline(deadline) {}

          expect(context.deadline).to eq(outer)
        end
      end
    end
  end

  describe '#with_timeout' do
    it 'sets a deadline relative to now within the block' do
      context.with_timeout(10) do
        expect(context.timeout).to be_within(0.1).of(10.0)
      end
    end

    it 'restores the previous deadline after the block' do
      context.with_timeout(10) {}

      expect(context.deadline).to be_nil
    end

    context 'when a shorter deadline is already set' do
      it 'keeps the shorter existing deadline' do
        context.with_timeout(5) do
          context.with_timeout(30) do
            expect(context.timeout).to be_within(0.1).of(5.0)
          end
        end
      end
    end

    context 'with override: true' do
      it 'sets the deadline regardless of existing deadline' do
        context.with_timeout(5) do
          context.with_timeout(30, override: true) do
            expect(context.timeout).to be_within(0.1).of(30.0)
          end
        end
      end
    end
  end
end

RSpec.describe Upfluence do
  describe '.context' do
    subject { described_class.context }

    it { is_expected.to be_a(Upfluence::Context) }

    it 'returns the same instance within the same thread' do
      expect(described_class.context).to equal(described_class.context)
    end

    it 'returns a different instance in a different thread' do
      other = Thread.new { described_class.context }.value

      expect(other).not_to equal(described_class.context)
    end
  end

  describe 'thread wrapper' do
    it 'propagates the deadline to child threads' do
      deadline = Time.now + 30

      described_class.context.with_deadline(deadline) do
        child_deadline = Upfluence::Thread.new { described_class.context.deadline }.value

        expect(child_deadline).to eq(deadline)
      end
    end

    it 'does not propagate deadline to child threads when none is set' do
      child_deadline = Upfluence::Thread.new { described_class.context.deadline }.value

      expect(child_deadline).to be_nil
    end

    it 'does not leak the deadline back to the parent after the child exits' do
      deadline = Time.now + 30

      described_class.context.with_deadline(deadline) do
        Upfluence::Thread.new { described_class.context.with_deadline(Time.now + 999) {} }.join
      end

      expect(described_class.context.deadline).to be_nil
    end
  end
end
