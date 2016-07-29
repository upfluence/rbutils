require 'upfluence/utils/thrift/middleware/error_catcher'
require 'upfluence/utils/thrift/middleware/request_logger'
require 'upfluence/utils/thrift/middleware/timeout'

module Upfluence
  module Utils
    module Thrift
      module Middleware
        class << self
          def setup(handler, logger, error_logger, timeout)
            ErrorCatcher.new(
              Timeout.new(
                RequestLogger.new(
                  handler,
                  logger
                ),
                timeout
              ),
              error_logger
            )
          end
        end
      end
    end
  end
end
