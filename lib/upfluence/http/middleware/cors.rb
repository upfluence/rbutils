module Upfluence
  module HTTP
    module Middleware
      class CORS
        HEADERS = {
          'Access-Control-Allow-Origin' => '*',
          'Access-Control-Allow-Headers' => 'Authorization, Content-Type, Scope, X-Upfluence-Plugin-Version',
          'Access-Control-Allow-Methods' => 'GET, POST, PUT, OPTIONS, DELETE'
        }.freeze

        def initialize(app, headers = nil)
          @app = app
          @headers = headers || HEADERS
        end

        def call(env)
          status, headers, body = options?(env) ? default_response : @app.call(env)
          [status, merge_headers(headers), body]
        end

        private

        def default_response
          [200, {}, ['']]
        end

        def options?(env)
          Rack::Request.new(env).options?
        end

        def merge_headers(headers)
          headers.merge(@headers) { |_, x, _| x }
        end
      end
    end
  end
end
