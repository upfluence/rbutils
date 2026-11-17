module Upfluence
  module Stats
    module Collector
      class Static
        Snapshot          = Struct.new(:counters, :gauges, :histograms, keyword_init: true)
        ValueSnapshot     = Struct.new(:name, :labels, :value, keyword_init: true)
        HistogramSnapshot = Struct.new(:name, :labels, :count, :sum, :buckets, keyword_init: true)
        Bucket            = Struct.new(:upper_bound, :count, keyword_init: true)

        class Value
          def initialize
            @mutex = Mutex.new
            @value = 0
          end

          def inc
            add(1)
          end

          def add(value)
            @mutex.synchronize { @value += value }
          end

          def update(value)
            @mutex.synchronize { @value = value }
          end

          def get
            @mutex.synchronize { @value }
          end
        end

        class Histogram
          def initialize(buckets)
            @upper_bounds = buckets + [Float::INFINITY]
            @mutex        = Mutex.new
            @counts       = Array.new(@upper_bounds.length, 0)
            @sum          = 0
          end

          def record(value)
            index = @upper_bounds.index { |upper_bound| value <= upper_bound }

            @mutex.synchronize do
              @counts[index] += 1
              @sum += value
            end
          end

          def count
            @mutex.synchronize { @counts.sum }
          end

          def sum
            @mutex.synchronize { @sum }
          end

          def buckets
            @mutex.synchronize do
              @upper_bounds.zip(@counts).map do |upper_bound, count|
                Bucket.new(upper_bound: upper_bound, count: count)
              end
            end
          end
        end

        class Vector
          def initialize(&build)
            @build   = build
            @mutex   = Mutex.new
            @metrics = {}
          end

          def with_labels(labels)
            @mutex.synchronize { @metrics[labels] ||= @build.call }
          end

          def entries
            @mutex.synchronize { @metrics.to_a }
          end
        end

        def initialize
          @mutex   = Mutex.new
          @vectors = { counter: {}, gauge: {}, histogram: {} }
        end

        def register_counter(name, _labels, docstring: nil)
          register(:counter, name) { Value.new }
        end

        def register_gauge(name, _labels, docstring: nil)
          register(:gauge, name) { Value.new }
        end

        def register_histogram(name, _labels, buckets:, docstring: nil)
          register(:histogram, name) { Histogram.new(buckets) }
        end

        def snapshot
          Snapshot.new(
            counters:   value_snapshots(:counter),
            gauges:     value_snapshots(:gauge),
            histograms: histogram_snapshots
          )
        end

        private

        def register(type, name, &build)
          @mutex.synchronize { @vectors[type][name] = Vector.new(&build) }
        end

        def entries(type)
          vectors = @mutex.synchronize { @vectors[type].to_a }

          vectors.flat_map do |name, vector|
            vector.entries.map { |labels, metric| [name, labels, metric] }
          end
        end

        def value_snapshots(type)
          sort(
            entries(type).map do |name, labels, metric|
              ValueSnapshot.new(name: name, labels: labels, value: metric.get)
            end
          )
        end

        def histogram_snapshots
          sort(
            entries(:histogram).map do |name, labels, metric|
              HistogramSnapshot.new(
                name:    name,
                labels:  labels,
                count:   metric.count,
                sum:     metric.sum,
                buckets: metric.buckets
              )
            end
          )
        end

        def sort(snapshots)
          snapshots.sort_by do |snapshot|
            [snapshot.name, snapshot.labels.map { |k, v| [k.to_s, v] }.sort]
          end
        end
      end
    end
  end
end
