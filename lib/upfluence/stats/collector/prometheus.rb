require 'prometheus/client'

module Upfluence
  module Stats
    module Collector
      class Prometheus
        class Counter
          def initialize(metric)
            @metric = metric
          end

          def inc
            add(1)
          end

          def add(value)
            @metric.increment(by: value)
          end

          def get
            @metric.get
          end
        end

        class Gauge
          def initialize(metric)
            @metric = metric
          end

          def update(value)
            @metric.set(value)
          end

          def get
            @metric.get
          end
        end

        class Histogram
          def initialize(metric)
            @metric = metric
          end

          def record(value)
            @metric.observe(value)
          end
        end

        class Vector
          def initialize(metric, wrapper)
            @metric  = metric
            @wrapper = wrapper
            @mutex   = Mutex.new
            @metrics = {}
          end

          def with_labels(labels)
            @mutex.synchronize do
              @metrics[labels] ||= @wrapper.new(
                labels.empty? ? @metric : @metric.with_labels(labels)
              )
            end
          end
        end

        def initialize(registry = ::Prometheus::Client.registry)
          @registry = registry
        end

        def register_counter(name, labels, docstring: nil)
          Vector.new(fetch(:counter, name, labels, docstring: docstring), Counter)
        end

        def register_gauge(name, labels, docstring: nil)
          Vector.new(fetch(:gauge, name, labels, docstring: docstring), Gauge)
        end

        def register_histogram(name, labels, buckets:, docstring: nil)
          Vector.new(
            fetch(:histogram, name, labels, docstring: docstring, buckets: buckets),
            Histogram
          )
        end

        private

        def fetch(type, name, labels, docstring:, **opts)
          name = name.to_sym
          metric = @registry.get(name) || @registry.public_send(
            type, name, docstring: docstring || name.to_s, labels: labels, **opts
          )

          if metric.type != type || metric.labels.sort != labels.sort
            raise ArgumentError, "#{name} already registered as a #{metric.type} with labels #{metric.labels}"
          end

          metric
        rescue ::Prometheus::Client::Registry::AlreadyRegisteredError
          retry
        end
      end
    end
  end
end
