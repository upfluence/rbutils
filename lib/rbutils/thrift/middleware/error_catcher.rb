module RbUtils
  module Thrift
    module Middleware
      class ErrorCatcher
        def initialize(app, error_logger)
          @app = app
          @error_logger = error_logger
        end

        def method_missing(method, *args, &block)
          @app.send(method, *args, &block)
        rescue ::Thrift::Exception => e
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
