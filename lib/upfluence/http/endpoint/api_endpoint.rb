require 'sinatra'

module Upfluence
  module HTTP
    module Endpoint
      class BadRequest < StandardError; end
      class APIEndpoint < Sinatra::Base
        disable :show_exceptions
        disable :logging
        disable :dump_errors

        enable :raise_errors

        before { content_type :json }

        configure :development do
          require 'sinatra/reloader'
          register Sinatra::Reloader
        end

        configure :test do
          enable :raise_errors
        end

        helpers do
          def ok
            [200, { status: 'OK' }.to_json]
          end

          def access_token
            token = params[:access_token]

            unless token
              pattern      = /^Bearer /
              header       = request.env['HTTP_AUTHORIZATION']
              token = header.gsub(pattern, '') if header && header.match(pattern)
            end

            token
          end

          def respond_with(resource, *args)
            if resource.respond_to?(:errors) && resource.errors.any?
              status = 422
              result = Base::Exceptions::ValidationError.from_model(
                resource
              ).to_json
            else
              status = 200
              opts = args.first || {}

              result = if resource.is_a? Enumerable
                         ActiveModel::ArraySerializer.new(resource, *args).to_json
                       elsif opts[:serializer]
                         opts[:serializer].new(resource, *args).to_json
                       elsif resource.respond_to?(:serialize)
                         resource.serialize(*args).to_json
                       else
                         ActiveModel::Serializer.serializer_for(resource).new(resource, *args).to_json
                       end
            end

            halt [status, result]
          end

          def json_params
            ActiveSupport::HashWithIndifferentAccess.new(JSON.parse(request_body))
          end
        end

        def request_body
          @request_body ||= request.body.read
        end
      end

      Sinatra::Base.error BadRequest do
        [400, {}, { error: 'bad_request' }.to_json]
      end

      Sinatra::Base.error JSON::ParserError do
        [400, {}, { message: 'invalid_json' }.to_json]
      end

      Sinatra::Base.not_found do
        [404, {}, { error: 'not_found' }.to_json]
      end
    end
  end
end
