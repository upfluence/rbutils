require 'upfluence/stats/vector'

module Upfluence
  module Stats
    DEFAULT_BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10].freeze

    class Scope
      attr_reader :namespace, :tags

      def initialize(registry, namespace, tags)
        @registry  = registry
        @namespace = namespace
        @tags      = tags
      end

      def counter(name, docstring: nil)
        counter_vector(name, [], docstring: docstring).with_labels
      end

      def counter_vector(name, labels, docstring: nil)
        register(:counter, name, labels, docstring: docstring)
      end

      def gauge(name, docstring: nil)
        gauge_vector(name, [], docstring: docstring).with_labels
      end

      def gauge_vector(name, labels, docstring: nil)
        register(:gauge, name, labels, docstring: docstring)
      end

      def histogram(name, buckets: DEFAULT_BUCKETS, docstring: nil)
        histogram_vector(name, [], buckets: buckets, docstring: docstring).with_labels
      end

      def histogram_vector(name, labels, buckets: DEFAULT_BUCKETS, docstring: nil)
        register(:histogram, name, labels, buckets: buckets, docstring: docstring)
      end

      def scope(namespace = '', **tags)
        Scope.new(
          @registry,
          join_names(@namespace, namespace),
          @tags.merge(tags.to_h { |k, v| [k.to_sym, v.to_s] })
        )
      end

      def root_scope
        Scope.new(@registry, '', {})
      end

      private

      def register(type, name, labels, **opts)
        labels = labels.map(&:to_sym)

        Vector.new(
          @registry.register(type, join_names(@namespace, name), @tags.keys + labels, **opts),
          @tags,
          labels
        )
      end

      def join_names(*names)
        names.map(&:to_s).reject(&:empty?).join('_')
      end
    end
  end
end
