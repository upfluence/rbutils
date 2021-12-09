module Upfluence
  module Utils
    module Thrift
      module Middleware
        class ErrorCatcher
          STANDARD_THRIFT_EXCEPTIONS = [
            ::Thrift::ApplicationException,
            ::Thrift::TransportException,
            ::Thrift::ProtocolException
          ].freeze

          def initialize(app, error_logger)
            @app = app
            @error_logger = error_logger
          end

          def method_missing(method, *args, &block)
            @app.send(method, *args, &block)
          rescue ::Thrift::Exception => e
            if STANDARD_THRIFT_EXCEPTIONS.include? e.class
              @error_logger.notify(e, method, *args)
            end

            raise e
          rescue => e
            @error_logger.notify(e, method, *args)

            raise ::Thrift::ApplicationException.new(
              ::Thrift::ApplicationException::INTERNAL_ERROR,
              e.to_s
            )
          end
        end
      end
    end
  end
end
