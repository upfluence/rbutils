require 'active_support/string_inquirer'

module Upfluence
  def env
    @env ||= ActiveSupport::StringInquirer.new(
      ENV.fetch('ENV', 'development')
    )
  end
end
