require 'spec_helper'
require 'upfluence/instrumentation/puma_instrumenter'

RSpec.describe Upfluence::Instrumentation::PumaInstrumenter do
  subject(:values) { instrumenter.values }

  let(:instrumenter) { described_class.allocate }
  let(:server) { instance_double(Puma::Launcher) }

  before { instrumenter.server = server }

  it 'omits unavailable stats' do
    allow(server).to receive(:stats).and_return(
      requests_count: 12,
      backlog:       nil,
      running:       4
    )

    expect(values).to eq(
      requests_count: [{ value: 12 }],
      running_thread: [{ value: 4 }]
    )
  end

  it 'does not report global Puma stats before the server is configured' do
    allow(Puma).to receive(:stats_hash)
    instrumenter.server = nil

    expect(values).to eq({})
    expect(Puma).not_to have_received(:stats_hash)
  end
end
