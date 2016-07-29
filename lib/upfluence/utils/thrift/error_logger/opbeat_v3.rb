module Upfluence
  module Utils
    module Thrift
      module ErrorLogger
        class OpbeatV3 < OpbeatV2
          def notify(error, method, *args)
            @client.report(
              error,
              extra: {
                method: method,
                arguments: args,
                environment: @env
              }
            )
          end
        end
      end
    end
  end
end
