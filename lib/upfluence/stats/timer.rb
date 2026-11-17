require 'upfluence/stats/vector'

module Upfluence
  module Stats
    class Timer
      DEFAULT_SUFFIX = '_seconds'.freeze

      def initialize(scope, name, suffix: DEFAULT_SUFFIX, **histogram_opts)
        @histogram = scope.histogram("#{name}#{suffix}", **histogram_opts)
      end

      def start
        StopWatch.new(@histogram)
      end

      def time
        stop_watch = start
        yield
      ensure
        stop_watch&.stop
      end
    end

    class StopWatch
      def initialize(histogram)
        @histogram  = histogram
        @started_at = now
      end

      def stop
        @histogram.record(now - @started_at)
      end

      private

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end

    class TimerVector < EntityVector
      def initialize(scope, name, labels, **opts)
        super(scope, labels) { |s| Timer.new(s, name, **opts) }
      end
    end
  end
end
