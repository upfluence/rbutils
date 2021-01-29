module Upfluence
  module HTTP
    module Endpoint
      class ValidationError
        def initialize(validations)
          @validations = validations
        end

        class << self
          def from_model(model)
            validations = model.errors.details.map do |error_field, errors|
              errors.map do |error|
                OpenStruct.new(
                  ressource: model.model_name.singular,
                  field:     error_field.to_s,
                  code:      error[:error].to_s
                )
              end
            end.flatten

            new(validations)
          end
        end

        def to_json
          { errors: @validations }.to_json
        end
      end
    end
  end
end
