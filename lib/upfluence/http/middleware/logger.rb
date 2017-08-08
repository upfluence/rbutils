require 'rack/body_proxy'

module Upfluence
  module HTTP
    module Middleware
      class Logger
        def initialize(app)
          @app = app
        end

        def call(env)
          began_at = Time.now
          status, header, body = @app.call(env)
          header = Rack::Utils::HeaderHash.new(header)
          body = Rack::BodyProxy.new(body) do
            log(env, status, header, began_at)
          end
          [status, header, body]
        end

        private

        def log(env, status, _header, began_at)
          now = Time.now

          Upfluence.logger.info(
            "%d %s %s%s (%s) %.2fms" % [
              status, env[Rack::REQUEST_METHOD],
              env[Rack::PATH_INFO],
              env[Rack::QUERY_STRING].empty? ? "" : "?"+env[Rack::QUERY_STRING],
              env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"] || "-",
              (now - began_at) * 1000
            ]
          )
        end
      end
    end
  end
end
