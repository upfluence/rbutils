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
          Upfluence.logger.error("Error: #{e.class}: #{e.message}")
          e.backtrace.each do |b|
            Upfluence.logger.error("\t#{b}")
          end

          raise e
        end
      end

      def notify(error, *_args)
        Upfluence.logger.error(error.inspect)
      end

      def ignore_exception(*_kls); end

      def user=(_user); end

      def middleware
        Middleware
      end
    end
  end
end
