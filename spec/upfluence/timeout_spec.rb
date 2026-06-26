# frozen_string_literal: true

require 'spec_helper'
require 'upfluence/timeout'

RSpec.describe Upfluence::Timeout do
  describe '.timeout' do
    subject(:call) { described_class.timeout(sec, &block) }

    let(:block) { ->(_sec) { :ok } }

    context 'with no context deadline' do
      let(:sec) { 5 }

      it { is_expected.to eq(:ok) }

      it 'uses the requested duration' do
        expect(::Timeout).to receive(:timeout).with(5, nil, nil)

        call
      end
    end

    context 'with a context deadline shorter than the requested duration' do
      let(:sec) { 30 }

      before { Upfluence.context.with_deadline(Time.now + 5) { @result = described_class.timeout(sec, &block) } }

      it 'uses the context timeout' do
        expect(::Timeout).to receive(:timeout).with(be_within(0.1).of(5.0), nil, nil)

        Upfluence.context.with_deadline(Time.now + 5) { call }
      end
    end

    context 'with a context deadline longer than the requested duration' do
      let(:sec) { 5 }

      it 'uses the requested duration' do
        expect(::Timeout).to receive(:timeout).with(5, nil, nil)

        Upfluence.context.with_deadline(Time.now + 30) { call }
      end
    end

    context 'with a custom exception class' do
      let(:sec) { 5 }
      let(:klass) { Class.new(StandardError) }

      it 'passes it through to Timeout' do
        expect(::Timeout).to receive(:timeout).with(5, klass, nil)

        described_class.timeout(sec, klass, &block)
      end
    end

    context 'with a custom message' do
      let(:sec) { 5 }

      it 'passes it through to Timeout' do
        expect(::Timeout).to receive(:timeout).with(5, nil, 'too slow')

        described_class.timeout(sec, nil, 'too slow', &block)
      end
    end

    context 'when the timeout fires' do
      let(:sec) { 0.01 }
      let(:block) { ->(_sec) { sleep 1 } }

      it 'raises Timeout::Error' do
        expect { call }.to raise_error(::Timeout::Error)
      end
    end

    context 'when effective timeout is already 0' do
      let(:sec) { 30 }
      let(:block) { ->(_sec) { :ok } }

      it 'raises Timeout::Error immediately' do
        expect {
          Upfluence.context.with_deadline(Time.now - 1) { call }
        }.to raise_error(::Timeout::Error)
      end

      context 'with a custom exception class' do
        let(:klass) { Class.new(StandardError) }

        it 'raises the custom class immediately' do
          expect {
            Upfluence.context.with_deadline(Time.now - 1) do
              described_class.timeout(sec, klass, &block)
            end
          }.to raise_error(klass)
        end
      end
    end
  end
end
