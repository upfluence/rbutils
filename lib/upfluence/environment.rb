require 'active_support/string_inquirer'

module Upfluence
  class << self
    def env
      @env ||= ActiveSupport::StringInquirer.new(
        ENV['ENV'] || ENV['RACK_ENV'] || 'development'
      )
    end
  end
end
