module Upfluence
  module Instrumentation
    class PeriodicInstrumenter
      def initialize(interval: 30, registry: ::Prometheus::Client.registry)
        @interval = interval
        @gauges = metrics.reduce({}) do |acc, (metric, values)|
          metric_name = [prefix, metric].compact.join("_").to_sym

          acc.merge(
            metric => registry.get(metric_name) || registry.gauge(
              metric_name,
              docstring: values[:docstring] || '',
              labels:    values[:labels] || []
            )
          )
        end

        @stop_thread = false
      end

      def start
        @thread ||= Thread.new do
          until @stop_thread
            begin
              values.each do |(metric, vs)|
                vs.each do |v|
                  @gauges[metric].set(v[:value], labels: v[:labels] || {})
                end
              end
            rescue => e
              Upfluence.error_logger.notify(e)
            ensure
              sleep @interval
            end
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
