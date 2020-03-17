module Upfluence
  module Utils
    class Semaphore
      def initialize(size)
        @size = size
        @used = 0
        @mutex = Mutex.new
        @cond = ConditionVariable.new
      end

      def acquire(count = 1)
        @mutex.synchronize do
          loop do
            break if @used + count <= @size

            @cond.wait(@mutex)
          end

          @used += count
        end
      end

      def release(count = 1)
        @mutex.synchronize do
          @used -= count
          @cond.broadcast
        end
      end

      def synchronize(count = 1, &block)
        acquire(count)
        block.call
      ensure
        release(count)
      end
    end
  end
end
