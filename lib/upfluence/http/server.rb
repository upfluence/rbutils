require 'rack/handler'
require 'rack/etag'
require 'prometheus/client'
require 'prometheus/client/push'
require "prometheus/middleware/exporter"

require 'upfluence/environment'
require 'upfluence/error_logger'

require 'upfluence/http/builder'
require 'upfluence/http/endpoint/healthcheck'
require 'upfluence/http/endpoint/profiler'
require 'upfluence/http/middleware/logger'
require 'upfluence/http/middleware/application_headers'
require 'upfluence/http/middleware/handle_exception'
require 'upfluence/http/middleware/prometheus'
require 'upfluence/http/middleware/cors'
require 'upfluence/http/middleware/request_stapler'

module Upfluence
  module HTTP
    class Server
      REQUEST_CONTEXT_KEY = :uhtt_request_context
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
        debug:                 ENV.fetch('DEBUG', nil)
      }

      def initialize(options = {}, &block)
        @options = DEFAULT_OPTIONS.dup.merge(options)
        opts = @options
        base_handler = nil

        if opts[:base_handler_klass]
          base_handler = opts[:base_handler_klass].new(@options[:interfaces])
        end

        @builder = Builder.new do
          use Middleware::RequestStapler
          use Middleware::Logger
          use Middleware::Prometheus
          use Prometheus::Middleware::Exporter if opts[:prometheus_endpoint]
          use Middleware::ApplicationHeaders, base_handler
          use Middleware::HandleException
          use Upfluence.error_logger.middleware
          use Rack::ContentLength
          use Rack::Chunked
          use Rack::Lint if Upfluence.env.development?
          use Rack::TempfileReaper
          use Rack::ETag
          use Middleware::CORS if Upfluence.env.development?

          DEFAULT_MIDDLEWARES.each do |m|
            m = [m] unless m.is_a?(Array)
            use(*m)
          end

          map '/healthcheck' do
            run(opts[:healthcheck_endpoint] || Endpoint::Healthcheck.new)
          end

          if opts[:base_processor_klass] && base_handler
            map '/base' do
              run_thrift(opts[:base_processor_klass], base_handler)
            end
          end

          map('/debug') { run(Endpoint::Profiler.new) } if opts[:debug]

          instance_eval(&block)
        end

        @handler = Rack::Handler.get(@options[:server])
      end

      def serve
        ENV['RACK_ENV'] = Upfluence.env.to_s

        Thread.new { run_prometheus_exporter } if @options[:push_gateway_url]

        @handler.run(@builder, **@options) do |server|
          server.threaded = @options[:threaded] if server.respond_to? :threaded=

          if server.respond_to?(:threadpool_size=) && @options[:threadpool_size]
            server.threadpool_size = @options[:threadpool_size]
          end
        end
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
