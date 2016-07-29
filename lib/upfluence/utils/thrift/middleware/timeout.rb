module Upfluence
  module Utils
    module Thrift
      module Middleware
        class Timeout
          def initialize(app, duration)
            @app = app
            @duration = duration
          end

          def method_missing(method, *args, &block)
            ::Timeout.timeout(@duration) { @app.send(method, *args, &block) }
          rescue ::Timeout::Error
            raise ::Thrift::ApplicationException.new(
              ::Thrift::ApplicationException::INTERNAL_ERROR,
              'Timeout reached'
            )
          end
        end
      end
    end
  end
end
