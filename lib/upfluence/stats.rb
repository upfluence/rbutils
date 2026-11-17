require 'upfluence/stats/scope'
require 'upfluence/stats/root_scope'
require 'upfluence/stats/noop_scope'
require 'upfluence/stats/timer'
require 'upfluence/stats/instrument'
require 'upfluence/stats/collector/prometheus'
require 'upfluence/stats/collector/static'

module Upfluence
  module Stats
    class << self
      attr_writer :root_scope

      def root_scope
        @root_scope ||= RootScope.new(Collector::Prometheus.new)
      end
    end
  end
end
