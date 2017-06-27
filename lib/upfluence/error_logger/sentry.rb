module Upfluence
  module ErrorLogger
    class Sentry
      def initialize(env)
        @env = env
      end

      def notify(error, method, *args)
        Raven.capture_exception(
          error,
          extra: { method: method, arguments: args, environment: @env }
        )
      end
    end
  end
end
