require 'upfluence/instrumentation/periodic_instrumenter'
require 'active_record'

module Upfluence
  module Instrumentation
    class ActiveRecordPoolInstrumenter < PeriodicInstrumenter
      KEYS = %i[
        size connections busy dead idle waiting
      ].freeze

      def prefix
        'active_record_pool'
      end

      def metrics
        KEYS.reduce({}) do |acc, k|
          acc.merge(k => { docstring: "Gauge for #{k}" })
        end
      end

      def values
        return {} unless ActiveRecord::Base.connected?

        ActiveRecord::Base.connection_pool.stat.slice(*KEYS).reduce({}) do |acc, (k, v)|
          acc.merge(k => [{ value: v }])
        end
      end
    end
  end
end
