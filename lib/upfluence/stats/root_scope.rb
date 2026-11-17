require 'upfluence/stats/scope'

module Upfluence
  module Stats
    class RootScope < Scope
      def initialize(collector)
        super(Registry.new(collector), '', {})
      end
    end

    class Registry
      Entry = Struct.new(:type, :labels, :vector)

      def initialize(collector)
        @collector = collector
        @mutex     = Mutex.new
        @entries   = {}
      end

      def register(type, name, labels, **opts)
        if labels.uniq.length != labels.length
          raise ArgumentError, "duplicated labels for #{name}: #{labels}"
        end

        @mutex.synchronize do
          entry = @entries[name]

          return fetch(entry, type, name, labels) if entry

          vector = @collector.public_send(:"register_#{type}", name, labels, **opts)
          @entries[name] = Entry.new(type, labels.sort, vector)

          vector
        end
      end

      private

      def fetch(entry, type, name, labels)
        if entry.type != type
          raise ArgumentError, "#{entry.type} with the same name already registered: #{name}"
        end

        if entry.labels != labels.sort
          raise ArgumentError, "#{type} #{name} already registered with different labels: #{entry.labels}"
        end

        entry.vector
      end
    end
  end
end
