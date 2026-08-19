module Upfluence
  module HTTP
    module Middleware
      class ActiveRecord
        def initialize(app)
          @app = app
        end

        def call(env)
          ::ActiveRecord::Base.connection_pool.with_connection do
            @app.call(env)
          end
        end
      end
    end
  end
end
