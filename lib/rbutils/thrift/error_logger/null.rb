module RbUtils
  module Thrift
    module Middleware
      module ErrorLogger
        class Null
          def notify(_error, _method, *args)
          end
        end
      end
    end
  end
end
