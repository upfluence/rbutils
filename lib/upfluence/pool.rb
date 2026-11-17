require 'upfluence/stats'
require 'upfluence/timeout'

module Upfluence
  class Pool
    class UnknownResource < RuntimeError; end
    class NoInstanciationBlock < RuntimeError; end

    class Metrics
      def self.standardized_metrics(n, scope: Upfluence::Stats.root_scope)
        new(scope.scope('upfluence_iopool_pool', pool: n))
      end

      def initialize(scope)
        @get               = scope.counter('get_total', docstring: 'Total pool get calls')
        @put               = scope.counter('put_total', docstring: 'Total pool put calls')
        @discard           = scope.counter('discard_total', docstring: 'Total pool discard calls')
        @get_wait          = scope.counter('get_wait_total', docstring: 'Pool gets that had to wait')
        @get_wait_duration = scope.counter(
          'get_wait_millisecond_total', docstring: 'Total milliseconds waiting for pool get'
        )
        @idle              = scope.gauge('idle', docstring: 'Idle resources in pool')
        @checkout          = scope.gauge('checkout', docstring: 'Checked out resources in pool')
        @size              = scope.gauge('size', docstring: 'Total pool size')
      end

      def observe_get
        @get.inc
      end

      def observe_put
        @put.inc
      end

      def observe_discard
        @discard.inc
      end

      def observe_wait(seconds)
        @get_wait.inc
        @get_wait_duration.add((seconds * 1000).to_i)
      end

      def update_idle(count)
        @idle.update(count)
      end

      def update_checkout(count)
        @checkout.update(count)
      end

      def set_size(count)
        @size.update(count)
      end
    end

    # Deprecated: use Metrics with a Upfluence::Stats scope instead.
    class PrometheusMetrics < Metrics
      def self.standardized_metrics(n)
        Metrics.standardized_metrics(n)
      end

      def initialize(registry, prefix, labels)
        super(
          Upfluence::Stats::RootScope.new(
            Upfluence::Stats::Collector::Prometheus.new(registry)
          ).scope(prefix, **labels)
        )
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
      @metrics.observe_discard

      @mutex.synchronize do
        remove_from_redeemed obj
        @metrics.update_checkout(@redeemed.length)
        @resource.broadcast
      end
    end

    def push(obj)
      @metrics.observe_put

      @mutex.synchronize do
        remove_from_redeemed obj

        @que.push obj
        @metrics.update_idle(@que.length)
        @metrics.update_checkout(@redeemed.length)
        @resource.broadcast
      end
    end

    def pop(options = {})
      timeout = options.fetch :timeout, @timeout
      effective = [timeout, Upfluence.context.timeout].compact.min
      deadline = Time.now + effective
      t0 = nil

      @metrics.observe_get

      @mutex.synchronize do
        loop do
          unless @que.empty?
            result = redeem(@que.pop)
            @metrics.update_idle(@que.length)
            @metrics.observe_wait(Time.now - t0) if t0
            return result
          end

          connection = try_create(options)

          if connection
            result = redeem(connection)
            @metrics.observe_wait(Time.now - t0) if t0
            return result
          end

          to_wait = deadline - Time.now
          raise ::Timeout::Error.new("Waited #{timeout} sec") if to_wait <= 0

          t0 ||= Time.now
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
      raise UnknownResource unless @redeemed.map(&:object_id).include? obj.object_id

      @redeemed.reject! { |e| e.equal?(obj) }
    end

    def redeem(obj)
      @redeemed << obj if obj
      @metrics.update_checkout(@redeemed.length)
      obj
    end

    def try_create(_options = nil)
      return if @redeemed.length >= @max

      @create_block.call
    end
  end
end
