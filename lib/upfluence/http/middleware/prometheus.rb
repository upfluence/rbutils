require 'prometheus/client'
require 'upfluence/environment'

module Upfluence
  module HTTP
    module Middleware
      class Prometheus
        LABELS = %i[path method env].freeze

        def initialize(app, registry = ::Prometheus::Client.registry)
          @registry = registry

          @request_total_count = @registry.get(
            :uhttp_handler_requests_total
          ) || @registry.counter(
            :uhttp_handler_requests_total,
            docstring: 'Histogram of processed items',
            labels:    LABELS + %i[status]
          )

          @request_histogram = @registry.get(
            :uhttp_handler_requests_duration_second
          ) || @registry.histogram(
            :uhttp_handler_requests_duration_second,
            docstring: 'Histogram of processing time',
            labels:    LABELS
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
            labels: {
              path:   parse_route(env),
              method: env['REQUEST_METHOD'].downcase,
              status: code,
              env:    Upfluence.env.to_s
            }
          )

          @request_histogram.observe(
            duration,
            labels: {
              path:   parse_route(env),
              method: env['REQUEST_METHOD'].downcase,
              env:    Upfluence.env.to_s
            }
          )
        end

        def parse_route(env)
          parse_route_sinatra(env) || parse_route_rails(env) ||
            parse_route_default(env)
        end

        def parse_route_rails(env)
          params = env['action_dispatch.request.parameters']
          return nil if params.nil?

          "#{params['controller']}##{params['action']}"
        end

        def parse_route_sinatra(env)
          route = env['sinatra.route']
          return nil if route.nil? || route.strip == ''

          path = Rack::Request.new(env).path

          splitted_template = route.split(' ').last.split('/').rejext do |v|
            v.eql?('')
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
