module Upfluence
  module Endpoint

    class BadRequest < StandardError; end

    class ApiEndpoint < Sinatra::Base
      disable :show_exceptions

      configure :development do
        require 'sinatra/reloader'
        register Sinatra::Reloader
      end

      configure :test do
        enable :raise_errors
      end

      helpers do
        def ok
          status 200
          content_type :json
          { status: 'OK' }.to_json
        end

        def respond_with(resource, *args)
          if resource.respond_to?(:errors) && resource.errors.any?
            status = 422
            result = { errors: resource.errors }.to_json
          else
            status = 200
            result = if resource.is_a? Enumerable
                       ActiveModel::ArraySerializer.new(
                           resource, *args
                       ).to_json
                     else
                       resource.serialize.to_json
                     end
          end
          halt [status, result] || 404
        end
      end

      def json_params
        begin
          JSON.parse(request.body.read).with_indifferent_access
        rescue
          halt 400, { message: 'Invalid JSON' }.to_json
        end
      end

      def render_errors(model)
        render json: { errors: model.errors }, status: :unprocessable_entity
      end
    end
  end
end
