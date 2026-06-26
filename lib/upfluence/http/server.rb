require 'rack/handler'
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

Rack::Timeout::Logger.disable

module Upfluence
  module HTTP
    class Server
      REQUEST_CONTEXT_KEY = :uhttp_request_context
      DEFAULT_MIDDLEWARES = []
      DEFAULT_OPTIONS = {
        server:                :puma,
        Port:                  ENV.fetch('PORT', 8080),
        Host:                  '0.0.0.0',
        threaded:              true,
        interfaces:            [],
        push_gateway_url:      ENV.fetch('PUSH_GATEWAY_URL', nil),
        push_gateway_interval: 15, # sec
        prometheus_endpoint:   ENV.fetch('PUSH_GATEWAY_URL', nil).eql?(nil),
        app_name:              ENV.fetch('APP_NAME', 'uhttp-rb-server'),
        unit_name:             ENV.fetch('UNIT_NAME','uhttp-rb-server-anonymous'),
        base_processor_klass:  nil,
        base_handler_klass:    nil,
        max_threads:           ENV.fetch('HTTP_SERVER_MAX_THREADS', 5).to_i,
        request_timeout:       ENV['HTTP_SERVER_REQUEST_TIMEOUT']&.to_i,
        middlewares:           [],
        instrumentations:      [
          Instrumentation::PumaInstrumenter.new,
          Instrumentation::GCInstrumenter.new,
          Instrumentation::ActiveRecordPoolInstrumenter.new
        ],
        admin_port:            ENV.fetch('ADMIN_PORT', nil),
        debug:                 ENV.fetch('DEBUG', nil)
      }

      def initialize(options = {}, &block)
        @options = DEFAULT_OPTIONS.dup.merge(options)
        opts = @options

        if opts[:base_handler_klass]
          @base_handler = opts[:base_handler_klass].new(opts[:interfaces])
        end

        @admin_builder = admin_builder(opts) if opts[:admin_port]
        @production_builder = production_builder(opts, &block)
        @handler = Rack::Handler.get(opts[:server])
      end

      def serve
        ENV['RACK_ENV'] = Upfluence.env.to_s

        Thread.new { run_prometheus_exporter } if @options[:push_gateway_url]

        @options[:instrumentations].each(&:start)

        if @admin_builder
          admin_port = @options[:admin_port].to_i

          Thread.new do
            run_builder(@admin_builder, Port: admin_port)
          end

          Upfluence.logger.info(
            "Admin server listening on #{@options[:Host]}:#{admin_port}"
          )
        end

        run_builder(@production_builder)
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
          server.threaded = opts[:threaded] if server.respond_to? :threaded=

          # Thin does not recognize the max_thread argument, howerver it has a
          # threadpool_size setter. Puma on the other hand recognize max_thread.
          if server.respond_to?(:threadpool_size=) && opts[:max_threads]
            server.threadpool_size = opts[:max_threads]
          end
        end
      end

      def production_builder(opts, &block)
        base_handler = @base_handler
        has_admin = !opts[:admin_port].nil?
        mount = method(:mount_admin_endpoints)

        Builder.new do
          use Middleware::RequestStapler
          use Middleware::Logger
          use Middleware::Prometheus
          use Middleware::ApplicationHeaders, base_handler
          use Middleware::HandleException

          if opts[:request_timeout]
            use Rack::Timeout, service_timeout: opts[:request_timeout]
          end

          use Upfluence.error_logger.middleware

          use Rack::ContentLength
          use Rack::Chunked
          use Rack::Lint if Upfluence.env.development?
          use Rack::TempfileReaper
          use Rack::ETag
          use Middleware::CORS if Upfluence.env.development?

          (DEFAULT_MIDDLEWARES + opts[:middlewares]).each do |m|
            m = [m] unless m.is_a?(Array)
            use(*m)
          end

          mount.call(self, opts) unless has_admin

          map '/healthcheck' do
            run(opts[:healthcheck_endpoint] || Endpoint::Healthcheck.new)
          end

          instance_eval(&block)
        end
      end

      def admin_builder(opts)
        mount = method(:mount_admin_endpoints)

        Builder.new do
          use Rack::ContentLength

          map '/healthcheck' do
            run(opts[:healthcheck_endpoint] || Endpoint::Healthcheck.new)
          end

          mount.call(self, opts)
        end
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
