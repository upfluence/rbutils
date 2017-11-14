require 'raven'

module Upfluence
  module ErrorLogger
    class Sentry
      EXCLUDED_ERRORS = (Raven::Configuration::IGNORE_DEFAULT + ['Identity::Thrift::Forbidden']).freeze
      SCALAR_TYPES = [String, Fixnum, Integer, Numeric, Float, NilClass, Hash, Symbol, Array, Range].freeze

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
        begin
          Raven.capture_exception(
            error,
            extra: { method: method, arguments: format_arguments(args) },
            tags: { method: method }
          )
        rescue Raven::Error => e
          Upfluence.logger.error e.message
        end
      end

      def user=(user)
        Raven.user_context(id: user.id, email: user.email)
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

      def format_arguments(*args)
        return [] if args.empty?

        args.map do |a|
          if SCALAR_TYPES.include? a.class
            { type: a.class, value: a }
          else
            value = Hash[a.instance_variables.map do |name|
              [name[1..-1], instance_variable_get(name)]
            end]

            { type: a.class, value: value }
          end
        end
      end
    end
  end
end
