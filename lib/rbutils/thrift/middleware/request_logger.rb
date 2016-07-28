module RbUtils
  module Thrift
    module Middleware
      class RequestLogger
        def initialize(app, logger)
          @app = app
          @logger = logger
        end

        def method_missing(method, *args, &block)
          args_str = args.map(&:to_s).join(',')[0..99]
          t0 = Time.now

          @logger.info(
            "Running method `#{method}` with [#{args_str}]"
          )

          result = @app.send method, *args, &block

          @logger.info(
            "Finished method `#{method}` with [#{args_str}]. Took: #{time_since(t0)}ms"
          )

          result
        rescue => e
          @logger.error(
            "Finished method `#{method}` with [#{args_str}] failed: #{e.class}. Took: #{time_since(t0)}ms"
          )
          raise e
        end

        private

        def time_since(t0)
          ((Time.now - t0) * 1000).to_i
        end
      end
    end
  end
end
