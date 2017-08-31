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
            unit_name: unit_name,
            unit_type: unit_type
          }.select { |_, v| !v.nil? }
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

      private

      def unit_name
        ENV['UNIT_NAME'].split('.').first if ENV['UNIT_NAME']
      end

      def unit_type
        unit_name.split('@').first if unit_name
      end
    end
  end
end
