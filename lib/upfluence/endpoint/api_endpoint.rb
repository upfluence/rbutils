module Upfluence
  module Endpoint
    class ApiEndpoint < Sinatra::Base
      class BadRequest < StandardError; end

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
    end
  end
end
