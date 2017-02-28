module Baes
  module Exceptions
    class ValidationError
      class << self
        attr_accessor :domain

        def from_model(model)
         validation_errors = []

         model.errors.details.map do |error_field, errors|
           errors.map do |error|
             validation_errors << Base::Exceptions::Validation.new(
               domain: self.domain,
               model: model.model_name.singular,
               field: error_field.to_s,
               error: error[:error].to_s
             )
           end
         end

         self.new(validations: validation_errors)
        end
      end
    end
  end
end
