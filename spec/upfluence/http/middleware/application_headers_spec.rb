require 'spec_helper'
require 'rack/lint'
require 'rack/mock'
require 'upfluence/http/middleware/application_headers'

RSpec.describe Upfluence::HTTP::Middleware::ApplicationHeaders do
  let(:version) do
    double(
      semantic_version: double(major: 1, minor: 2, patch: 3),
      git_version:      nil
    )
  end
  let(:handler) { double(getName: 'analytics', getVersion: version) }

  it 'returns Rack-compliant application headers' do
    app = described_class.new(->(_env) { [200, {}, ['ok']] }, handler)
    response = Rack::MockRequest.new(Rack::Lint.new(app)).get('/')

    expect(response.status).to eq(200)
    expect(response.headers).to include(
      'x-upfluence-unit-name' => 'analytics',
      'x-upfluence-version' => 'v1.2.3'
    )
  end
end
