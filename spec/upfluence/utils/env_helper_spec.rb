# frozen_string_literal: true

require 'spec_helper'
require 'upfluence/utils/env_helper'

RSpec.describe Upfluence::Utils::EnvHelper do
  describe '.env_to_bool' do
    subject { described_class.env_to_bool(value, strict: strict) }

    let(:strict) { false }

    context 'with a truthy value' do
      %w[t true yes y 1 on TRUE].each do |v|
        context "value=#{v}" do
          let(:value) { v }

          it { is_expected.to eq(true) }
        end
      end
    end

    context 'with a falsy value' do
      %w[f false no n 0 off FALSE].each do |v|
        context "value=#{v}" do
          let(:value) { v }

          it { is_expected.to eq(false) }
        end
      end
    end

    context 'with an unknown value' do
      let(:value) { 'maybe' }

      it { is_expected.to eq(true) }

      context 'with strict: true' do
        let(:strict) { true }

        it { is_expected.to be_nil }
      end
    end

    context 'with an empty value' do
      let(:value) { '' }

      it { is_expected.to eq(false) }

      context 'with strict: true' do
        let(:strict) { true }

        it { is_expected.to be_nil }
      end
    end
  end
end
