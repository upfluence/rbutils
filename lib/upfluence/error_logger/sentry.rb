require 'sentry-ruby'

module Upfluence
  module ErrorLogger
    class Sentry
      EXCLUDED_ERRORS = (::Sentry::Configuration::IGNORE_DEFAULT + ['Identity::Thrift::Forbidden'])
      MAX_TAG_SIZE = 8 * 1024

      def initialize
        @tag_extractors = []

        ::Sentry.init do |config|
          config.send_default_pii = true
          config.dsn = ENV['SENTRY_DSN']
          config.environment = Upfluence.env
          config.excluded_exceptions = EXCLUDED_ERRORS
          config.logger = Upfluence.logger
          config.release = "#{ENV['PROJECT_NAME']}-#{ENV['SEMVER_VERSION']}"
          config.enable_tracing = false
          config.auto_session_tracking = false
        end

        ::Sentry.set_tags(
          { unit_name: unit_name, unit_type: unit_type }.select { |_, v| v }
        )

        ::Sentry.with_scope do |scope|
          scope.add_event_processor do |event, _hint|
            tags = @tag_extractors.map(&:extract).compact.reduce({}, &:merge)

            tx_name = transaction_name(tags)

            event.transaction = tx_name if tx_name
            event.extra.merge!(prepare_extra(tags))

            event
          end
        end
      end

      def append_tag_extractors(klass)
        @tag_extractors << klass
      end

      def notify(error, *args)
        ::Sentry.with_scope do |scope|
          context = args.reduce({}) do |acc, arg|
            v = arg.is_a?(Hash) ? arg : { "arg_#{acc.length}" => arg.inspect }

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
        ::Sentry::Rack::CaptureExceptions
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
    end
  end
end
