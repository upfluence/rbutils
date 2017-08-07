require 'sinatra'
require 'upfluence/http/endpoint/api_endpoint'

module Upfluence
  module Endpoint
    ApiEndpoint = HTTP::Endpoint::APIEndpoint
  end
end
