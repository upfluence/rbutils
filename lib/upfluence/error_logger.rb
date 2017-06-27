require 'upfluence/error_logger/sentry'
require 'upfluence/error_logger/null'

module Upfluence
  class << self
    def error_logger
      @error_logger ||= if ENV['SENTRY_DSN']
                          ErrorLogger::Sentry.new
                        else
                          ErrorLogger::Null.new
                        end
    end
  end
end
