require 'stackprof'

module Upfluence
  module HTTP
    module Endpoint
      class Profiler
        def initialize(opts = {})
          @interval = opts[:interval] || 50
          @mode = opts[:mode] || :cpu
          @mapping = Rack::URLMap.new(
            '/start' => lambda { |env|  start(env) },
            '/stop' => lambda { |env| stop(env) },
            '/profile' => lambda { |env| profile(env) }
          )
        end

        def call(env)
          @mapping.call(env)
        end

        private

        def stop(env)
          StackProf.stop
          return ok
        end

        def start(env)
          StackProf.start(mode: @mode, interval: @interval, raw: false)
          return ok
        end

        def profile(env)
          results = StackProf.results
          @last_results = Marshal.dump(results) if results

          return [200, {}, [@last_results]] if @last_results
          return [404, {}, ['No profile available']]
        end

        def ok
          [200, {}, ['ok']]
        end

        def path(env)
          Rack::Request.new(env).path
        end
      end
    end
  end
end
