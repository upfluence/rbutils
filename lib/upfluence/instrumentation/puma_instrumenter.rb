require 'upfluence/instrumentation/periodic_instrumenter'
require 'puma'

module Upfluence
  module Instrumentation
    class PumaInstrumenter < PeriodicInstrumenter
      KEYS = %i[backlog_thread running_thread busy_thread pool_capacity requests_count].freeze

      attr_writer :server

      def prefix
        'puma'
      end

      def metrics
        KEYS.reduce({}) do |acc, k|
          acc.merge(k => { docstring: "Gauge for #{k}" })
        end
      end

      def values
        return {} unless @server

        stats = @server.stats

        {
          requests_count: stats[:requests_count],
          backlog_thread: stats[:backlog],
          running_thread: stats[:running],
          busy_thread:    stats[:busy_threads],
          pool_capacity:  stats[:max_threads]
        }.compact.transform_values { |value| [{ value: value }] }
      rescue NoMethodError
        {}
      end
    end
  end
end
