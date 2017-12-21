require 'thread'
require 'timeout'

module Upfluence
  class Pool
    class UnknownResource < RuntimeError; end
    class NoInstanciationBlock < RuntimeError; end

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
      deadline = Time.now + timeout

      @mutex.synchronize do
        loop do
          return redeem(@que.pop) unless @que.empty?

          connection = redeem(try_create(options))
          return connection if connection

          to_wait = deadline - Time.now
          raise Timeout::Error, "Waited #{timeout} sec" if to_wait <= 0
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
