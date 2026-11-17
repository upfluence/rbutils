require 'spec_helper'
require 'rack/mock'
require 'upfluence/http/middleware/prometheus'

RSpec.describe Upfluence::HTTP::Middleware::Prometheus do
  let(:registry) { Prometheus::Client::Registry.new }
  let(:app) { described_class.new(->(_env) { [201, {}, ['ok']] }, registry) }
  let(:labels) { { path: '/users/:id', method: 'post', env: Upfluence.env.to_s } }

  before { Rack::MockRequest.new(app).post('/users/42') }

  it 'counts the request under its resolved route and status' do
    expect(registry.get(:uhttp_handler_requests_total).values).to eq(
      labels.merge(status: '201') => 1.0
    )
  end

  it 'observes the request duration under its resolved route' do
    expect(
      registry.get(:uhttp_handler_requests_duration_second).values.keys
    ).to eq([labels])
  end
end
