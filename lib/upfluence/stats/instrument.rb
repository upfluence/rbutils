require 'upfluence/stats/noop_scope'
require 'upfluence/stats/timer'
require 'upfluence/stats/vector'

module Upfluence
  module Stats
    class Instrument
      DEFAULT_FORMATTER = ->(error) { error.nil? ? 'success' : 'failed' }

      def initialize(scope, name, track_started: true, track_duration: true,
                     counter_label: 'status', formatter: DEFAULT_FORMATTER,
                     timer_opts: {})
        @counter_label = counter_label.to_sym
        @formatter     = formatter
        @started       = track_started ? scope.counter("#{name}_started_total") : NOOP_METRIC
        @timer         = Timer.new(scope, "#{name}_duration", **timer_opts) if track_duration
        @finished      = scope.counter_vector("#{name}_total", [@counter_label])
      end

      def start
        @started.inc

        Operation.new(@finished, @counter_label, @formatter, @timer&.start)
      end

      def exec
        operation = start
        error = nil

        yield
      rescue Exception => e
        error = e
        raise
      ensure
        operation&.finish(error)
      end
    end

    class Operation
      def initialize(finished, counter_label, formatter, stop_watch)
        @finished      = finished
        @counter_label = counter_label
        @formatter     = formatter
        @stop_watch    = stop_watch
      end

      def finish(error = nil)
        @stop_watch&.stop
        @finished.with_labels(@counter_label => @formatter.call(error)).inc
      end
    end

    class InstrumentVector < EntityVector
      def initialize(scope, name, labels, **opts)
        super(scope, labels) { |s| Instrument.new(s, name, **opts) }
      end
    end
  end
end
