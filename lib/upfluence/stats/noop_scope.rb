module Upfluence
  module Stats
    class NoopMetric
      def inc; end
      def add(_value); end
      def update(_value); end
      def record(_value); end

      def get
        0
      end
    end

    NOOP_METRIC = NoopMetric.new

    class NoopVector
      def with_labels(**_values)
        NOOP_METRIC
      end
    end

    NOOP_VECTOR = NoopVector.new

    class NoopScope
      def namespace
        ''
      end

      def tags
        {}
      end

      def counter(_name, **_opts)
        NOOP_METRIC
      end

      def counter_vector(_name, _labels, **_opts)
        NOOP_VECTOR
      end

      def gauge(_name, **_opts)
        NOOP_METRIC
      end

      def gauge_vector(_name, _labels, **_opts)
        NOOP_VECTOR
      end

      def histogram(_name, **_opts)
        NOOP_METRIC
      end

      def histogram_vector(_name, _labels, **_opts)
        NOOP_VECTOR
      end

      def scope(_namespace = '', **_tags)
        self
      end

      def root_scope
        self
      end
    end

    NOOP_SCOPE = NoopScope.new
  end
end
