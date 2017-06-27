require 'upfluence/utils/error_logger/opbeat_v2'
require 'upfluence/utils/error_logger/opbeat_v3'
require 'upfluence/utils/error_logger/sentry'
require 'upfluence/utils/error_logger/null'

module Upfluence
  def error_logger
    @error_logger ||= if ENV['SENTRY_DSN']
                        ErrorLogger::Sentry.new(env)
                      else
                        ErrorLogger::Null.new
                      end
  end
end
