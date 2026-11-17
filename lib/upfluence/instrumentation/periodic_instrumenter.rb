require 'upfluence/stats'

module Upfluence
  module Instrumentation
    class PeriodicInstrumenter
      def initialize(interval: 30, scope: Upfluence::Stats.root_scope)
        scope = scope.scope(prefix.to_s)

        @interval = interval
        @gauges = metrics.to_h do |metric, values|
          [
            metric,
            scope.gauge_vector(metric, values[:labels] || [], docstring: values[:docstring])
          ]
        end

        @stop_thread = false
      end

      def start
        @thread ||= Thread.new do
          until @stop_thread
            begin
              collect
            rescue => e
              Upfluence.error_logger.notify(e)
            ensure
              sleep @interval unless @stop_thread
            end
          end
        end
      end

      def collect
        values.each do |(metric, vs)|
          vs.each do |v|
            @gauges[metric].with_labels(**(v[:labels] || {})).update(v[:value])
          end
        end
      end

      def stop
        return unless @thread&.alive?

        @stop_thread = true
        @thread.wakeup
        @thread.join
        @thread = nil
      end

      def prefix
        nil
      end

      def values
        raise "Please implement a subcalss"
      end

      def metrics
        raise "Please implement a subcalss"
      end
    end
  end
end
