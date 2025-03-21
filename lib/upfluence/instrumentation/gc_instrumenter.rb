require 'upfluence/instrumentation/periodic_instrumenter'

module Upfluence
  module Instrumentation
    class GCInstrumenter < PeriodicInstrumenter
      KEYS = %i[
        heap_live_slots heap_free_slots major_gc_count minor_gc_count
        total_allocated_objects
      ].freeze

      def prefix
        'ruby_gc'
      end

      def metrics
        KEYS.reduce({}) do |acc, k|
          acc.merge(k => { docstring: "Gauge for #{k}" })
        end
      end

      def values
        GC.stat.slice(*KEYS).reduce({}) do |acc, (k, v)|
          acc.merge(k => [{ value: v }])
        end
      end
    end
  end
end
