require 'spec_helper'
require 'rack/lint'
require 'rack/mock'
require 'upfluence/http/endpoint/api_endpoint'

RSpec.describe Upfluence::HTTP::Endpoint::APIEndpoint do
  let(:app) do
    Class.new(described_class) do
      post '/' do
        json_params.to_json
      end
    end
  end

  it 'parses JSON after Sinatra reads the request parameters' do
    response = Rack::MockRequest.new(Rack::Lint.new(app)).post(
      '/',
      'CONTENT_TYPE' => 'application/json',
      input:          '{"foo":"bar"}'
    )

    expect(response.status).to eq(200)
    expect(JSON.parse(response.body)).to eq('foo' => 'bar')
  end

  it 'runs in the Upfluence environment' do
    expect(described_class.environment).to eq(Upfluence.env.to_sym)
  end
end
