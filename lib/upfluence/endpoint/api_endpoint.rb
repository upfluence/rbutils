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
                     elsif resource.respond_to?(:serialize)
                       resource.serialize.to_json
                     else
                       ActiveModel::Serializer.serializer_for(resource).new(resource).to_json
                     end
          end
          halt [status, result] || 404
        end

        def json_params
          begin
            ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(request.body.read))
          rescue
            halt 400, { message: 'Invalid JSON' }.to_json
          end
        end
      end
    end

    Sinatra::Base.error BadRequest do
      status 400
      { error: 'Bad request' }.to_json
    end
  end
end
