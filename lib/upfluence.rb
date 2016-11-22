require 'upfluence/utils'
require 'upfluence/endpoint/api_endpoint'
require 'upfluence/polyfill/active_model_serializers' unless ActiveModel::Serializer.respond_to?('serializer_for')
