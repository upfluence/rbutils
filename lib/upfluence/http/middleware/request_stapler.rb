require 'upfluence/context'

module Upfluence
  module HTTP
    module Middleware
      class RequestStapler
        def initialize(app, timeout: nil)
          @timeout = timeout
          @app = app
        end

        def call(env)
          Server.request = Rack::Request.new(env)

          return @app.call(env) unless @timeout

          Upfluence.context.with_timeout(@timeout) { @app.call(env) }
        end
      end
    end
  end
end
