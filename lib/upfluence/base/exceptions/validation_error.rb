require 'thrift/exceptions'
require 'base/exceptions/exceptions_types'

module Base
  module Exceptions
    class ValidationError < ::Thrift::Exception
      class << self
        attr_accessor :domain

        def from_model(model)
          validation_errors = model.errors.details.map do |error_field, errors|
            errors.map do |error|
              Base::Exceptions::Validation.new(
                domain: domain,
                model: model.model_name.singular,
                field: error_field.to_s,
                error: error[:error].to_s
              )
            end
          end.flatten

          new(validations: validation_errors)
        end
      end

      def to_json
        {
          errors: validations.map do |v|
            { resource: v.model, field: v.field, code: v.error }
          end
        }.to_json
      end
    end
  end
end
