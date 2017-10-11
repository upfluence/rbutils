require 'base/exceptions/exceptions_types'
require 'active_record/errors'

module Upfluence
  module Utils
    module Thrift
      module Middleware
        class ActiveRecord
          def initialize(app)
            @app = app
          end

          def method_missing(method, *args, &block)
            @app.send(method, *args, &block)
          rescue ActiveRecord::RecordInvalid => e
            raise Base::Exceptions::ValidationError.from_model(e.record)
          rescue ActiveRecord::RecordNotFound
            raise Base::Exceptions::NotFound
          end
        end
      end
    end
  end
end
