require 'upfluence/utils/thrift/middleware/error_catcher'
require 'upfluence/utils/thrift/middleware/request_logger'
require 'upfluence/utils/thrift/middleware/timeout'

module Upfluence
  module Utils
    module Thrift
      module Middleware
        class << self
          def setup(handler, timeout = 30)
            ErrorCatcher.new(
              Timeout.new(
                RequestLogger.new(handler, Upfluence.logger), timeout
              ),
              Upfluence.error_logger
            )
          end
        end
      end
    end
  end
end
