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
          config.release = "#{ENV['PROJECT_NAME']}-#{ENV['SEMVER_VERSION']}"
          config.tags = {
            unit_name: ENV['UNIT_NAME'],
            unit_type: ENV['UNIT_NAME'].split('@').first
          }
        end
      end

      def notify(error, method, *args)
        Raven.capture_exception(
          error,
          extra: { method: method, arguments: args },
          tags: { method: method }
        )
      end

      def middleware
        ::Raven::Rack
      end
    end
  end
end
