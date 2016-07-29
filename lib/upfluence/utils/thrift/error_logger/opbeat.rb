module Upfluence
  module Utils
    module Thrift
      module ErrorLogger
        class Opbeat
          def initialize(client, env)
            @client = client
            @env = env
          end

          def notify(error, method, *args)
            @client.capture_exception(
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
