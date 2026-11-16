require 'spec_helper'
require 'rack/mock'
require 'sinatra/base'
require 'upfluence/http/builder'
require 'upfluence/http/middleware/prometheus'

RSpec.describe Upfluence::HTTP::Middleware::Prometheus do
  let(:registry) { Prometheus::Client::Registry.new }

  let(:short_circuit) do
    Class.new do
      def initialize(app)
        @app = app
      end

      def call(env)
        status = env['HTTP_X_SHORT_CIRCUIT']
        return [status.to_i, {}, []] if status

        @app.call(env)
      end
    end
  end

  let(:base_endpoint) do
    Class.new(Sinatra::Base) do
      put('/ping') { 'pong' }
    end
  end

  let(:reset_password_endpoint) do
    Class.new(base_endpoint) do
      get('/:token') { 'ok' }
      post('/request') { 204 }
      post('/:token') { 'ok' }
    end
  end

  let(:files_endpoint) do
    Class.new(Sinatra::Base) do
      get('/*') { 'ok' }
    end
  end

  let(:root_endpoint) do
    Class.new(Sinatra::Base) do
      get('/users/:id') { 'ok' }
    end
  end

  let(:app) do
    prometheus = described_class
    reg = registry
    gate = short_circuit
    reset_password = reset_password_endpoint
    files = files_endpoint
    root = root_endpoint

    Upfluence::HTTP::Builder.new do
      use prometheus, reg

      map '/api/v1' do
        map '/reset_password' do
          use gate
          run reset_password
        end

        map('/files') { run files }
      end

      map('/healthcheck') { run ->(_env) { [200, {}, ["ok\n"]] } }

      run root
    end
  end

  shared_examples 'a recorded route' do |method, path, want_path:, want_status:, short_circuit: nil|
    it "labels #{method} #{path} (#{want_status}) as #{want_path}" do
      headers = short_circuit ? { 'HTTP_X_SHORT_CIRCUIT' => short_circuit } : {}

      Rack::MockRequest.new(app).request(method, path, headers)

      expect(registry.get(:uhttp_handler_requests_total).values.keys).to eq(
        [
          {
            path:   want_path,
            method: method.downcase,
            env:    Upfluence.env.to_s,
            status: want_status
          }
        ]
      )
    end
  end

  context 'when sinatra matches the route' do
    it_behaves_like 'a recorded route', 'GET', '/api/v1/reset_password/abc',
                    want_path:   '/api/v1/reset_password/:token',
                    want_status: '200'

    it_behaves_like 'a recorded route', 'POST', '/api/v1/reset_password/request',
                    want_path:   '/api/v1/reset_password/request',
                    want_status: '204'

    it_behaves_like 'a recorded route', 'GET', '/api/v1/files/a/b/c',
                    want_path:   '/api/v1/files/*',
                    want_status: '200'
  end

  context 'when the request is short-circuited before sinatra' do
    it_behaves_like 'a recorded route', 'POST', '/api/v1/reset_password/abc',
                    short_circuit: '429',
                    want_path:     '/api/v1/reset_password/:token',
                    want_status:   '429'

    it_behaves_like 'a recorded route', 'POST', '/api/v1/reset_password/abc',
                    short_circuit: '500',
                    want_path:     '/api/v1/reset_password/:token',
                    want_status:   '500'

    it_behaves_like 'a recorded route', 'PUT', '/api/v1/reset_password/ping',
                    short_circuit: '429',
                    want_path:     '/api/v1/reset_password/ping',
                    want_status:   '429'

    it_behaves_like 'a recorded route', 'GET', '/api/v1/reset_password/a/b',
                    short_circuit: '429',
                    want_path:     '/api/v1/reset_password/*',
                    want_status:   '429'
  end

  context 'when no route matches' do
    it_behaves_like 'a recorded route', 'GET', '/api/v1/reset_password/a/b',
                    want_path:   'unexpected-route',
                    want_status: '404'

    it_behaves_like 'a recorded route', 'GET', '/api/v1/unknown',
                    want_path:   'unexpected-route',
                    want_status: '404'
  end

  context 'when the endpoint is not a sinatra app' do
    it_behaves_like 'a recorded route', 'GET', '/healthcheck',
                    want_path:   '/healthcheck',
                    want_status: '200'
  end

  context 'when the sinatra endpoint is run at the root' do
    it_behaves_like 'a recorded route', 'GET', '/users/42',
                    want_path:   '/users/:id',
                    want_status: '200'
  end
end
