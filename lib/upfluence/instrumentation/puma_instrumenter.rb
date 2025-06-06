require 'upfluence/instrumentation/periodic_instrumenter'
require 'puma'

module Upfluence
  module Instrumentation
    class PumaInstrumenter < PeriodicInstrumenter
      KEYS = %i[backlog_thread running_thread busy_thread pool_capacity requests_count].freeze

      def prefix
        'puma'
      end

      def metrics
        KEYS.reduce({}) do |acc, k|
          acc.merge(k => { docstring: "Gauge for #{k}" })
        end
      end

      def values
        stats = Puma.stats_hash

        {
          requests_count: [{ value: stats[:requests_count] }],
          backlog_thread: [{ value: stats[:backlog] }],
          running_thread: [{ value: stats[:running] }],
          busy_thread:    [{ value: stats[:busy_threads] }],
          pool_capacity:  [{ value: stats[:max_threads] }]
        }
      rescue NoMethodError
        {}
      end
    end
  end
end
