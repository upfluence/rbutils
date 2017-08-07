require 'rack/handler'
require 'rack/etag'

require 'upfluence/environment'
require 'upfluence/error_logger'

require 'upfluence/http/builder'
require 'upfluence/http/endpoint/healthcheck'
require 'upfluence/http/middleware/logger'
require 'upfluence/http/middleware/application_headers'
require 'upfluence/http/middleware/handle_exception'
require 'upfluence/handler/base'

module Upfluence
  module HTTP
    class Server
      DEFAULT_OPTIONS = {
        server: :thin,
        Port: ENV['PORT'] || 8080,
        Host: '0.0.0.0',
        threaded: true,
        interfaces: []
      }.freeze

      def initialize(options = {}, &block)
        @options = DEFAULT_OPTIONS.dup.merge(options)
        opts = @options
        base_handler = Handler::Base.new(opts[:interfaces])

        @builder = Builder.new do
          use Middleware::Logger
          use Middleware::ApplicationHeaders, base_handler
          use Middleware::HandleException
          use Upfluence.error_logger.middleware
          use Rack::ContentLength
          use Rack::Chunked
          use Rack::Lint if Upfluence.env.development?
          use Rack::TempfileReaper
          use Rack::ETag

          map '/healthcheck'  do
            run(opts[:healthcheck_endpoint] || Endpoint::Healthcheck.new)
          end

          map '/base' do
            run_thrift Base::BaseService::Processor, base_handler
          end

          instance_eval(&block)
        end

        @handler = Rack::Handler.get(@options[:server])

        if @options[:server] == :thin
          require 'thin/logging'

          Thin::Logging.silent = true
        end
      end

      def serve
        ENV['RACK_ENV'] = Upfluence.env.to_s
        @handler.run(@builder, @options) do |server|
          server.threaded = @options[:threaded] if server.respond_to? :threaded=

          if server.respond_to?(:threadpool_size=) && @options[:threadpool_size]
            server.threadpool_size = @options[:threadpool_size]
          end
        end
      end
    end
  end
end
