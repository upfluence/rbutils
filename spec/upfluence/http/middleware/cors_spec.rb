require 'spec_helper'
require 'rack/lint'
require 'rack/mock'
require 'upfluence/http/middleware/cors'

RSpec.describe Upfluence::HTTP::Middleware::CORS do
  it 'returns Rack-compliant CORS headers' do
    app = described_class.new(->(_env) { [200, {}, ['ok']] })
    response = Rack::MockRequest.new(Rack::Lint.new(app)).options('/')

    expect(response.status).to eq(200)
    expect(response.headers).to include(
      'access-control-allow-origin' => '*',
      'access-control-allow-headers' => 'Authorization, Content-Type, Scope, X-Upfluence-Plugin-Version',
      'access-control-allow-methods' => 'GET, POST, PUT, OPTIONS, DELETE'
    )
  end
end
