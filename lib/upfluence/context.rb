# frozen_string_literal: true

require 'upfluence/thread'

module Upfluence
  CONTEXT_KEY = :upfluence_context

  class Context
    attr_reader :deadline

    def initialize
      @deadline = nil
    end

    def timeout
      return nil if @deadline.nil?

      [(@deadline - Time.now).to_f, 0.0].max
    end

    def with_deadline(deadline, override: false)
      previous = @deadline
      @deadline = override || previous.nil? ? deadline : [previous, deadline].min

      yield
    ensure
      @deadline = previous
    end

    def with_timeout(duration, override: false)
      with_deadline(Time.now + duration, override: override) { yield }
    end

    class ThreadWrapper
      class << self
        def wrap_thread(thr, block)
          parent_deadline = thr[CONTEXT_KEY]&.deadline

          return block.call unless parent_deadline

          Upfluence.context.with_deadline(parent_deadline) { block.call }
        end
      end
    end

    ::Upfluence::Thread.register_wrapper :context, ThreadWrapper
  end

  class << self
    def context
      Thread.current[CONTEXT_KEY] ||= Context.new
    end
  end
end
