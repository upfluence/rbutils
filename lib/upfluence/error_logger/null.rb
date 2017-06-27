module Upfluence
  module ErrorLogger
    class Null
      class Middleware
        def initialize(app)
          @app = app
        end

        def call(env)
          @app.call(env)
        end
      end

      def notify(error, _method, *_args)
        Upfluence.logger.error(error.inspect)
      end

      def middleware
        Middleware
      end
    end
  end
end
