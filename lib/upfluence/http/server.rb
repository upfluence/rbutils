require 'rack/etag'
require 'rack/timeout/base'
require 'prometheus/client'
require 'prometheus/client/push'
require 'prometheus/middleware/exporter'

require 'upfluence/environment'
require 'upfluence/error_logger'
require 'upfluence/logger'

require 'upfluence/http/builder'
require 'upfluence/http/endpoint/healthcheck'
require 'upfluence/http/endpoint/profiler'
require 'upfluence/http/middleware/logger'
require 'upfluence/http/middleware/application_headers'
require 'upfluence/http/middleware/handle_exception'
require 'upfluence/http/middleware/prometheus'
require 'upfluence/http/middleware/cors'
require 'upfluence/http/middleware/request_stapler'
require 'upfluence/instrumentation'

begin
  require 'rackup/handler'
rescue LoadError
  require 'rack/handler'
end

Rack::Timeout::Logger.disable

module Upfluence
  module HTTP
    class Server
      REQUEST_CONTEXT_KEY = :uhttp_request_context
      SHUTDOWN_SIGNALS = %w[INT TERM].freeze
      DEFAULT_MIDDLEWARES = []
      DEFAULT_OPTIONS = {
        server:                          :puma,
        Port:                            ENV.fetch('PORT', 8080),
        Host:                            '0.0.0.0',
        threaded:                        true,
        interfaces:                      [],
        push_gateway_url:                ENV.fetch('PUSH_GATEWAY_URL', nil),
        push_gateway_interval:           15, # sec
        prometheus_endpoint:             ENV.fetch('PUSH_GATEWAY_URL', nil).eql?(nil),
        app_name:                        ENV.fetch('APP_NAME', 'uhttp-rb-server'),
        unit_name:                       ENV.fetch('UNIT_NAME', 'uhttp-rb-server-anonymous'),
        base_processor_klass:            nil,
        base_handler_klass:              nil,
        max_threads:                     ENV.fetch('HTTP_SERVER_MAX_THREADS', 5).to_i,
        request_timeout:                 ENV['HTTP_SERVER_REQUEST_TIMEOUT']&.to_i,
        enable_active_record_middleware: true,
        middlewares:                     [],
        instrumentations:                [
          Instrumentation::PumaInstrumenter.new,
          Instrumentation::GCInstrumenter.new,
          Instrumentation::ActiveRecordPoolInstrumenter.new
        ],
        admin_port:                      ENV.fetch('ADMIN_PORT', nil),
        debug:                           ENV.fetch('DEBUG', nil)
      }

      def initialize(options = {}, &block)
        @options = DEFAULT_OPTIONS.dup.merge(options)
        opts = @options

        @base_handler = opts[:base_handler_klass].new(opts[:interfaces]) if opts[:base_handler_klass]

        @admin_builder = admin_builder(opts) if opts[:admin_port]
        @production_builder = production_builder(opts, &block)
        handler = defined?(Rackup::Handler) ? Rackup::Handler : Rack::Handler
        @handler = handler.get(opts[:server])
        @stoppables = []
      end

      def serve
        ENV['RACK_ENV'] = Upfluence.env.to_s
        @stopping = false
        signal_handlers = install_signal_handlers
        admin_thread = nil

        register_stoppable(prometheus_exporter_thread) if @options[:push_gateway_url]

        @options[:instrumentations].each do |instrumentation|
          instrumentation.start
          register_stoppable(instrumentation) if instrumentation.respond_to?(:stop)
        end

        if @admin_builder
          admin_port = @options[:admin_port].to_i

          admin_thread = Thread.new do
            run_builder(@admin_builder, Port: admin_port)
          end

          Upfluence.logger.info(
            "Admin server listening on #{@options[:Host]}:#{admin_port}"
          )
        end

        run_builder(@production_builder)
      ensure
        stop
        admin_thread&.join
        restore_signal_handlers(signal_handlers) if signal_handlers
      end

      class << self
        def request
          Thread.current[REQUEST_CONTEXT_KEY]
        end

        def request=(req)
          Thread.current[REQUEST_CONTEXT_KEY] = req
        end
      end

      private

      def run_builder(builder, **overrides)
        opts = @options.merge(overrides)

        @handler.run(builder, **opts) do |server|
          register_stoppable(server)
          register_booted_handler(server)
          configure_puma_instrumenter(server) if builder.equal?(@production_builder)
          server.threaded = opts[:threaded] if server.respond_to? :threaded=

          # Thin does not recognize the max_thread argument, howerver it has a
          # threadpool_size setter. Puma on the other hand recognize max_thread.
          server.threadpool_size = opts[:max_threads] if server.respond_to?(:threadpool_size=) && opts[:max_threads]
        end
      end

      def register_booted_handler(server)
        return unless server.respond_to?(:events)

        server.events.after_booted { install_signal_handlers }
      end

      def configure_puma_instrumenter(server)
        @options[:instrumentations].select { |instrumentation| instrumentation.respond_to?(:server=) }.each do |instrumentation|
          instrumentation.server = server
        end
      end

      def install_signal_handlers
        SHUTDOWN_SIGNALS.to_h do |signal|
          previous_handler = Signal.trap(signal) do
            Thread.new { stop }
          end

          [signal, previous_handler]
        end
      end

      def restore_signal_handlers(handlers)
        handlers.each { |signal, handler| Signal.trap(signal, handler) }
      end

      def register_stoppable(stoppable)
        return stoppable.stop if @stopping

        @stoppables << stoppable
      end

      def stop
        @stopping = true
        stoppables = @stoppables
        @stoppables = []

        stoppables.each(&:stop)
      end

      def prometheus_exporter_thread
        Thread.new { run_prometheus_exporter }.tap do |thread|
          thread.define_singleton_method(:stop) do
            kill
            join
          end
        end
      end

      def production_builder(opts, &block)
        has_admin = !opts[:admin_port].nil?
        builder = Builder.new

        mount_middlewares(builder, opts)

        builder.instance_eval do
          if opts[:enable_active_record_middleware] &&
             defined?(ActiveRecord::Base) &&
             ActiveRecord::Base.configurations.any?
            require 'upfluence/http/middleware/active_record'

            use Middleware::ActiveRecord
          end

          (DEFAULT_MIDDLEWARES + opts[:middlewares]).each do |m|
            m = [m] unless m.is_a?(Array)
            use(*m)
          end
        end

        mount_admin_endpoints(builder, opts) unless has_admin
        builder.instance_eval(&block)

        builder
      end

      def admin_builder(opts)
        builder = Builder.new

        mount_middlewares(builder, opts)
        mount_admin_endpoints(builder, opts)

        builder
      end

      def mount_admin_endpoints(builder, opts)
        base_handler = @base_handler

        builder.instance_eval do
          use Prometheus::Middleware::Exporter if opts[:prometheus_endpoint]

          if opts[:base_processor_klass] && base_handler
            map '/base' do
              run_thrift(opts[:base_processor_klass], base_handler)
            end
          end

          map('/debug') { run(Endpoint::Profiler.new) } if opts[:debug]
        end
      end

      def mount_middlewares(builder, opts)
        base_handler = @base_handler

        builder.instance_eval do
          use Middleware::RequestStapler, timeout: opts[:request_timeout]
          use Middleware::Logger
          use Middleware::Prometheus
          use Middleware::ApplicationHeaders, base_handler
          use Middleware::HandleException

          use Rack::Timeout, service_timeout: opts[:request_timeout] if opts[:request_timeout]

          use Upfluence.error_logger.middleware

          use Rack::ContentLength
          use Rack::Lint if Upfluence.env.development?
          use Rack::TempfileReaper
          use Rack::ETag
          use Middleware::CORS if Upfluence.env.development?
        end

        builder.instance_eval do
          map '/healthcheck' do
            run(opts[:healthcheck_endpoint] || Endpoint::Healthcheck.new)
          end
        end
      end

      def run_prometheus_exporter
        push = Prometheus::Client::Push.new(
          @options[:app_name],
          @options[:unit_name],
          @options[:push_gateway_url]
        )

        loop do
          sleep @options[:push_gateway_interval]

          begin
            push.replace Prometheus::Client.registry
          rescue StandardError => e
            Upfluence.error_logger.notify(e)
          end
        end
      end
    end
  end
end
