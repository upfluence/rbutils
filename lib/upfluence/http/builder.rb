require 'rack/builder'
require 'thrift/server/rack_application'
require 'upfluence/http/middleware/mount_point'
require 'upfluence/utils'

module Upfluence
  module HTTP
    class Builder < Rack::Builder
      def map(path, &block)
        super(path) do
          use Middleware::MountPoint, self
          instance_eval(&block)
        end
      end

      def endpoint
        @run
      end

      def run_thrift(processor, handler, timeout = 30)
        run Thrift::RackApplication.for(
          '/',
          processor.new(
            Upfluence::Utils::Thrift::Middleware.setup(handler, timeout)
          ),
          Thrift::BinaryProtocolFactory.new
        )
      end
    end
  end
end
