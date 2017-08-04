require 'rack/handler'

require 'upfluence/env'
require 'upfluence/error_logger'

require 'upfluence/http/builder'
require 'upfluence/http/endpoint/healthcheck'
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

      def new(options = {}, &block)
        @options = DEFAULT_OPTIONS.dup.merge(options)
        @builder = Builder.new do
          use Rack::CommonLogger, Upfluence.logger
          use Upfluence.error_logger.middleware
          use Rack::ContentLength
          use Rack::Chunked

          if Upfluence.env.development?
            use Rack::ShowExceptions
            use Rack::Lint
          end

          use Rack::TempfileReaper
          use Rack::Etag

          map('/healthcheck') { run Endpoint::Healthcheck }
          map '/base' do
            run_thrift(
              Base::BaseService::Processor,
              Handler::Base.new(@options[:interfaces])
            )
          end

          block.call
        end

        @handler = Rack::Handler.get(@options[:server])

        if @options[:server] == :thin
          require 'thin/logger'

          Thin::Logging.trace_logger = Upfluence.logger
          Thin::Logging.logger = Upfluence.logger
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
