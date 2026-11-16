require 'spec_helper'
require 'rack/mock'
require 'sinatra/base'
require 'upfluence/http/builder'
require 'upfluence/http/route_resolver'

RSpec.describe Upfluence::HTTP::RouteResolver do
  let(:resolved) { [] }

  let(:recorder) do
    Class.new do
      def initialize(app, resolved)
        @app = app
        @resolved = resolved
      end

      def call(env)
        @app.call(env).tap do |status, _headers, _body|
          @resolved << [
            Upfluence::HTTP::RouteResolver.resolve(env, status),
            Upfluence::HTTP::RouteResolver.resolve(env)
          ]
        end
      end
    end
  end

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
    rec = recorder
    res = resolved
    gate = short_circuit
    reset_password = reset_password_endpoint
    files = files_endpoint
    root = root_endpoint

    Upfluence::HTTP::Builder.new do
      use rec, res

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

  shared_examples 'a resolved route' do |method, path, want:, want_without_code: want, short_circuit: nil|
    via = short_circuit ? " short-circuited with #{short_circuit}" : ''

    it "resolves #{method} #{path}#{via} as #{want} (#{want_without_code} without code)" do
      headers = short_circuit ? { 'HTTP_X_SHORT_CIRCUIT' => short_circuit } : {}

      Rack::MockRequest.new(app).request(method, path, headers)

      expect(resolved).to eq([[want, want_without_code]])
    end
  end

  context 'when sinatra matches the route' do
    it_behaves_like 'a resolved route', 'GET', '/api/v1/reset_password/abc',
                    want: '/api/v1/reset_password/:token'

    it_behaves_like 'a resolved route', 'POST', '/api/v1/reset_password/request',
                    want: '/api/v1/reset_password/request'

    it_behaves_like 'a resolved route', 'GET', '/api/v1/files/a/b/c',
                    want: '/api/v1/files/*'
  end

  context 'when the request is short-circuited before sinatra' do
    it_behaves_like 'a resolved route', 'POST', '/api/v1/reset_password/abc',
                    short_circuit: '429',
                    want:          '/api/v1/reset_password/:token'

    it_behaves_like 'a resolved route', 'POST', '/api/v1/reset_password/abc',
                    short_circuit: '500',
                    want:          '/api/v1/reset_password/:token'

    it_behaves_like 'a resolved route', 'PUT', '/api/v1/reset_password/ping',
                    short_circuit: '429',
                    want:          '/api/v1/reset_password/ping'

    it_behaves_like 'a resolved route', 'GET', '/api/v1/reset_password/a/b',
                    short_circuit: '429',
                    want:          '/api/v1/reset_password/*'
  end

  context 'when no route matches' do
    it_behaves_like 'a resolved route', 'GET', '/api/v1/reset_password/a/b',
                    want:              'unexpected-route',
                    want_without_code: '/api/v1/reset_password/*'

    it_behaves_like 'a resolved route', 'GET', '/api/v1/unknown',
                    want:              'unexpected-route',
                    want_without_code: '/api/v1/*'
  end

  context 'when the endpoint is not a sinatra app' do
    it_behaves_like 'a resolved route', 'GET', '/healthcheck',
                    want: '/healthcheck'
  end

  context 'when the sinatra endpoint is run at the root' do
    it_behaves_like 'a resolved route', 'GET', '/users/42',
                    want: '/users/:id'
  end

  context 'when the request is not mounted' do
    let(:env) { Rack::MockRequest.env_for('/orders/12/items/3') }

    it 'replaces the numeric segments' do
      expect(described_class.resolve(env, '200')).to eq('/orders/:id/items/:id')
    end
  end

  context 'when rails routed the request' do
    let(:env) do
      Rack::MockRequest.env_for(
        '/users/42',
        'action_dispatch.request.parameters' => {
          'controller' => 'users',
          'action'     => 'show'
        }
      )
    end

    it 'resolves the controller and action' do
      expect(described_class.resolve(env, '200')).to eq('users#show')
    end
  end
end
