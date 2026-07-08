require 'thread'
require 'upfluence/timeout'

module Upfluence
  class Pool
    class UnknownResource < RuntimeError; end
    class NoInstanciationBlock < RuntimeError; end

    class PrometheusMetrics
      def self.standardized_metrics(n)
        require 'prometheus/client'
        new(Prometheus::Client.registry, 'upfluence_iopool_pool', { pool: n })
      end

      def initialize(registry, prefix, labels)
        label_keys = labels.keys

        @labels            = labels
        @get               = register(registry, :counter, :"#{prefix}_get_total", 'Total pool get calls', label_keys)
        @put               = register(registry, :counter, :"#{prefix}_put_total", 'Total pool put calls', label_keys)
        @discard           = register(registry, :counter, :"#{prefix}_discard_total", 'Total pool discard calls', label_keys)
        @get_wait          = register(registry, :counter, :"#{prefix}_get_wait_total", 'Pool gets that had to wait', label_keys)
        @get_wait_duration = register(registry, :counter, :"#{prefix}_get_wait_millisecond_total", 'Total milliseconds waiting for pool get', label_keys)
        @idle              = register(registry, :gauge,   :"#{prefix}_idle", 'Idle resources in pool', label_keys)
        @checkout          = register(registry, :gauge,   :"#{prefix}_checkout", 'Checked out resources in pool', label_keys)
        @size              = register(registry, :gauge,   :"#{prefix}_size", 'Total pool size', label_keys)
      end

      def observe_get
        @get.increment(labels: @labels)
      end

      def observe_put
        @put.increment(labels: @labels)
      end

      def observe_discard
        @discard.increment(labels: @labels)
      end

      def observe_wait(seconds)
        @get_wait.increment(labels: @labels)
        @get_wait_duration.increment(by: (seconds * 1000).to_i, labels: @labels)
      end

      def update_idle(count)
        @idle.set(count, labels: @labels)
      end

      def update_checkout(count)
        @checkout.set(count, labels: @labels)
      end

      def set_size(count)
        @size.set(count, labels: @labels)
      end

      private

      def register(registry, type, name, docstring, label_keys)
        registry.public_send(type, name, docstring: docstring, labels: label_keys)
      rescue Prometheus::Client::Registry::AlreadyRegisteredError
        registry.get(name)
      end
    end

    class NullMetrics
      def observe_get; end
      def observe_put; end
      def observe_discard; end
      def observe_wait(_seconds); end
      def update_idle(_count); end
      def update_checkout(_count); end
      def set_size(_count); end
    end

    attr_reader :max

    def initialize(size = 0, options = {}, &block)
      raise NoInstanciationBlock unless block

      @create_block = block
      @redeemed = []
      @que = []
      @max = size
      @mutex = Mutex.new
      @resource = ConditionVariable.new
      @shutdown_block = nil
      @timeout = options.fetch :timeout, 5
      @metrics = options.fetch(:metrics, NullMetrics.new)

      @metrics.set_size(size)
    end

    def discard(obj)
      @mutex.synchronize do
        remove_from_redeemed obj
        @resource.broadcast
      end
    end

    def push(obj)
      @mutex.synchronize do
        remove_from_redeemed obj

        @que.push obj
        @resource.broadcast
      end
    end

    def pop(options = {})
      timeout = options.fetch :timeout, @timeout
      effective = [timeout, Upfluence.context.timeout].compact.min
      deadline = Time.now + effective

      @mutex.synchronize do
        loop do
          return redeem(@que.pop) unless @que.empty?

          connection = redeem(try_create(options))
          return connection if connection

          to_wait = deadline - Time.now
          raise ::Timeout::Error, "Waited #{timeout} sec" if to_wait <= 0
          @resource.wait(@mutex, to_wait)
        end
      end
    end

    def empty?
      (@redeemed.length - @que.length) >= @max
    end

    def length
      @max - @redeemed.length + @que.length
    end

    private

    def remove_from_redeemed(obj)
      unless @redeemed.map(&:object_id).include? obj.object_id
        raise UnknownResource
      end

      @redeemed.reject! { |e| e.object_id == obj.object_id }
    end

    def redeem(obj)
      @redeemed << obj if obj
      obj
    end

    def try_create(_options = nil)
      return if @redeemed.length >= @max

      @create_block.call
    end
  end
end
