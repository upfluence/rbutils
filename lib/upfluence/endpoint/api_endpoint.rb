require 'sinatra'

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
          content_type :json
          [200 , { status: 'OK' }.to_json]
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
                       resource.serialize(*args).to_json
                     else
                       ActiveModel::Serializer.serializer_for(resource).new(resource, *args).to_json
                     end
          end

          halt [status, result]
        end

        def json_params
          begin
            ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(request_body))
          rescue JSON::ParserError
            halt [400, { message: 'Invalid JSON' }.to_json]
          end
        end

        def request_body
          @request_body ||= request.body.read
        end
      end
    end

    Sinatra::Base.error BadRequest do
      status 400
      { error: 'Bad request' }.to_json
    end
  end
end
