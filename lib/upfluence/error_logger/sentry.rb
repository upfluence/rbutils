require 'sentry-ruby'
require 'upfluence/environment'
require 'upfluence/logger'

module Upfluence
  module ErrorLogger
    class Sentry
      EXCLUDED_ERRORS = (
        ::Sentry::Configuration::IGNORE_DEFAULT + [
          'ActiveRecord::RecordNotFound',
          'ActiveRecord::ConcurrentMigrationError'
        ]
      )

      class << self
        def exception_name_lambda(level, name)
          lambda do |exception|
            level if exception.class.name.eql? name
          end
        end

        def exception_message_lambda(level, message)
          downcased_message = message.downcase

          lambda do |exception|
            level if exception.message.downcase.include?(downcased_message)
          end
        end
      end

      DEFAULT_LEVEL_PROCS = [
        exception_name_lambda(:warning, 'Net::ReadTimeout'),
        exception_name_lambda(:warning, 'EOFError'),
        exception_name_lambda(:warning, 'ActiveRecord::QueryCanceled'),
        exception_name_lambda(:warning, 'Timeout::Error'),
        exception_name_lambda(:warning, 'Errno::ECONNRESET'),
        exception_name_lambda(:warning, 'OAuth2::ConnectionError'),
        exception_message_lambda(:warning, 'Connection reset by peer'),
        exception_message_lambda(:warning, 'Connection refused'),
        exception_message_lambda(:warning, 'connection refused'),
        exception_message_lambda(:warning, 'Failed to open TCP connection'),
        exception_message_lambda(:warning, 'Net::ReadTimeout')
      ].freeze
      MAX_TAG_SIZE = 8 * 1024

      def initialize
        @tag_extractors = []
        @level_procs = [*DEFAULT_LEVEL_PROCS]

        ::Sentry.init do |config|
          config.send_default_pii = true
          config.dsn = ENV.fetch('SENTRY_DSN', nil)
          config.environment = Upfluence.env
          config.excluded_exceptions = EXCLUDED_ERRORS
          config.sdk_logger = Upfluence.logger
          config.release = "#{ENV.fetch('PROJECT_NAME', nil)}-#{ENV.fetch('SEMVER_VERSION', nil)}"
          config.enable_tracing = false
          config.auto_session_tracking = false
        end

        ::Sentry.set_tags(
          { unit_name: unit_name, unit_type: unit_type }.select { |_, v| v }
        )

        ::Sentry.with_scope do |scope|
          scope.add_event_processor do |event, hint|
            tags = @tag_extractors.map(&:extract).compact.reduce({}, &:merge)

            exc = hint[:exception]

            tags.merge!(exc.tags) if exc.respond_to? :tags

            tx_name = transaction_name(tags)

            event.transaction = tx_name if tx_name
            event.extra.merge!(prepare_extra(tags))

            event.level = compute_exception_level(exc)

            event
          end
        end
      end

      def append_tag_extractors(klass)
        @tag_extractors << klass
      end

      # proc must accept an exception and return either a sentry level (:error, :warning, etc.)
      # or nil if the exception is not matched
      def append_level_procs(proc)
        @level_procs << proc
      end

      def notify(error, *args)
        ::Sentry.with_scope do |scope|
          context = args.reduce({}) do |acc, arg|
            v = if arg.is_a?(Hash)
                  arg.transform_keys(&:to_s).transform_values(&:inspect)
                else
                  key = acc.empty? ? 'method' : "arg_#{acc.length}"
                  { key => arg.inspect }
                end

            acc.merge(v)
          end

          scope.set_extras(prepare_extra(context))

          ::Sentry.capture_exception(error)
        end
      rescue ::Sentry::Error => e
        Upfluence.logger.warning e.message
      end

      def user=(user)
        ::Sentry.set_user(id: user.id, email: user.email)
      end

      def middleware
        RackMiddleware
      end

      def ignore_exception(*klss)
        klss.each do |kls|
          case kls.class
          when Class
            ::Sentry.configuration.excluded_exceptions << kls.name
          when String
            ::Sentry.configuration.excluded_exceptions << kls
          else
            Upfluence.logger.warn "Unexcepted argument for ignore_exception #{kls}"
          end
        end
      end

      class RackMiddleware < ::Sentry::Rack::CaptureExceptions
        def capture_exception(exception, env)
          if env.key?('sinatra.error') && Sinatra::Base.errors.keys.any? do |klass|
            klass.is_a?(Class) && !klass.eql?(Exception) && exception.is_a?(klass)
          end
            return
          end

          super
        end
      end

      private

      def prepare_extra(tags)
        tags.select { |_k, v| v.respond_to?(:size) && v.size < MAX_TAG_SIZE }
      end

      def transaction_name(tags)
        return tags['transaction'] if tags['transaction']

        svc = tags['thrift.request.service']
        mth = tags['thrift.request.method']

        return "#{svc}##{mth}" if svc && mth

        nil
      end

      def unit_name
        ENV['UNIT_NAME']&.split('.')&.first
      end

      def unit_type
        unit_name&.split('@')&.first
      end

      def compute_exception_level(exception)
        return :error if exception.nil?

        @level_procs.each do |lvp|
          level = lvp.call(exception)

          next if level.nil?

          return level
        end

        :error
      end
    end
  end
end
