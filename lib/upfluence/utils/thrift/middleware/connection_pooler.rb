require 'active_record/base'

module Upfluence
  module Utils
    module Thrift
      module Middleware
        class ConnectionPooler
          def initialize(app)
            @app = app
          end

          def method_missing(method, *args, &block)
            ActiveRecord::Base.connection_pool.with_connection do
              @app.send(method, *args, &block)
            end
          end
        end
      end
    end
  end
end
