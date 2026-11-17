module Upfluence
  module Stats
    class Vector
      attr_reader :labels

      def initialize(vector, tags, labels)
        @vector = vector
        @tags   = tags
        @labels = labels
      end

      def with_labels(**values)
        @vector.with_labels(@tags.merge(Vector.normalize_values(@labels, values)))
      end

      def self.normalize_values(labels, values)
        values = values.to_h { |k, v| [k.to_sym, v.to_s] }

        return values if values.length == labels.length && values.keys.sort == labels.sort

        raise ArgumentError, "wrong label values: labels: #{labels}, values: #{values.keys}"
      end
    end

    class EntityVector
      attr_reader :labels

      def initialize(scope, labels, &build)
        @scope    = scope
        @labels   = labels.map(&:to_sym)
        @build    = build
        @mutex    = Mutex.new
        @entities = {}
      end

      def with_labels(**values)
        values = Vector.normalize_values(@labels, values)

        @mutex.synchronize do
          @entities[values] ||= @build.call(@scope.scope('', **values))
        end
      end
    end
  end
end
