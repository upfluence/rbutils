module Upfluence
  module HTTP
    module Middleware
      class HandleException
        def initialize(app)
          @app = app
        end

        def call(env)
          @app.call(env)
        rescue StandardError, LoadError, SyntaxError => e
          [500, {}, ["{\"error\": \"#{e.class.name}\"}"]]
        end
      end
    end
  end
end
