module Upfluence
  module Utils
    module Thrift
      module ErrorLogger
        class Null
          def notify(_error, _method, *args)
          end
        end
      end
    end
  end
end
