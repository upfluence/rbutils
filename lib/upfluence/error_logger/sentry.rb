require 'raven'

module Upfluence
  module ErrorLogger
    class Sentry
      EXCLUDED_ERRORS = (Raven::Configuration::IGNORE_DEFAULT + ['Identity::Thrift::Forbidden']).freeze

      def initialize
        ::Raven.configure do |config|
          config.dsn = ENV['SENTRY_DSN']
          config.current_environment = Upfluence.env
          config.excluded_exceptions = EXCLUDED_ERRORS
          config.logger = Upfluence.logger
          config.release = ENV['SEMVER_VERSION']
          config.server_name = ENV['UNIT_NAME']
        end
      end

      def notify(error, method, *args)
        Raven.capture_exception(
          error,
          extra: { method: method, arguments: args, environment: @env }
        )
      end

      def middleware
        ::Raven::Rack
      end
    end
  end
end
