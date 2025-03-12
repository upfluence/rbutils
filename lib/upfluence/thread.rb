require 'thread'

module Upfluence
  class Thread < ::Thread
    def initialize(**opts, &block)
      thr = self.class.current
      wrappers = self.class.wrappers.reject { |k, _| opts.key?(k) && !opts[k] }.values

      super do
        wrappers.reduce(block) do |acc, wrapper|
          Proc.new { wrapper.wrap_thread(thr, acc) }
        end.call
      end
    end

    class << self
      def wrappers
        @wrappers || {}
      end

      def register_wrapper(name, klass)
        @wrappers ||= {}
        @wrappers[name] = klass
      end
    end
  end
end

begin
  require 'active_record'

  class ActiveRecordThreadWrapper
    class << self
      def wrap_thread(_thr, block)
        return block.call unless ActiveRecord::Base.connected?

        ActiveRecord::Base.connection_pool.with_connection do
          block.call
        end
      end
    end
  end

  Upfluence::Thread.register_wrapper :active_record, ActiveRecordThreadWrapper
rescue LoadError
end
