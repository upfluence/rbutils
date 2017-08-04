require 'rack/builder'
require 'thrift/server/rack_application'
require 'upfluence/utils'

module Upfluence
  module HTTP
    class Builder
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
