module Upfluence
  module HTTP
    module Middleware
      class RequestStapler
        def initialize(app)
          @app = app
        end

        def call(env)
          Server.request = Rack::Request.new(env)
          @app.call(env)
        end
      end
    end
  end
end
