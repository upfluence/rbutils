require 'prometheus/client'

module Upfluence
  module HTTP
    module Middleware
      class Prometheus
        def initialize(app, registry = ::Prometheus::Client.registry)
          @registry = registry

          @request_total_count = @registry.get(
            :uhttp_handler_requests_total
          ) || @registry.counter(
            :uhttp_handler_requests_total,
            'Histogram of processed items',
          )

          @request_histogram = @registry.get(
            :uhttp_handler_requests_duration_second
          ) || @registry.histogram(
            :uhttp_handler_requests_duration_second,
            'Histogram of processing time',
          )

          @app = app
        end

        def call(env)
          trace(env) { @app.call(env) }
        end

        private

        def trace(env)
          start = Time.now
          yield.tap do |response|
            duration = [(Time.now - start).to_f, 0.0].max
            record(env, response.first.to_s, duration)
          end
        end

        def record(env, code, duration)
          @request_total_count.increment(
            path: parse_route(env),
            method: env['REQUEST_METHOD'].downcase,
            status: code
          )

          @request_histogram.observe(
            { path: parse_route(env), method: env['REQUEST_METHOD'].downcase },
            duration
          )
        end

        def parse_route(env)
          parse_route_sinatra(env) || parse_route_rails(env) ||
            parse_route_default(env)
        end

        def parse_route_rails(env)
          params = env["action_dispatch.request.parameters"]
          return nil if params.nil?

          "#{params["controller"]}##{params["action"]}"
        end

        def parse_route_sinatra(env)
          route = env['sinatra.route']
          return nil if route.nil? || route.strip == ''

          path = Rack::Request.new(env).path

          splitted_template = route.split(' ').last.split('/').select do |v|
            v != ''
          end.reverse

          path.split('/').reverse.map.with_index do |part, i|
            splitted_template[i] || part
          end.reverse.join('/')
        end

        def parse_route_default(env)
          Rack::Request.new(env).path.gsub(%r{/\d+(/|$)}, '/:id\\1')
        end
      end
    end
  end
end
