module Upfluence
  module HTTP
    module Endpoint
      class Healthcheck
        def call(_env)
          [200, {}, ["ok\n"]]
        end
      end
    end
  end
end
