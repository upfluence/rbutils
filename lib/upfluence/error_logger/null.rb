module Upfluence
  module ErrorLogger
    class Null
      class Middleware
        def initialize(app)
          @app = app
        end

        def call(env)
          @app.call(env)
        rescue => e
          notify(error)

          raise e
        end
      end

      def notify(error, *_args)
        Upfluence.logger.error("Error: #{error.class}: #{error.message}")
        Upfluence.logger.error("Inspect: #{error.inspect}")

        error.backtrace.each do |b|
          Upfluence.logger.error("\t#{b}")
        end
      end

      def ignore_exception(*_kls); end

      def user=(_user); end

      def middleware
        Middleware
      end
    end
  end
end
