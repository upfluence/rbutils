# frozen_string_literal: true

require 'timeout'
require 'upfluence/context'

module Upfluence
  module Timeout
    def self.timeout(sec, klass = nil, message = nil, &block)
      effective = [sec, Upfluence.context.timeout].compact.min

      raise(klass || ::Timeout::Error, message) if effective <= 0

      Upfluence.context.with_timeout(effective) do
        ::Timeout.timeout(effective, klass, message, &block)
      end
    end
  end
end
