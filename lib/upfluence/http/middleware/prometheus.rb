require 'prometheus/client'
require 'upfluence/environment'
require 'upfluence/http/route_resolver'

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
          path = RouteResolver.resolve(env, code)

          @request_total_count.increment(
            labels: {
              path:   path,
              method: env['REQUEST_METHOD'].downcase,
              status: code,
              env:    Upfluence.env.to_s
            }
          )

          @request_histogram.observe(
            duration,
            labels: {
              path:   path,
              method: env['REQUEST_METHOD'].downcase,
              env:    Upfluence.env.to_s
            }
          )
        end
      end
    end
  end
end
