require 'rbutils/thrift/middleware/error_catcher'
require 'rbutils/thrift/middleware/request_logger'
require 'rbutils/thrift/middleware/timeout'

module RbUtils
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
