module Upfluence
  module Utils
    class IntervalExecutor
      DEFAULT_INTERVAL = 60*60*6

      class << self
        def start(interval = DEFAULT_INTERVAL)
          Thread.new do
            loop do
              yield

              sleep(interval)
            end
          end
        end
      end
    end
  end
end
